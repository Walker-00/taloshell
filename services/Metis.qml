pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

/**
 * Graphing calculator backend for the dashboard Graph tab.
 * Talks to `metis --serve` (a Rust graphing engine; /data/projects/metis)
 * over JSON lines: the shell sends the expression list + view, metis answers
 * with ready-to-draw polylines (pixel space), shaded regions, points, tables,
 * points of interest and per-row results (values, errors, sliders, regressions).
 *
 * Only one request is in flight; newer requests replace older unsent ones,
 * so typing/panning never queues stale work. A watchdog restarts metis if a
 * pathological expression takes too long.
 */
Singleton {
    id: root

    readonly property string stateFile: FileUtils.trimFileProtocol(`${Directories.state}/user/graph.json`)
    readonly property string command: Config.options.apps.metis || "metis"

    // Desmos-like palette that reads on light and dark themes
    readonly property list<color> palette: ["#e0524d", "#3b82f6", "#22a559", "#9b6bf2", "#f28c28", "#14b8a6", "#ec4899", "#8a8f98"]
    function colorOf(i) { return root.palette[((i % root.palette.length) + root.palette.length) % root.palette.length]; }

    // ------------------------------------------------------------- document
    // One entry per row. `kind` is "expr" or "table"; tables keep their
    // columns as JSON in `tableJson`: [{ header, cells: [..], hue }].
    property ListModel rows: ListModel {}
    property bool deg: false
    property real cx: 0
    property real cy: 0
    property real sx: 0.025 // world units per pixel
    property real sy: 0.025
    property int selected: 0
    property bool loaded: false
    property int nextColor: 0
    property var settings: root.defaultSettings()

    function defaultSettings() {
        return { grid: true, minorGrid: true, axes: true, axisNumbers: true, polarGrid: false, xLabel: "", yLabel: "", lockSquare: true };
    }
    function setSetting(key, value) {
        const s = Object.assign({}, root.settings);
        s[key] = value;
        root.settings = s;
        if (key === "lockSquare" && value) root.sy = root.sx;
        root.changed();
    }

    signal changed() // any document/view edit → re-render + save

    function makeRow(text, kind) {
        return {
            kind: kind ?? "expr", text: text ?? "", tableJson: "", hue: root.nextColor++, hidden: false,
            min: -10, max: 10, step: 0.1, playing: false, dir: 1, speed: 1, loopMode: "bounce",
            lineStyle: "solid", lineWidth: 2.5, opacity: 1, fillOpacity: 0.25, pointStyle: "dot",
            showLabel: false, connect: false,
        };
    }
    readonly property var rowRoles: ["kind", "text", "tableJson", "hue", "hidden", "min", "max", "step", "speed", "loopMode",
        "lineStyle", "lineWidth", "opacity", "fillOpacity", "pointStyle", "showLabel", "connect"]

    function rowObjects() {
        const out = [];
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            const o = {};
            for (const k of root.rowRoles) o[k] = r[k];
            out.push(o);
        }
        return out;
    }
    function loadRows(list) {
        rows.clear();
        for (const r of list) {
            const base = root.makeRow("", "expr");
            root.nextColor--; // makeRow consumed a color we don't use
            const row = Object.assign(base, r);
            // v1 files stored the palette index as `color`
            if (r.hue === undefined && r.color !== undefined) row.hue = r.color;
            delete row.color;
            row.playing = false;
            row.dir = 1;
            rows.append(row);
        }
        if (rows.count === 0) rows.append(root.makeRow(""));
        root.selected = Math.min(root.selected, rows.count - 1);
        root.updateAnimating();
    }

    // ------------------------------------------------------------- undo / redo
    property var undoStack: []
    property var redoStack: []
    property string lastCheckpointKey: ""
    property real lastCheckpointTime: 0
    readonly property bool canUndo: undoStack.length > 0
    readonly property bool canRedo: redoStack.length > 0

    function snapshot() { return JSON.stringify({ rows: root.rowObjects(), deg: root.deg }); }
    /// Record the state before an edit. Repeated edits with the same key
    /// (typing in one row, dragging one point) collapse into one step.
    function checkpoint(key) {
        const now = Date.now();
        if (key && key === root.lastCheckpointKey && now - root.lastCheckpointTime < 1200) {
            root.lastCheckpointTime = now;
            return;
        }
        const u = root.undoStack.slice();
        u.push(root.snapshot());
        if (u.length > 200) u.shift();
        root.undoStack = u;
        root.redoStack = [];
        root.lastCheckpointKey = key ?? "";
        root.lastCheckpointTime = now;
    }
    function restore(snap) {
        const d = JSON.parse(snap);
        root.loadRows(d.rows);
        root.deg = !!d.deg;
        root.lastCheckpointKey = "";
        root.changed();
    }
    function undo() {
        if (root.undoStack.length === 0) return;
        const u = root.undoStack.slice();
        const snap = u.pop();
        root.redoStack = root.redoStack.concat([root.snapshot()]);
        root.undoStack = u;
        root.restore(snap);
    }
    function redo() {
        if (root.redoStack.length === 0) return;
        const r = root.redoStack.slice();
        const snap = r.pop();
        root.undoStack = root.undoStack.concat([root.snapshot()]);
        root.redoStack = r;
        root.restore(snap);
    }

    // ------------------------------------------------------------- row edits
    function insertRow(at, text, kind) {
        root.checkpoint("");
        at = Math.max(0, Math.min(at, rows.count));
        rows.insert(at, root.makeRow(text, kind));
        root.changed();
        return at;
    }
    function removeRow(i) {
        if (i < 0 || i >= rows.count) return;
        root.checkpoint("");
        rows.remove(i);
        root.updateAnimating();
        if (rows.count === 0) rows.append(root.makeRow(""));
        root.selected = Math.min(root.selected, rows.count - 1);
        root.changed();
    }
    function duplicateRow(i) {
        if (i < 0 || i >= rows.count) return;
        root.checkpoint("");
        const o = root.rowObjects()[i];
        o.hue = root.nextColor++;
        o.playing = false;
        o.dir = 1;
        rows.insert(i + 1, o);
        root.selected = i + 1;
        root.changed();
    }
    function moveRow(i, delta) {
        const j = i + delta;
        if (i < 0 || j < 0 || i >= rows.count || j >= rows.count) return;
        root.checkpoint("");
        rows.move(i, j, 1);
        root.selected = j;
        root.changed();
    }
    function setText(i, text) {
        if (i < 0 || i >= rows.count || rows.get(i).text === text) return;
        root.checkpoint(`text:${i}`);
        rows.setProperty(i, "text", text);
        root.changed();
    }
    function setProp(i, prop, value) {
        if (i < 0 || i >= rows.count || rows.get(i)[prop] === value) return;
        root.checkpoint(`prop:${i}:${prop}`);
        rows.setProperty(i, prop, value);
        root.changed();
    }
    function clearAll() {
        root.checkpoint("");
        rows.clear();
        rows.append(root.makeRow(""));
        root.selected = 0;
        root.changed();
    }

    // ------------------------------------------------------------- names
    function usedNames() {
        const names = new Set(root.result?.names ?? []);
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            const m = r.text.match(/^\s*([A-Za-zα-ωΑ-Ω]+(?:_\{?\w+\}?)?)\s*(?:\(|=)/);
            if (m) names.add(m[1].replace(/[{}]/g, ""));
            if (r.kind === "table") for (const c of root.tableOf(i).columns) names.add(c.header.trim());
        }
        return names;
    }
    /// `base` if unused, else base_1, base_2, …
    function fresh(base, taken) {
        const used = taken ?? root.usedNames();
        if (!used.has(base)) return base;
        for (let k = 1; k < 1000; k++) if (!used.has(`${base}_${k}`)) return `${base}_${k}`;
        return base;
    }

    // ------------------------------------------------------------- tables
    function tableOf(i) {
        try {
            const t = JSON.parse(rows.get(i).tableJson || "{}");
            return { columns: Array.isArray(t.columns) ? t.columns : [] };
        } catch (e) {
            return { columns: [] };
        }
    }
    function setTable(i, t, key) {
        root.checkpoint(key ?? "");
        rows.setProperty(i, "tableJson", JSON.stringify(t));
        root.changed();
    }
    /// Free pair of column names x_n / y_n.
    function freshTableIndex() {
        const used = root.usedNames();
        for (let n = 1; n < 1000; n++) if (!used.has(`x_${n}`) && !used.has(`y_${n}`)) return n;
        return 1;
    }
    function addTable(at, points) {
        const n = root.freshTableIndex();
        const xs = (points ?? []).map(p => root.num(p[0]));
        const ys = (points ?? []).map(p => root.num(p[1]));
        const row = root.makeRow("", "table");
        row.tableJson = JSON.stringify({ columns: [
            { header: `x_${n}`, cells: xs.length ? xs : [""], hue: row.hue },
            { header: `y_${n}`, cells: ys.length ? ys : [""], hue: row.hue },
        ] });
        root.checkpoint("");
        at = Math.max(0, Math.min(at, rows.count));
        rows.insert(at, row);
        root.selected = at;
        root.changed();
        return at;
    }
    function setCell(i, c, r, text) {
        const t = root.tableOf(i);
        const col = t.columns[c];
        if (!col) return;
        while (col.cells.length <= r) col.cells.push("");
        if (col.cells[r] === text) return;
        col.cells[r] = text;
        // keep every column the same length
        const len = Math.max(...t.columns.map(k => k.cells.length));
        for (const k of t.columns) while (k.cells.length < len) k.cells.push("");
        root.setTable(i, t, `cell:${i}:${c}:${r}`);
    }
    function setHeader(i, c, text) {
        const t = root.tableOf(i);
        if (!t.columns[c] || t.columns[c].header === text) return;
        t.columns[c].header = text;
        root.setTable(i, t, `header:${i}:${c}`);
    }
    function addColumn(i) {
        const t = root.tableOf(i);
        const first = t.columns[0]?.header ?? "x_1";
        const m = first.match(/_(\w+)$/);
        const used = root.usedNames();
        let name = root.fresh(m ? `y_${m[1]}` : "y_1", used);
        if (t.columns.some(k => k.header === name)) name = root.fresh("y", used);
        const len = t.columns[0]?.cells.length ?? 1;
        t.columns.push({ header: name, cells: Array(len).fill(""), hue: root.nextColor++ });
        root.setTable(i, t);
    }
    function removeColumn(i, c) {
        const t = root.tableOf(i);
        if (t.columns.length <= 2) return;
        t.columns.splice(c, 1);
        root.setTable(i, t);
    }
    function removeTableRow(i, r) {
        const t = root.tableOf(i);
        for (const k of t.columns) if (r < k.cells.length) k.cells.splice(r, 1);
        root.setTable(i, t);
    }
    function setColumnHue(i, c, hue) {
        const t = root.tableOf(i);
        if (!t.columns[c]) return;
        t.columns[c].hue = hue;
        root.setTable(i, t);
    }
    /// Append a point to the selected table, or a new one after the rows.
    function addPointToTable(x, y) {
        let i = root.selected;
        if (i < 0 || i >= rows.count || rows.get(i).kind !== "table") {
            for (i = 0; i < rows.count && rows.get(i).kind !== "table"; i++);
        }
        if (i >= rows.count) return root.addTable(rows.count, [[x, y]]);
        const t = root.tableOf(i);
        const n = Math.max(...t.columns.map(k => k.cells.length));
        // first row whose x and y cells are both empty
        let r = 0;
        while (r < n && ((t.columns[0].cells[r] ?? "").trim() || (t.columns[1]?.cells[r] ?? "").trim())) r++;
        root.checkpoint("");
        for (const k of t.columns) while (k.cells.length <= r) k.cells.push("");
        t.columns[0].cells[r] = root.num(x);
        if (t.columns[1]) t.columns[1].cells[r] = root.num(y);
        rows.setProperty(i, "tableJson", JSON.stringify(t));
        root.selected = i;
        root.changed();
        return i;
    }
    /// Replace a point-list row with an equivalent table.
    function pointsToTable(i) {
        const pts = (root.result?.points ?? []).filter(p => p.row === i).map(p => [p.x, p.y]);
        if (pts.length === 0) return;
        const at = root.addTable(i + 1, pts);
        root.removeRow(i);
        root.selected = at - 1;
    }

    /// Set the t/θ range of a parametric or polar row by rewriting its
    /// trailing restriction: `(cos t, sin t) {0 <= t <= 2pi}`.
    function setParamRange(i, v, from, to) {
        if (i < 0 || i >= rows.count || !String(from).trim() || !String(to).trim()) return;
        let text = rows.get(i).text;
        // drop an existing trailing restriction that mentions the parameter
        const m = text.match(/\s*\{([^{}]*)\}\s*$/);
        if (m && (m[1].includes(v) || (v === "θ" && m[1].includes("theta")))) text = text.slice(0, m.index);
        root.setText(i, `${text.replace(/\s+$/, "")} {${from} <= ${v} <= ${to}}`);
    }

    // function names that contain an "x" and must not be split
    readonly property var xWords: ["exp", "max", "argmax", "lcm"]
    readonly property var xPrefixes: ["sin", "cos", "tan", "sec", "csc", "cot", "sinh", "cosh", "tanh", "ln", "log", "exp", "sqrt", "abs", "floor", "ceil", "round", "sign", "erf", "gamma"]
    /// Replace the variable x in plain text with `repl` (x_1, …), leaving
    /// function names, x_2 and x1 alone.
    function replaceX(text, repl) {
        let out = "";
        let i = 0;
        while (i < text.length) {
            if (/[A-Za-z]/.test(text[i])) {
                let k = i;
                while (k < text.length && /[A-Za-z]/.test(text[k])) k++;
                const run = text.slice(i, k);
                const subscripted = /[_0-9]/.test(text[k] ?? "");
                if (root.xWords.includes(run) || !run.includes("x") || (run === "x" && subscripted)) out += run;
                else if (run === "x") out += repl;
                else if (run.endsWith("x") && root.xPrefixes.includes(run.slice(0, -1))) out += `${run.slice(0, -1)} ${repl}`;
                else out += run.split("").map(ch => ch === "x" ? ` ${repl} ` : ch).join("");
                i = k;
            } else {
                out += text[i++];
            }
        }
        return out.replace(/ {2,}/g, " ").trim();
    }
    /// Desmos' "table of values" for a y = f(x) row: editable x column plus a
    /// column computed from the row's formula.
    function tableOfValues(i) {
        if (i < 0 || i >= rows.count) return;
        const text = rows.get(i).text;
        const n = root.freshTableIndex();
        const X = `x_${n}`;
        const fn = text.match(/^\s*([A-Za-z]\w*)\s*\(\s*x\s*\)\s*=/);
        let header;
        if (fn) header = `${fn[1]}(${X})`;
        else {
            const m = text.match(/^\s*y\s*=\s*(.+)$/) ?? text.match(/^\s*(.+?)\s*=\s*y\s*$/);
            header = root.replaceX(m ? m[1] : text, X);
        }
        const row = root.makeRow("", "table");
        row.hue = rows.get(i).hue;
        row.tableJson = JSON.stringify({ columns: [
            { header: X, cells: ["-2", "-1", "0", "1", "2"], hue: row.hue },
            { header: header, cells: [], hue: row.hue },
        ] });
        root.checkpoint("");
        rows.insert(i + 1, row);
        root.selected = i + 1;
        root.changed();
    }

    readonly property var regressionModels: [
        { id: "linear", name: "Linear", tex: "y = mx + b", params: ["m", "b"], rhs: "{m} X + {b}" },
        { id: "quadratic", name: "Quadratic", tex: "y = ax² + bx + c", params: ["a", "b", "c"], rhs: "{a} X^2 + {b} X + {c}" },
        { id: "cubic", name: "Cubic", tex: "y = ax³ + bx² + cx + d", params: ["a", "b", "c", "d"], rhs: "{a} X^3 + {b} X^2 + {c} X + {d}" },
        { id: "exponential", name: "Exponential", tex: "y = a·e^(bx)", params: ["a", "b"], rhs: "{a} e^({b} X)" },
        { id: "power", name: "Power", tex: "y = a·x^b", params: ["a", "b"], rhs: "{a} X^{b}" },
        { id: "logarithmic", name: "Logarithmic", tex: "y = a + b·ln x", params: ["a", "b"], rhs: "{a} + {b} ln(X)" },
        { id: "logistic", name: "Logistic", tex: "y = c / (1 + a·e^(−bx))", params: ["c", "a", "b"], rhs: "{c}/(1 + {a} e^(-{b} X))" },
        { id: "sinusoidal", name: "Sinusoidal", tex: "y = a·sin(bx + c) + d", params: ["a", "b", "c", "d"], rhs: "{a} sin({b} X + {c}) + {d}" },
    ]
    /// Add `Y ~ model(X)` after table row i, fitting column `ycol` against column 0.
    function addRegression(i, modelId, ycol) {
        const t = root.tableOf(i);
        const X = t.columns[0]?.header, Y = t.columns[ycol ?? 1]?.header;
        const model = root.regressionModels.find(m => m.id === modelId);
        if (!X || !Y || !model) return;
        const used = root.usedNames();
        let rhs = model.rhs;
        for (const p of model.params) {
            const name = root.fresh(p, used);
            used.add(name);
            rhs = rhs.split(`{${p}}`).join(name);
        }
        rhs = rhs.split("X").join(/^[A-Za-z]\w*$/.test(X) ? X : `(${X})`);
        root.insertRow(i + 1, `${Y} ~ ${rhs}`);
        root.selected = i + 1;
    }

    // ------------------------------------------------------------- saved graphs & examples
    property var saved: ({}) // name → { rows, deg, view, settings }

    function currentGraph() {
        return { rows: root.rowObjects(), deg: root.deg, view: { cx: root.cx, cy: root.cy, sx: root.sx, sy: root.sy }, settings: root.settings };
    }
    function applyGraph(g) {
        root.checkpoint("");
        root.loadRows(g.rows ?? []);
        root.deg = !!g.deg;
        if (g.settings) root.settings = Object.assign(root.defaultSettings(), g.settings);
        const v = g.view;
        if (v && v.sx > 0 && v.sy > 0) {
            root.cx = v.cx; root.cy = v.cy; root.sx = v.sx; root.sy = v.sy;
        }
        root.selected = 0;
        root.changed();
    }
    function saveAs(name) {
        name = String(name).trim();
        if (!name) return;
        const s = Object.assign({}, root.saved);
        s[name] = root.currentGraph();
        root.saved = s;
        saveTimer.restart();
    }
    function openSaved(name) { if (root.saved[name]) root.applyGraph(root.saved[name]); }
    function deleteSaved(name) {
        const s = Object.assign({}, root.saved);
        delete s[name];
        root.saved = s;
        saveTimer.restart();
    }
    readonly property var examples: [
        { name: "Heart", view: [0, 0.2, 0.012], rows: ["(x^2 + y^2 - 1)^3 = x^2 y^3", "(x^2 + y^2 - 1)^3 < x^2 y^3"] },
        { name: "Rose (slider)", view: [0, 0, 0.012], rows: ["r = cos(k θ) {0 <= θ <= 2pi}", "k = 4"] },
        { name: "Lissajous", view: [0, 0, 0.008], rows: ["(sin(a t + d), sin(b t)) {0 <= t <= 2pi}", "a = 3", "b = 2", "d = 0.5"] },
        { name: "Unit circle & angle", view: [0, 0, 0.006], rows: ["x^2 + y^2 = 1", "(cos a, sin a)", "a = 0.8", "y = tan(a) x {0 <= x <= cos a}", "(cos a, 0)"] },
        { name: "Tangent line", view: [0, 0, 0.012], rows: ["f(x) = sin(x) + x/3", "(a, f(a))", "a = 1", "y = f'(a)(x - a) + f(a)"] },
        { name: "Linear regression", view: [4, 5, 0.018], table: [[0, 1.8], [1, 3.1], [2, 3.9], [3, 5.2], [4, 5.8], [5, 7.1], [6, 8.2], [7, 8.8]], rows: ["y_1 ~ m x_1 + b"] },
        { name: "Riemann sum", view: [2, 2, 0.01], rows: ["f(x) = 1 + x/2 + sin(x)", "n = 8", "0 <= y <= f(4 floor(n x/4)/n) {0 <= x <= 4}", "int(f(x), x, 0, 4)", "sum(f(4k/n) 4/n, k, 0, n - 1)"] },
        { name: "Inequalities", view: [0, 0, 0.018], rows: ["y > x^2 - 4", "y < 2 - x/2", "x^2 + y^2 <= 9 {y < 0}"] },
        { name: "Polar spiral", view: [0, 0, 0.04], rows: ["r = θ {0 <= θ <= 6pi}"] },
        { name: "Normal distribution", view: [0, 0.2, 0.006], rows: ["y = e^(-(x - m)^2/(2s^2))/(s sqrt(2pi))", "m = 0", "s = 1", "int(e^(-t^2/2)/sqrt(2pi), t, -1, 1)"] },
    ]
    function openExample(ex) {
        const n = root.freshTableIndex();
        const g = { rows: [], deg: false, view: { cx: ex.view[0], cy: ex.view[1], sx: ex.view[2], sy: ex.view[2] } };
        const hueBase = root.nextColor;
        let k = 0;
        if (ex.table) {
            const r = root.makeRow("", "table");
            r.hue = hueBase + k++;
            r.tableJson = JSON.stringify({ columns: [
                { header: "x_1", cells: ex.table.map(p => String(p[0])), hue: r.hue },
                { header: "y_1", cells: ex.table.map(p => String(p[1])), hue: r.hue },
            ] });
            g.rows.push(r);
        }
        for (const t of ex.rows) {
            const r = root.makeRow(t);
            r.hue = hueBase + k++;
            g.rows.push(r);
        }
        root.nextColor = hueBase + k;
        root.applyGraph(g);
    }
    /// All rows as plain text (tables become list definitions); paste restores them.
    function copyExpressions() {
        const lines = [];
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            if (r.kind === "table") {
                for (const c of root.tableOf(i).columns)
                    if (/^[A-Za-z]\w*$/.test(c.header.trim())) lines.push(`${c.header} = [${c.cells.filter(v => v.trim()).join(", ")}]`);
            } else if (r.text.trim()) {
                lines.push(r.text);
            }
        }
        Quickshell.execDetached(["wl-copy", "--", lines.join("\n")]);
        return lines.length;
    }

    // ------------------------------------------------------------- numbers
    /// Short decimal text for a value (no float noise).
    function num(v) {
        if (!isFinite(v)) return "";
        const a = Math.abs(v);
        if (a !== 0 && (a >= 1e7 || a < 1e-5)) return v.toExponential(4).replace(/\.?0+e/, "e");
        return String(parseFloat(v.toPrecision(8)));
    }
    /// Round a coordinate to what a pixel can resolve (for dragged points).
    function snap(v, perPixel) {
        const p = Math.pow(10, Math.floor(Math.log10(Math.max(perPixel * 2, 1e-12))));
        return Math.round(v / p) * p;
    }

    // ------------------------------------------------------------- sliders
    function sliderRowOf(name) {
        const rs = root.result?.rows ?? [];
        for (let k = 0; k < rs.length && k < rows.count; k++)
            if (rs[k]?.type === "slider" && rs[k].name === name) return k;
        return -1;
    }
    /// Rewrite `name = value` keeping the left-hand side as typed.
    function setSliderValue(i, v, key) {
        if (i < 0 || i >= rows.count) return;
        const r = rows.get(i);
        const step = r.step > 0 ? r.step : 0;
        if (step > 0) v = Math.round((v - r.min) / step) * step + r.min;
        v = Math.max(r.min, Math.min(r.max, v));
        const decimals = step > 0 ? Math.max(0, Math.min(10, -Math.floor(Math.log10(step) + 1e-9))) : 4;
        let s = v.toFixed(decimals);
        if (s.includes(".")) s = s.replace(/0+$/, "").replace(/\.$/, "");
        if (s === "-0") s = "0";
        const lhs = r.text.split("=")[0].trim();
        root.checkpoint(key ?? `slider:${i}`);
        rows.setProperty(i, "text", `${lhs} = ${s}`);
        if (root.result?.rows?.[i]?.type === "slider") root.result.rows[i].value = v;
        root.changed();
    }

    /// Leaving a row: create sliders for letters the backend reported undefined.
    function commitRow(i) {
        const info = root.result?.rows?.[i];
        const names = (info?.undefined ?? []).filter(n => n.length <= 12).slice(0, 8);
        if (names.length === 0) return 0;
        root.checkpoint("");
        names.forEach((n, k) => rows.insert(i + 1 + k, root.makeRow(`${n} = 1`)));
        root.changed();
        return names.length;
    }

    // ------------------------------------------------------------- dragging points
    /// Move a draggable point of row i to (x, y). For tables, `s` is the y
    /// column (0-based among y columns) and `index` the plotted point.
    function dragPoint(i, x, y, perPixelX, perPixelY, s, index) {
        if (i < 0 || i >= rows.count) return;
        const r = rows.get(i);
        const nx = root.snap(x, perPixelX), ny = root.snap(y, perPixelY);
        if (r.kind === "table") {
            const t = root.tableOf(i);
            const info = root.result?.rows?.[i];
            const xs = info?.columns?.[0]?.values ?? [];
            const ys = info?.columns?.[s + 1]?.values ?? [];
            // map the plotted index back to the data row (non-finite rows are skipped)
            let k = -1, seen = -1;
            for (let j = 0; j < Math.min(xs.length, ys.length); j++) {
                if (xs[j] !== null && ys[j] !== null && isFinite(xs[j]) && isFinite(ys[j])) seen++;
                if (seen === index) { k = j; break; }
            }
            if (k < 0) return;
            const isNum = c => /^\s*-?\d*\.?\d+(e-?\d+)?\s*$/i.test(c ?? "");
            root.checkpoint(`drag:${i}:${s}:${index}`);
            if (isNum(t.columns[0].cells[k])) t.columns[0].cells[k] = root.num(nx);
            if (t.columns[s + 1] && isNum(t.columns[s + 1].cells[k])) t.columns[s + 1].cells[k] = root.num(ny);
            rows.setProperty(i, "tableJson", JSON.stringify(t));
            root.changed();
            return;
        }
        const drag = root.result?.rows?.[i]?.drag;
        if (!drag) return;
        if (drag.x === "#" && drag.y === "#") {
            const m = r.text.match(/^(\s*(?:[A-Za-z]\w*\s*=\s*)?)\(/);
            root.checkpoint(`drag:${i}`);
            rows.setProperty(i, "text", `${m ? m[1] : ""}(${root.num(nx)}, ${root.num(ny)})`);
            root.changed();
            return;
        }
        for (const [axis, v] of [["x", nx], ["y", ny]]) {
            const name = drag[axis];
            if (!name || name === "#") continue;
            const k = root.sliderRowOf(name);
            if (k >= 0) root.setSliderValue(k, v, `drag:${i}`);
        }
    }
    function isDraggable(i) {
        if (i < 0 || i >= rows.count) return false;
        if (rows.get(i).kind === "table") return true;
        return !!root.result?.rows?.[i]?.drag;
    }

    // ------------------------------------------------------------- view
    function resetView() {
        root.cx = 0;
        root.cy = 0;
        root.sx = 0.025;
        root.sy = 0.025;
        root.changed();
    }
    function zoomAt(factor, wx, wy) {
        const nsx = Math.max(1e-12, Math.min(1e12, root.sx * factor));
        const nsy = Math.max(1e-12, Math.min(1e12, root.sy * factor));
        root.cx = wx + (root.cx - wx) * (nsx / root.sx);
        root.cy = wy + (root.cy - wy) * (nsy / root.sy);
        root.sx = nsx;
        root.sy = nsy;
        root.changed();
    }
    function setBounds(xmin, xmax, ymin, ymax) {
        if (!(xmax > xmin) || !(ymax > ymin) || root.width < 10 || root.height < 10) return false;
        root.cx = (xmin + xmax) / 2;
        root.cy = (ymin + ymax) / 2;
        root.sx = (xmax - xmin) / root.width;
        root.sy = (ymax - ymin) / root.height;
        if (root.settings.lockSquare) root.sx = root.sy = Math.max(root.sx, root.sy);
        root.changed();
        return true;
    }
    /// Zoom to fit everything drawn (points, tables, else curve extents).
    function zoomFit() {
        const r = root.result, v = root.resultView;
        if (!r || !v) return;
        const xs = [], ys = [];
        const wx = px => v.cx + (px - v.width / 2) * v.sx;
        const wy = py => v.cy - (py - v.height / 2) * v.sy;
        for (const p of r.points ?? []) { xs.push(p.x); ys.push(p.y); }
        for (const t of r.tables ?? []) for (const s of t.series) for (let k = 0; k + 1 < s.length; k += 2) { xs.push(s[k]); ys.push(s[k + 1]); }
        if (xs.length === 0) {
            for (const c of r.curves ?? []) for (const l of c.lines) for (let k = 0; k + 1 < l.length; k += 2) { xs.push(wx(l[k])); ys.push(wy(l[k + 1])); }
        }
        if (xs.length === 0) return;
        let x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
        if (x1 - x0 < 1e-9) { x0 -= 1; x1 += 1; }
        if (y1 - y0 < 1e-9) { y0 -= 1; y1 += 1; }
        const padX = (x1 - x0) * 0.12, padY = (y1 - y0) * 0.12;
        root.setBounds(x0 - padX, x1 + padX, y0 - padY, y1 + padY);
    }

    // ------------------------------------------------------------- rendering
    property int users: 0 // mounted Graph tabs
    property var result: null // latest render from metis
    property var resultView: null // view that `result` was rendered for
    property var probeResult: null
    property bool failed: false
    property string failReason: ""
    property string stderrText: ""
    property real width: 0
    property real height: 0

    property int nextId: 1
    property int inFlightId: 0
    property string inFlightKind: ""
    property var inFlightView: null
    property var pending: null // latest unsent render
    property var pendingProbe: null // latest unsent probe

    function acquire() {
        root.users++;
        root.failed = false;
        if (!proc.running) proc.running = true;
        root.render();
    }
    function release() {
        root.users = Math.max(0, root.users - 1);
        if (root.users === 0) stopTimer.restart();
    }

    function requestRows() {
        const out = [];
        for (let i = 0; i < rows.count; i++) {
            const r = rows.get(i);
            if (r.kind === "table")
                out.push({ table: { columns: root.tableOf(i).columns.map(c => ({ header: c.header, cells: c.cells })) }, hidden: r.hidden });
            else
                out.push({ text: r.text, hidden: r.hidden, style: r.lineStyle !== "solid" ? r.lineStyle : undefined });
        }
        return out;
    }

    function render(probe) {
        if (root.width < 10 || root.height < 10 || !root.loaded) return;
        const view = { cx: root.cx, cy: root.cy, sx: root.sx, sy: root.sy, width: root.width, height: root.height };
        const req = {
            id: root.nextId++,
            rows: root.requestRows(),
            deg: root.deg,
            cx: view.cx, cy: view.cy, sx: view.sx, sy: view.sy,
            width: Math.round(view.width), height: Math.round(view.height),
            res: 2,
            sel: root.selected,
        };
        if (probe) req.probe = probe;
        root.pending = { req: req, view: view };
        root.pump();
    }
    /// Exact point on row i under world x (y for x = f(y)); answer in probeResult.
    function probe(i, x, y) {
        root.pendingProbe = { id: root.nextId++, cmd: "probe", row: i, x: x, y: y };
        root.pump();
    }

    function pump() {
        if (root.inFlightId !== 0 || !proc.running) return;
        if (root.pendingProbe) {
            const p = root.pendingProbe;
            root.pendingProbe = null;
            root.inFlightId = p.id;
            root.inFlightKind = "probe";
            proc.write(JSON.stringify(p) + "\n");
            watchdog.restart();
            return;
        }
        if (!root.pending) return;
        const p = root.pending;
        root.pending = null;
        root.inFlightId = p.req.id;
        root.inFlightKind = "render";
        root.inFlightView = p.view;
        proc.write(JSON.stringify(p.req) + "\n");
        watchdog.restart();
    }

    function onLine(line) {
        let msg;
        try { msg = JSON.parse(line); } catch (e) { console.warn("[Metis] bad response:", e); return; }
        if (msg.id !== undefined && msg.id === root.inFlightId) {
            watchdog.stop();
            root.inFlightId = 0;
            if (msg.error) {
                console.warn("[Metis]", msg.error);
            } else if (root.inFlightKind === "probe") {
                root.probeResult = msg.probe;
            } else {
                if (root.failReason === "timeout") root.failReason = "";
                root.resultView = root.inFlightView;
                root.result = msg;
                if (msg.probe) root.probeResult = msg.probe;
            }
        }
        root.pump();
    }

    onChanged: {
        root.render();
        saveTimer.restart();
    }
    onWidthChanged: root.render()
    onHeightChanged: root.render()
    onSelectedChanged: root.render()
    onDegChanged: root.changed()

    Process {
        id: proc
        command: ["sh", "-c", `exec ${root.command} --serve`]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.onLine(line)
        }
        stderr: SplitParser {
            onRead: line => root.stderrText = line
        }
        onStarted: {
            root.inFlightId = 0;
            root.pump();
            root.render();
        }
        onExited: (exitCode, exitStatus) => {
            root.inFlightId = 0;
            watchdog.stop();
            if (root.users === 0) return;
            if (exitCode === 127) {
                root.failed = true;
                root.failReason = "notfound";
                return;
            }
            restartTimer.restart();
        }
    }

    // A single render should never take this long; restart metis
    Timer {
        id: watchdog
        interval: 6000
        onTriggered: {
            console.warn("[Metis] render timed out, restarting backend");
            root.failReason = "timeout";
            proc.running = false;
        }
    }
    Timer {
        id: restartTimer
        interval: 400
        onTriggered: if (root.users > 0 && !root.failed) proc.running = true
    }
    Timer {
        id: stopTimer
        interval: 30000 // keep warm briefly after the tab closes
        onTriggered: if (root.users === 0) proc.running = false
    }

    // ------------------------------------------------------------- slider animation
    property bool animating: false
    property real lastTick: 0
    function updateAnimating() {
        let any = false;
        for (let i = 0; i < rows.count; i++) if (rows.get(i).playing) any = true;
        root.animating = any;
    }
    function togglePlay(i) {
        if (i < 0 || i >= rows.count) return;
        rows.setProperty(i, "playing", !rows.get(i).playing);
        root.lastTick = Date.now();
        root.updateAnimating();
    }
    Timer {
        interval: 33
        repeat: true
        running: root.users > 0 && root.animating
        onTriggered: {
            const now = Date.now();
            const dt = Math.min(0.2, (now - (root.lastTick || now)) / 1000);
            root.lastTick = now;
            for (let i = 0; i < rows.count; i++) {
                const r = rows.get(i);
                if (!r.playing) continue;
                const info = root.result?.rows?.[i];
                if (info?.type !== "slider") continue;
                let dir = r.dir ?? 1;
                let v = (info.value ?? 0) + dir * (r.max - r.min) * dt / 6 * (r.speed || 1);
                if (v > r.max || v < r.min) {
                    if (r.loopMode === "loop") {
                        v = dir > 0 ? r.min : r.max;
                    } else if (r.loopMode === "once") {
                        v = Math.max(r.min, Math.min(r.max, v));
                        rows.setProperty(i, "playing", false);
                        root.updateAnimating();
                    } else {
                        v = Math.max(r.min, Math.min(r.max, v));
                        dir = -dir;
                    }
                }
                rows.setProperty(i, "dir", dir);
                // high precision while animating so small steps don't stall
                const lhs = r.text.split("=")[0].trim();
                rows.setProperty(i, "text", `${lhs} = ${parseFloat(v.toFixed(5))}`);
                info.value = v;
            }
            root.render();
            saveTimer.restart();
        }
    }

    // ------------------------------------------------------------- persistence
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: stateView.setText(JSON.stringify({
            version: 2, deg: root.deg, view: { cx: root.cx, cy: root.cy, sx: root.sx, sy: root.sy },
            settings: root.settings, rows: root.rowObjects(), nextColor: root.nextColor, saved: root.saved,
        }, null, 1))
    }

    FileView {
        id: stateView
        path: root.stateFile
        onLoaded: {
            let d = {};
            try { d = JSON.parse(stateView.text()); } catch (e) { d = {}; }
            root.nextColor = d.nextColor ?? (d.rows ?? []).length;
            if ((d.rows ?? []).length > 0) root.loadRows(d.rows);
            else root.loadExample();
            root.deg = !!d.deg;
            root.settings = Object.assign(root.defaultSettings(), d.settings ?? {});
            root.saved = d.saved ?? {};
            const v = d.view ?? {};
            const sx = v.sx ?? v.scale, sy = v.sy ?? v.scale;
            if (sx > 0 && sy > 0) {
                root.cx = v.cx ?? 0;
                root.cy = v.cy ?? 0;
                root.sx = sx;
                root.sy = sy;
            }
            root.loaded = true;
            root.render();
        }
        onLoadFailed: error => {
            root.loadExample();
            root.loaded = true;
            root.render();
        }
    }

    function loadExample() {
        root.rows.clear();
        for (const t of ["y = a sin(b x)", "a = 2", "b = 1", "x^2 + y^2 < 9", ""])
            root.rows.append(root.makeRow(t));
    }

    IpcHandler {
        target: "graph"
        function open(): void { GlobalStates.dashboardTab = "graph"; GlobalStates.dashboardOpen = true; }
        function add(expression: string): void {
            root.insertRow(root.rows.count, expression);
            GlobalStates.dashboardTab = "graph";
            GlobalStates.dashboardOpen = true;
        }
        function clear(): void { root.clearAll(); }
        function undo(): void { root.undo(); }
    }
}
