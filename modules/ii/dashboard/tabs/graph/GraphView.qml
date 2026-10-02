pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * The graph paper: grid, curves, regions, points, tables and all mouse
 * interaction (pan, zoom, drag points, trace curves, pin coordinates).
 */
Rectangle {
    id: view

    property var pin: null // { x, y, row, kind: ""|"root"|…|"location", s, index }
    property var hover: null // world coordinates under the mouse
    property var hoverPoi: null
    property bool showSettings: false
    property string toast: ""

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.large
    border.width: Appearance.sizes.borderWidth > 1 ? Appearance.sizes.borderWidth : 0
    border.color: Appearance.colors.colLayer0Border
    clip: true

    function fmt(v) {
        if (v === null || v === undefined || !isFinite(v)) return Translation.tr("undefined");
        const a = Math.abs(v);
        if (a !== 0 && (a >= 1e6 || a < 1e-4)) return v.toExponential(3).replace(/\.?0+e/, "e");
        return String(parseFloat(v.toPrecision(6)));
    }
    function row(i) { return i >= 0 && i < Metis.rows.count ? Metis.rows.get(i) : null; }
    function rowColor(i, hueOverride) {
        const r = view.row(i);
        if (!r) return Appearance.colors.colSubtext;
        return Metis.colorOf(hueOverride ?? r.hue);
    }
    function focusPaper() { area.forceActiveFocus(); }
    function clearPin() {
        view.pin = null;
        plot.requestPaint();
    }

    // ------------------------------------------------------------- geometry
    Item {
        id: area
        anchors.fill: parent
        anchors.margins: 1
        onWidthChanged: { Metis.width = width; grid.requestPaint(); }
        onHeightChanged: { Metis.height = height; grid.requestPaint(); }
        Component.onCompleted: {
            Metis.width = width;
            Metis.height = height;
        }

        function toPx(x) { return (x - Metis.cx) / Metis.sx + width / 2; }
        function toPy(y) { return height / 2 - (y - Metis.cy) / Metis.sy; }
        function toWx(px) { return Metis.cx + (px - width / 2) * Metis.sx; }
        function toWy(py) { return Metis.cy - (py - height / 2) * Metis.sy; }

        /// Transform from the pixel space of the last result to the current view.
        function resultTransform() {
            const v = Metis.resultView;
            if (!v) return null;
            return {
                kx: v.sx / Metis.sx,
                ky: v.sy / Metis.sy,
                tx: (v.cx - v.width / 2 * v.sx - Metis.cx) / Metis.sx + width / 2,
                ty: height / 2 - (v.cy + v.height / 2 * v.sy - Metis.cy) / Metis.sy,
            };
        }

        Connections {
            target: Metis
            function onCxChanged() { area.repaint(); }
            function onCyChanged() { area.repaint(); }
            function onSxChanged() { area.repaint(); }
            function onSyChanged() { area.repaint(); }
            function onSettingsChanged() { area.repaint(); }
            function onResultChanged() { plot.requestPaint(); }
            function onSelectedChanged() { plot.requestPaint(); }
            function onProbeResultChanged() {
                const p = Metis.probeResult;
                if (p && view.pin && p.row === view.pin.row && !view.pin.kind) {
                    view.pin = Object.assign({}, view.pin, { x: p.x, y: p.y });
                    plot.requestPaint();
                }
            }
        }
        Connections {
            target: Metis.rows
            function onDataChanged() { plot.requestPaint(); }
        }
        Connections {
            target: Appearance.colors
            function onColLayer1Changed() { area.repaint(); }
        }
        function repaint() {
            grid.requestPaint();
            plot.requestPaint();
        }
        onVisibleChanged: if (visible) repaint()

        // ---- grid, axes and tick labels
        Canvas {
            id: grid
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const W = width, H = height, sx = Metis.sx, sy = Metis.sy, st = Metis.settings;
                if (W <= 0 || H <= 0 || !(sx > 0) || !(sy > 0)) return;
                const nice = m => {
                    const p = Math.pow(10, Math.floor(Math.log10(m)));
                    for (const k of [1, 2, 5, 10]) if (k * p >= m) return { step: k * p, lead: k };
                    return { step: 10 * p, lead: 1 };
                };
                let mx = nice(95 * sx), my = nice(95 * sy);
                if (Math.abs(sx / sy - 1) < 1e-9) my = mx = (mx.step >= my.step ? mx : my);
                const minor = m => m.step / (m.lead === 2 ? 4 : 5);
                const fg = Appearance.colors.colOnLayer1;
                const px = x => (x - Metis.cx) / sx + W / 2;
                const py = y => H / 2 - (y - Metis.cy) / sy;
                const x0 = Metis.cx - W / 2 * sx, x1 = Metis.cx + W / 2 * sx;
                const y0 = Metis.cy - H / 2 * sy, y1 = Metis.cy + H / 2 * sy;
                const ax = Math.round(px(0)) + 0.5, ay = Math.round(py(0)) + 0.5;

                if (st.polarGrid) {
                    // circles at the major step, rays every 15° (every 30° bolder)
                    const rmax = Math.hypot(Math.max(Math.abs(x0), Math.abs(x1)), Math.max(Math.abs(y0), Math.abs(y1)));
                    ctx.strokeStyle = ColorUtils.transparentize(fg, 0.89);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    let n = 0;
                    for (let r = mx.step; r <= rmax && n < 400; r += mx.step, n++) {
                        ctx.moveTo(px(r), py(0));
                        ctx.ellipse(px(-r), py(r), 2 * r / sx, 2 * r / sy);
                    }
                    for (let k = 0; k < 24; k++) {
                        const a = k * Math.PI / 12;
                        ctx.moveTo(ax, ay);
                        ctx.lineTo(px(rmax * Math.cos(a)), py(rmax * Math.sin(a)));
                    }
                    ctx.stroke();
                } else if (st.grid) {
                    const lines = (stepX, stepY, alpha) => {
                        ctx.strokeStyle = ColorUtils.transparentize(fg, 1 - alpha);
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        let n = 0;
                        for (let k = Math.ceil(x0 / stepX); k * stepX <= x1 && n < 800; k++, n++) {
                            const X = Math.round(px(k * stepX)) + 0.5;
                            ctx.moveTo(X, 0); ctx.lineTo(X, H);
                        }
                        n = 0;
                        for (let k = Math.ceil(y0 / stepY); k * stepY <= y1 && n < 800; k++, n++) {
                            const Y = Math.round(py(k * stepY)) + 0.5;
                            ctx.moveTo(0, Y); ctx.lineTo(W, Y);
                        }
                        ctx.stroke();
                    };
                    if (st.minorGrid && minor(mx) / sx > 6) lines(minor(mx), minor(my), 0.045);
                    lines(mx.step, my.step, 0.11);
                }

                if (st.axes) {
                    ctx.strokeStyle = ColorUtils.transparentize(fg, 0.35);
                    ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    if (ax >= 0 && ax <= W) { ctx.moveTo(ax, 0); ctx.lineTo(ax, H); }
                    if (ay >= 0 && ay <= H) { ctx.moveTo(0, ay); ctx.lineTo(W, ay); }
                    ctx.stroke();
                }

                ctx.font = `${Appearance.font.pixelSize.smallest}px "${Appearance.font.family.main}"`;
                ctx.lineWidth = 3;
                ctx.strokeStyle = Appearance.colors.colLayer1Base;
                ctx.fillStyle = Appearance.colors.colSubtext;
                const text = (t, x, y) => { ctx.strokeText(t, x, y); ctx.fillText(t, x, y); };
                const ly = Math.min(Math.max(ay + 14, 14), H - 5);
                const onRight = ax < 30;
                const lx = onRight ? Math.max(ax + 6, 4) : Math.min(ax - 6, W - 4);
                if (st.axisNumbers) {
                    const label = (v, step) => {
                        if (Math.abs(v) < step * 1e-6) return "0";
                        const a = Math.abs(v);
                        if (a >= 1e6 || a < 1e-4) return v.toExponential(1).replace("-", "−");
                        return v.toFixed(Math.max(0, -Math.floor(Math.log10(step)))).replace("-", "−");
                    };
                    ctx.textAlign = "center";
                    for (let k = Math.ceil(x0 / mx.step), n = 0; k * mx.step <= x1 && n < 400; k++, n++) {
                        if (k === 0) continue;
                        const X = px(k * mx.step);
                        if (X < 12 || X > W - 12) continue;
                        text(label(k * mx.step, mx.step), X, ly);
                    }
                    ctx.textAlign = onRight ? "left" : "right";
                    for (let k = Math.ceil(y0 / my.step), n = 0; k * my.step <= y1 && n < 400; k++, n++) {
                        if (k === 0) continue;
                        const Y = py(k * my.step);
                        if (Y < 10 || Y > H - 10) continue;
                        text(label(k * my.step, my.step), lx, Y + 4);
                    }
                    if (ax >= 0 && ax <= W && ay >= 0 && ay <= H) {
                        ctx.textAlign = "right";
                        text("0", ax - 5, ly);
                    }
                }
                // axis names
                ctx.font = `italic ${Appearance.font.pixelSize.small}px "${Appearance.font.family.main}"`;
                ctx.fillStyle = Appearance.colors.colOnLayer1;
                if (st.xLabel) { ctx.textAlign = "right"; text(st.xLabel, W - 8, Math.min(Math.max(ay - 8, 16), H - 20)); }
                if (st.yLabel) { ctx.textAlign = onRight ? "left" : "right"; text(st.yLabel, onRight ? Math.max(ax + 8, 8) : Math.min(ax - 8, W - 8), 18); }
            }
        }

        // ---- curves, regions, points, tables
        Canvas {
            id: plot
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const r = Metis.result;
                const t = area.resultTransform();
                if (!r || !t) return;
                const sel = Metis.selected;
                const k = Math.sqrt(t.kx * t.ky);

                ctx.save();
                ctx.setTransform(t.kx, 0, 0, t.ky, t.tx, t.ty);
                for (const reg of (r.regions ?? [])) {
                    const rr = view.row(reg.row);
                    ctx.fillStyle = ColorUtils.transparentize(view.rowColor(reg.row), 1 - (rr?.fillOpacity ?? 0.25));
                    // one path → one fill: no seams or double alpha between runs
                    const c = reg.cell, runs = reg.runs;
                    ctx.beginPath();
                    for (let i = 0; i + 2 < runs.length; i += 3)
                        ctx.rect(runs[i + 1] * c, runs[i] * c, runs[i + 2] * c, c);
                    ctx.fill();
                }
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                for (const c of (r.curves ?? [])) {
                    const rr = view.row(c.row);
                    ctx.strokeStyle = ColorUtils.transparentize(view.rowColor(c.row), 1 - (rr?.opacity ?? 1));
                    ctx.lineWidth = ((rr?.lineWidth ?? 2.5) + (c.row === sel ? 0.8 : 0)) / k;
                    ctx.beginPath();
                    for (const l of c.lines) {
                        ctx.moveTo(l[0], l[1]);
                        for (let j = 2; j + 1 < l.length; j += 2) ctx.lineTo(l[j], l[j + 1]);
                    }
                    ctx.stroke();
                }
                ctx.restore();

                const P = (x, y) => [area.toPx(x), area.toPy(y)];
                const marker = (X, Y, style, color, size) => {
                    if (X < -12 || Y < -12 || X > width + 12 || Y > height + 12) return;
                    ctx.beginPath();
                    if (style === "cross") {
                        ctx.lineWidth = 2.5;
                        ctx.strokeStyle = color;
                        ctx.moveTo(X - size, Y - size); ctx.lineTo(X + size, Y + size);
                        ctx.moveTo(X + size, Y - size); ctx.lineTo(X - size, Y + size);
                        ctx.stroke();
                        return;
                    }
                    ctx.arc(X, Y, size, 0, Math.PI * 2);
                    if (style === "open") {
                        ctx.fillStyle = Appearance.colors.colLayer1Base;
                        ctx.fill();
                        ctx.lineWidth = 2.5;
                        ctx.strokeStyle = color;
                        ctx.stroke();
                    } else {
                        ctx.fillStyle = color;
                        ctx.fill();
                    }
                };
                const labels = [];
                const series = (rowIdx, pts, color, rr) => {
                    // pts: flat world coordinates
                    if (rr?.connect && pts.length >= 4) {
                        ctx.beginPath();
                        ctx.lineWidth = rr.lineWidth ?? 2.5;
                        ctx.strokeStyle = ColorUtils.transparentize(color, 1 - (rr.opacity ?? 1));
                        ctx.lineJoin = "round";
                        for (let j = 0; j + 1 < pts.length; j += 2) {
                            const [X, Y] = P(pts[j], pts[j + 1]);
                            if (j === 0) ctx.moveTo(X, Y); else ctx.lineTo(X, Y);
                        }
                        ctx.stroke();
                    }
                    const n = pts.length / 2;
                    const draggable = Metis.isDraggable(rowIdx);
                    for (let j = 0; j + 1 < pts.length; j += 2) {
                        const [X, Y] = P(pts[j], pts[j + 1]);
                        if (draggable && n <= 200) {
                            // Desmos-style halo marks movable points
                            ctx.beginPath();
                            ctx.arc(X, Y, 11, 0, Math.PI * 2);
                            ctx.fillStyle = ColorUtils.transparentize(color, 0.82);
                            ctx.fill();
                        }
                        marker(X, Y, rr?.pointStyle ?? "dot", color, n > 2000 ? 2 : 4.5);
                        if (rr?.showLabel && n <= 60) labels.push([X, Y, `(${view.fmt(pts[j])}, ${view.fmt(pts[j + 1])})`, color]);
                    }
                };
                const byRow = {};
                for (const p of (r.points ?? [])) (byRow[p.row] = byRow[p.row] ?? []).push(p.x, p.y);
                for (const key in byRow) series(Number(key), byRow[key], view.rowColor(Number(key)), view.row(Number(key)));
                for (const tb of (r.tables ?? [])) {
                    const cols = Metis.tableOf(tb.row).columns;
                    tb.series.forEach((s, c) => series(tb.row, s, view.rowColor(tb.row, cols[c + 1]?.hue), view.row(tb.row)));
                }
                for (const p of (r.pois ?? [])) {
                    const [X, Y] = P(p.x, p.y);
                    marker(X, Y, "open", ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.4), 4.5);
                }
                if (view.pin) {
                    const [X, Y] = P(view.pin.x, view.pin.y);
                    if (view.pin.kind === "location") {
                        ctx.lineWidth = 1.5;
                        ctx.strokeStyle = Appearance.colors.colOnLayer1;
                        ctx.beginPath();
                        ctx.moveTo(X - 7, Y); ctx.lineTo(X + 7, Y);
                        ctx.moveTo(X, Y - 7); ctx.lineTo(X, Y + 7);
                        ctx.stroke();
                    } else {
                        marker(X, Y, "dot", view.rowColor(view.pin.row, view.pin.hue), 6.5);
                        marker(X, Y, "dot", Appearance.colors.colLayer1, 2.5);
                    }
                }
                ctx.font = `${Appearance.font.pixelSize.smallest}px "${Appearance.font.family.main}"`;
                ctx.textAlign = "left";
                ctx.lineWidth = 3;
                for (const [X, Y, s, color] of labels) {
                    ctx.strokeStyle = Appearance.colors.colLayer1Base;
                    ctx.strokeText(s, X + 8, Y - 8);
                    ctx.fillStyle = color;
                    ctx.fillText(s, X + 8, Y - 8);
                }
            }
        }

        // ---- hit testing
        /// Nearest draggable point within 12px: { row, s, index, x, y }.
        function hitDraggable(mx, my) {
            const r = Metis.result;
            if (!r) return null;
            let best = null;
            const test = (row, s, index, x, y) => {
                const d = Math.hypot(area.toPx(x) - mx, area.toPy(y) - my);
                if (d < 12 && (!best || d < best.d)) best = { d: d, row: row, s: s, index: index, x: x, y: y };
            };
            const counts = {};
            for (const p of (r.points ?? [])) {
                counts[p.row] = (counts[p.row] ?? -1) + 1;
                if (r.rows?.[p.row]?.drag) test(p.row, 0, counts[p.row], p.x, p.y);
            }
            for (const tb of (r.tables ?? []))
                tb.series.forEach((s, c) => { for (let j = 0; j + 1 < s.length; j += 2) test(tb.row, c, j / 2, s[j], s[j + 1]); });
            return best;
        }
        /// Nearest curve vertex (any row, or only `onlyRow`) within `radius` px.
        function hitCurve(mx, my, radius, onlyRow) {
            const r = Metis.result;
            const t = area.resultTransform();
            if (!r || !t) return null;
            let best = null;
            for (const c of (r.curves ?? [])) {
                if (onlyRow !== undefined && c.row !== onlyRow) continue;
                for (const l of c.lines) {
                    for (let j = 0; j + 1 < l.length; j += 2) {
                        const X = l[j] * t.kx + t.tx, Y = l[j + 1] * t.ky + t.ty;
                        const d = Math.hypot(X - mx, Y - my);
                        if (d < radius && (!best || d < best.d)) best = { d: d, row: c.row, x: area.toWx(X), y: area.toWy(Y) };
                    }
                }
            }
            return best;
        }
        function hitPoi(mx, my, radius) {
            let best = null;
            for (const p of (Metis.result?.pois ?? [])) {
                const d = Math.hypot(area.toPx(p.x) - mx, area.toPy(p.y) - my);
                if (d < radius && (!best || d < best.d)) best = Object.assign({ d: d }, p);
            }
            return best;
        }
        function hitPoint(mx, my) {
            let best = null;
            const r = Metis.result;
            const test = (row, x, y, hue) => {
                const d = Math.hypot(area.toPx(x) - mx, area.toPy(y) - my);
                if (d < 10 && (!best || d < best.d)) best = { d: d, row: row, x: x, y: y, hue: hue };
            };
            for (const p of (r?.points ?? [])) test(p.row, p.x, p.y);
            for (const tb of (r?.tables ?? [])) {
                const cols = Metis.tableOf(tb.row).columns;
                tb.series.forEach((s, c) => { for (let j = 0; j + 1 < s.length; j += 2) test(tb.row, s[j], s[j + 1], cols[c + 1]?.hue); });
            }
            return best;
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: mode === "pan" && pressed ? Qt.ClosedHandCursor
                : mode === "drag" || overDraggable ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                : Qt.CrossCursor
            property string mode: "" // pan | drag | trace
            property var target: null
            property real startX: 0
            property real startY: 0
            property real startCx: 0
            property real startCy: 0
            property bool moved: false
            property bool overDraggable: false

            onPressed: event => {
                area.forceActiveFocus();
                view.showSettings = false;
                if (event.button === Qt.RightButton) {
                    view.clearPin();
                    return;
                }
                startX = event.x; startY = event.y;
                startCx = Metis.cx; startCy = Metis.cy;
                moved = false;
                const d = area.hitDraggable(event.x, event.y);
                if (d) {
                    mode = "drag";
                    target = d;
                    Metis.selected = d.row;
                    return;
                }
                const poi = area.hitPoi(event.x, event.y, 9);
                const pt = area.hitPoint(event.x, event.y);
                if (poi || pt) {
                    mode = "";
                    view.pin = poi ? { x: poi.x, y: poi.y, row: Metis.selected, kind: poi.kind } : { x: pt.x, y: pt.y, row: pt.row, kind: "point", hue: pt.hue };
                    if (pt && !poi) Metis.selected = pt.row;
                    plot.requestPaint();
                    return;
                }
                const c = area.hitCurve(event.x, event.y, 9);
                if (c) {
                    // Desmos: pressing on a curve traces it while dragging
                    mode = "trace";
                    target = c;
                    Metis.selected = c.row;
                    view.pin = { x: c.x, y: c.y, row: c.row, kind: "" };
                    Metis.probe(c.row, area.toWx(event.x), area.toWy(event.y));
                    plot.requestPaint();
                    return;
                }
                mode = "pan";
            }
            onPositionChanged: event => {
                view.hover = { x: area.toWx(event.x), y: area.toWy(event.y) };
                if (!pressed) {
                    overDraggable = area.hitDraggable(event.x, event.y) !== null;
                    view.hoverPoi = area.hitPoi(event.x, event.y, 9);
                    return;
                }
                const dx = event.x - startX, dy = event.y - startY;
                if (Math.abs(dx) + Math.abs(dy) > 3) moved = true;
                if (!moved) return;
                if (mode === "drag") {
                    Metis.dragPoint(target.row, area.toWx(event.x), area.toWy(event.y), Metis.sx, Metis.sy, target.s, target.index);
                } else if (mode === "trace") {
                    const c = area.hitCurve(event.x, event.y, 1e9, target.row);
                    if (c) {
                        view.pin = { x: c.x, y: c.y, row: c.row, kind: "" };
                        plot.requestPaint();
                    }
                    Metis.probe(target.row, area.toWx(event.x), area.toWy(event.y));
                } else if (mode === "pan") {
                    Metis.cx = startCx - dx * Metis.sx;
                    Metis.cy = startCy + dy * Metis.sy;
                    Metis.changed();
                }
            }
            onReleased: event => {
                if (mode === "pan" && !moved && event.button === Qt.LeftButton) {
                    // click on empty paper: pin that location (it can become a point)
                    view.pin = { x: area.toWx(event.x), y: area.toWy(event.y), row: -1, kind: "location" };
                    plot.requestPaint();
                }
                if (mode === "drag") {
                    // a click (no drag) on a movable point still shows its coordinates
                    view.pin = moved ? null : { x: target.x, y: target.y, row: target.row, kind: "point",
                        hue: Metis.rows.get(target.row)?.kind === "table" ? Metis.tableOf(target.row).columns[target.s + 1]?.hue : undefined };
                    plot.requestPaint();
                }
                mode = "";
                target = null;
            }
            onExited: {
                view.hover = null;
                view.hoverPoi = null;
            }
            onWheel: event => {
                const steps = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : event.pixelDelta.y / 40;
                if (steps === 0) return;
                const f = Math.pow(0.85, steps);
                const wx = area.toWx(event.x), wy = area.toWy(event.y);
                if (event.modifiers & Qt.ShiftModifier && !Metis.settings.lockSquare) {
                    Metis.sx *= f; Metis.cx = wx + (Metis.cx - wx) * f; Metis.changed();
                } else if (event.modifiers & Qt.ControlModifier && !Metis.settings.lockSquare) {
                    Metis.sy *= f; Metis.cy = wy + (Metis.cy - wy) * f; Metis.changed();
                } else {
                    Metis.zoomAt(f, wx, wy);
                }
            }
        }

        // keyboard: arrows pan, +/- zoom, 0 reset
        focus: true
        Keys.onPressed: event => {
            let handled = true;
            switch (event.key) {
            case Qt.Key_Left: Metis.cx -= 60 * Metis.sx; break;
            case Qt.Key_Right: Metis.cx += 60 * Metis.sx; break;
            case Qt.Key_Up: Metis.cy += 60 * Metis.sy; break;
            case Qt.Key_Down: Metis.cy -= 60 * Metis.sy; break;
            case Qt.Key_Plus: case Qt.Key_Equal: Metis.zoomAt(0.8, Metis.cx, Metis.cy); break;
            case Qt.Key_Minus: Metis.zoomAt(1.25, Metis.cx, Metis.cy); break;
            case Qt.Key_0: Metis.resetView(); break;
            case Qt.Key_Escape: if (view.pin) view.clearPin(); else handled = false; break;
            default: handled = false;
            }
            if (handled) { Metis.changed(); event.accepted = true; }
        }

        // ---- pinned coordinate label with actions
        Rectangle {
            id: pinLabel
            visible: view.pin !== null
            readonly property real ax: view.pin ? area.toPx(view.pin.x) : 0
            readonly property real ay: view.pin ? area.toPy(view.pin.y) : 0
            x: Math.max(4, Math.min(area.width - width - 4, ax + 12))
            y: ay - height - 10 < 4 ? Math.min(area.height - height - 4, ay + 12) : ay - height - 10
            implicitWidth: pinRow.implicitWidth + 12
            implicitHeight: pinRow.implicitHeight + 8
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer3Base
            border.width: 1
            border.color: view.pin && view.pin.row >= 0 ? view.rowColor(view.pin.row, view.pin.hue) : Appearance.colors.colOutlineVariant
            RowLayout {
                id: pinRow
                anchors.centerIn: parent
                spacing: 2
                StyledText {
                    Layout.rightMargin: 4
                    text: {
                        const p = view.pin;
                        if (!p) return "";
                        const kinds = { root: Translation.tr("root"), max: Translation.tr("max"), min: Translation.tr("min"),
                            "y-intercept": Translation.tr("y-intercept"), intersection: Translation.tr("intersection") };
                        const k = kinds[p.kind] ?? "";
                        return `${k ? k + "  " : ""}(${view.fmt(p.x)}, ${view.fmt(p.y)})`;
                    }
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer3
                }
                PinButton {
                    symbol: "add_circle"
                    tip: Translation.tr("Add as a point expression")
                    onClicked: {
                        const p = view.pin;
                        const x = Metis.num(p.kind === "location" ? Metis.snap(p.x, Metis.sx) : p.x);
                        const y = Metis.num(p.kind === "location" ? Metis.snap(p.y, Metis.sy) : p.y);
                        const at = Metis.insertRow(Metis.rows.count, `(${x}, ${y})`);
                        Metis.selected = at;
                        view.clearPin();
                    }
                }
                PinButton {
                    symbol: "table_chart"
                    tip: Translation.tr("Add to a table")
                    onClicked: {
                        const p = view.pin;
                        Metis.addPointToTable(p.kind === "location" ? Metis.snap(p.x, Metis.sx) : p.x,
                                              p.kind === "location" ? Metis.snap(p.y, Metis.sy) : p.y);
                        view.clearPin();
                    }
                }
                PinButton {
                    symbol: "content_copy"
                    tip: Translation.tr("Copy coordinates")
                    onClicked: Quickshell.clipboardText = `(${Metis.num(view.pin.x)}, ${Metis.num(view.pin.y)})`
                }
                PinButton {
                    symbol: "close"
                    tip: Translation.tr("Close")
                    onClicked: view.clearPin()
                }
            }
        }

        // ---- hover label for points of interest (Desmos shows them on hover)
        Rectangle {
            visible: view.hoverPoi !== null && !(view.pin && view.hoverPoi && view.pin.x === view.hoverPoi.x && view.pin.y === view.hoverPoi.y)
            x: view.hoverPoi ? Math.max(4, Math.min(area.width - width - 4, area.toPx(view.hoverPoi.x) + 10)) : 0
            y: view.hoverPoi ? Math.max(4, area.toPy(view.hoverPoi.y) - height - 8) : 0
            implicitWidth: hoverText.implicitWidth + 12
            implicitHeight: hoverText.implicitHeight + 6
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer3Base
            opacity: 0.95
            StyledText {
                id: hoverText
                anchors.centerIn: parent
                text: view.hoverPoi ? `${view.hoverPoi.kind}  (${view.fmt(view.hoverPoi.x)}, ${view.fmt(view.hoverPoi.y)})` : ""
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer3
            }
        }
    }

    // ---- controls
    ColumnLayout {
        id: controls
        anchors { top: parent.top; right: parent.right; margins: 10 }
        spacing: 4
        ViewButton { symbol: "settings"; tip: Translation.tr("Graph settings"); toggled: view.showSettings; onClicked: view.showSettings = !view.showSettings }
        Item { implicitHeight: 4 }
        ViewButton { symbol: "add"; tip: Translation.tr("Zoom in"); onClicked: Metis.zoomAt(0.75, Metis.cx, Metis.cy) }
        ViewButton { symbol: "remove"; tip: Translation.tr("Zoom out"); onClicked: Metis.zoomAt(1 / 0.75, Metis.cx, Metis.cy) }
        ViewButton { symbol: "fit_screen"; tip: Translation.tr("Zoom to fit"); onClicked: Metis.zoomFit() }
        ViewButton { symbol: "home"; tip: Translation.tr("Default view"); onClicked: Metis.resetView() }
        Item { implicitHeight: 4 }
        ViewButton { symbol: "photo_camera"; tip: Translation.tr("Save as image (and copy)"); onClicked: view.exportImage() }
    }

    function exportImage() {
        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss");
        const dir = FileUtils.trimFileProtocol(Directories.pictures);
        const path = `${dir}/metis-graph-${stamp}.png`;
        const wasControls = controls.visible;
        controls.visible = false;
        area.grabToImage(result => {
            controls.visible = wasControls;
            if (!result.saveToFile(path)) {
                view.toast = Translation.tr("Couldn't save %1").arg(path);
            } else {
                Quickshell.execDetached(["bash", "-c", `wl-copy -t image/png < '${StringUtils.shellSingleQuoteEscape(path)}'`]);
                view.toast = Translation.tr("Saved %1 · copied to clipboard").arg(path.replace(FileUtils.trimFileProtocol(Directories.home), "~"));
            }
            toastTimer.restart();
        });
    }
    Timer {
        id: toastTimer
        interval: 3500
        onTriggered: view.toast = ""
    }

    // ---- status: cursor coordinates, render time, toast
    StyledText {
        anchors { left: parent.left; bottom: parent.bottom; margins: 10 }
        text: {
            if (view.toast) return view.toast;
            const parts = [];
            if (view.hover) parts.push(`x ${view.fmt(view.hover.x)}   y ${view.fmt(view.hover.y)}`);
            if (Metis.result?.ms !== undefined) parts.push(`${Metis.result.ms} ms`);
            return parts.join("   ·   ");
        }
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: view.toast ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
    }

    // ---- graph settings
    GraphSettings {
        visible: view.showSettings
        anchors { top: parent.top; right: controls.left; margins: 10 }
        onCloseRequested: view.showSettings = false
    }

    // ---- backend unavailable
    Rectangle {
        anchors.centerIn: parent
        visible: Metis.failed || Metis.failReason === "timeout"
        width: Math.min(parent.width - 40, 420)
        implicitHeight: failCol.implicitHeight + 28
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer3Base
        ColumnLayout {
            id: failCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6
            RowLayout {
                spacing: 8
                MaterialSymbol { text: "error"; iconSize: 22; color: Appearance.colors.colError }
                StyledText {
                    Layout.fillWidth: true
                    text: Metis.failed ? Translation.tr("Graph backend not found") : Translation.tr("That took too long — restarting the graph backend")
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer3
                    wrapMode: Text.Wrap
                }
            }
            StyledText {
                visible: Metis.failed
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: Translation.tr("Install metis (cargo install --path <metis repo>) or set apps.metis in the config to its path. Last error: %1").arg(Metis.stderrText || "—")
            }
            RippleButton {
                visible: Metis.failed
                implicitHeight: 32
                implicitWidth: 90
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colPrimary
                onClicked: { Metis.release(); Metis.acquire(); }
                contentItem: StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Translation.tr("Retry")
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }

    component ViewButton: RippleButton {
        id: vb
        property string symbol
        property string tip
        implicitWidth: 32
        implicitHeight: 32
        buttonRadius: Appearance.rounding.full
        colBackground: vb.toggled ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: vb.symbol
            iconSize: 18
            color: vb.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
        }
        StyledToolTip { text: vb.tip }
    }
    component PinButton: RippleButton {
        id: pb
        property string symbol
        property string tip
        implicitWidth: 24
        implicitHeight: 24
        buttonRadius: Appearance.rounding.full
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: pb.symbol
            iconSize: 16
            color: Appearance.colors.colOnLayer3
        }
        StyledToolTip { text: pb.tip }
    }
}
