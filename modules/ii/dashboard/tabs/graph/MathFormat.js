.pragma library

// Typeset-looking rich text for math input (Desmos style): italic variables,
// upright functions, real superscripts/subscripts, proper symbols.
// Input is the plain text the user typed; output is Qt rich-text HTML.

const FUNCS = new Set([
    "sin", "cos", "tan", "sec", "csc", "cot", "asin", "acos", "atan", "asec", "acsc", "acot",
    "arcsin", "arccos", "arctan", "arcsec", "arccsc", "arccot", "sinh", "cosh", "tanh", "sech", "csch", "coth",
    "asinh", "acosh", "atanh", "arsinh", "arcosh", "artanh", "ln", "log", "exp", "sqrt", "cbrt", "nthroot", "abs",
    "floor", "ceil", "round", "trunc", "frac", "sign", "sgn", "mod", "gcd", "lcm", "min", "max", "mean", "median",
    "total", "length", "count", "sum", "prod", "int", "integral", "diff", "nCr", "nPr", "choose", "stdev", "stdevp",
    "var", "varp", "mad", "sort", "unique", "reverse", "join", "erf", "erfc", "gamma", "lgamma", "factorial",
    "distance", "midpoint", "quantile", "cov", "corr", "argmin", "argmax", "hypot", "atan2", "deg", "rad", "isprime",
    "for", "log10", "log2",
]);
const SYMBOLS = {
    pi: "π", tau: "τ", theta: "θ", alpha: "α", beta: "β", gamma: "γ", delta: "δ", epsilon: "ε", lambda: "λ",
    mu: "μ", sigma: "σ", omega: "ω", phi: "φ", rho: "ρ", psi: "ψ", inf: "∞", infinity: "∞",
};
const UPRIGHT = new Set(["π", "τ", "∞", "e"]);

function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function isLetter(c) {
    return /[A-Za-zͰ-Ͽ]/.test(c);
}

// index just past the bracket group starting at i (s[i] is an opener)
function matchGroup(s, i) {
    const open = s[i], close = { "(": ")", "{": "}", "[": "]" }[open];
    let depth = 0;
    for (let k = i; k < s.length; k++) {
        if (s[k] === open) depth++;
        else if (s[k] === close && --depth === 0) return k + 1;
    }
    return s.length;
}

function word(w) {
    if (SYMBOLS[w] !== undefined) {
        const sym = SYMBOLS[w];
        return UPRIGHT.has(sym) ? sym : `<i>${sym}</i>`;
    }
    if (FUNCS.has(w)) return w === "sqrt" ? "√" : w === "cbrt" ? "∛" : w;
    if (w.length === 1 && UPRIGHT.has(w)) return w;
    // unknown runs are implicit products of variables: xy → 𝑥𝑦
    return `<i>${esc(w)}</i>`;
}

// the next "atom" for ^ or _ without braces: -?(number | word | group)
function atom(s, i) {
    let k = i;
    if (s[k] === "-") k++;
    if (k < s.length && (s[k] === "(" || s[k] === "{")) return matchGroup(s, k);
    if (k < s.length && /[0-9.]/.test(s[k])) {
        while (k < s.length && /[0-9.]/.test(s[k])) k++;
        return k;
    }
    while (k < s.length && isLetter(s[k])) k++;
    return Math.max(k, i + 1);
}

function inner(g) {
    // strip one layer of grouping brackets used only for scripts
    if ((g[0] === "(" && g[g.length - 1] === ")") || (g[0] === "{" && g[g.length - 1] === "}")) return g.slice(1, -1);
    return g;
}

function format(s, depth) {
    depth = depth ?? 0;
    if (depth > 6) return esc(s);
    let out = "";
    let i = 0;
    const binary = (sym) => { out += `&thinsp;${sym}&thinsp;`; };
    while (i < s.length) {
        const c = s[i];
        if (c === " " || c === "\t") {
            // keep a visible gap between juxtaposed words/numbers: "a sin t"
            const before = s[i - 1] ?? "", after = s.slice(i).replace(/^\s+/, "")[0] ?? "";
            if (/[A-Za-z0-9\u0370-\u03ff)\]]/.test(before) && /[A-Za-z0-9\u0370-\u03ff(]/.test(after) && !out.endsWith("&thinsp;")) out += "&thinsp;";
            i++;
            continue;
        }
        // d/dx
        if (c === "d" && s.startsWith("d/d", i) && isLetter(s[i + 3] ?? "")) {
            let k = i + 3;
            while (k < s.length && isLetter(s[k])) k++;
            out += `d/d${word(s.slice(i + 3, k))} `;
            i = k;
            continue;
        }
        if (isLetter(c)) {
            let k = i;
            while (k < s.length && isLetter(s[k])) k++;
            const w = s.slice(i, k);
            out += word(w);
            i = k;
            // x1 → x₁ (Desmos auto-subscript) unless it's a function name
            if (k < s.length && /[0-9]/.test(s[k]) && !FUNCS.has(w) && SYMBOLS[w] === undefined) {
                let d = k;
                while (d < s.length && /[0-9]/.test(s[d])) d++;
                out += `<sub>${s.slice(k, d)}</sub>`;
                i = d;
            }
            continue;
        }
        if (/[0-9.]/.test(c)) {
            let k = i;
            while (k < s.length && /[0-9.]/.test(s[k])) k++;
            if ((s[k] === "e" || s[k] === "E") && /[0-9-]/.test(s[k + 1] ?? "") && /[0-9]/.test(s[k + 1] === "-" ? s[k + 2] ?? "" : s[k + 1])) {
                let e = k + 1;
                if (s[e] === "-") e++;
                while (e < s.length && /[0-9]/.test(s[e])) e++;
                out += `${s.slice(i, k)}×10<sup>${s.slice(k + 1, e).replace("-", "−")}</sup>`;
                i = e;
                continue;
            }
            out += s.slice(i, k);
            i = k;
            continue;
        }
        if (c === "^" || c === "_") {
            const end = atom(s, i + 1);
            const body = format(inner(s.slice(i + 1, end)), depth + 1);
            out += c === "^" ? `<sup>${body}</sup>` : `<sub>${body}</sub>`;
            i = end;
            continue;
        }
        const two = s.slice(i, i + 2);
        if (two === "<=") { binary("≤"); i += 2; continue; }
        if (two === ">=") { binary("≥"); i += 2; continue; }
        if (two === "**") { out += "<sup>"; const end = atom(s, i + 2); out += format(inner(s.slice(i + 2, end)), depth + 1) + "</sup>"; i = end; continue; }
        switch (c) {
        case "*": out += "·"; break;
        case "-": {
            // unary minus hugs its operand; binary gets spacing
            const prev = out.replace(/<[^>]*>/g, "").replace(/&thinsp;/g, "").replace(/\s+$/, "").slice(-1);
            if (prev === "" || "(=<>≤≥+−·,[{~:".includes(prev)) out += "−";
            else binary("−");
            break;
        }
        case "+": binary("+"); break;
        case "=": binary("="); break;
        case "<": binary("&lt;"); break;
        case ">": binary("&gt;"); break;
        case "~": binary("∼"); break;
        case ",": out += ",&thinsp;"; break;
        case "&": out += "&amp;"; break;
        default: out += esc(c);
        }
        i++;
    }
    return out;
}
