#!/usr/bin/env python3
"""
taloshell theme engine.

Themes are small palette files (defaults/themes/*.json, plus user themes in
~/.config/taloshell/themes/*.json which override built-ins with the same id).
This script expands a palette into the full Material 3 role set the shell uses,
then feeds it through matugen's template engine so GTK, Hyprland, fuzzel,
terminals, KDE etc. all follow the chosen theme.

Usage:
  themes.py list                               JSON list of themes (for the UI)
  themes.py roles <id> [--accent A] [--mode M] Print the generated M3 roles
  themes.py apply <id> [--accent A] [--mode M] Apply the theme everywhere
     --accent  name from the theme's "accents" or a #hex color
     --mode    dark | light  (switches to the theme's counterpart if needed)
"""
import argparse
import colorsys
import json
import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SHELL_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
XDG_CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
XDG_STATE_HOME = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
BUILTIN_DIR = os.path.join(SHELL_DIR, "defaults", "themes")
USER_DIR = os.path.join(XDG_CONFIG_HOME, "taloshell", "themes")
STATE_DIR = os.path.join(XDG_STATE_HOME, "taloshell")
GEN_DIR = os.path.join(STATE_DIR, "user", "generated")
SHELL_CONFIG_FILE = os.path.join(XDG_CONFIG_HOME, "taloshell", "config.json")


# ---------------------------------------------------------------- color math
def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "#" + "".join(f"{max(0, min(255, round(c * 255))):02x}" for c in rgb)


def mix(a, b, t):
    """t=0 -> a, t=1 -> b"""
    ra, rb = hex_to_rgb(a), hex_to_rgb(b)
    return rgb_to_hex(tuple(x + (y - x) * t for x, y in zip(ra, rb)))


def luminance(h):
    def ch(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(c) for c in hex_to_rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def best_on(color, candidates, minimum=4.5):
    """First themed candidate with readable contrast, else the most contrasting one."""
    for c in candidates:
        if contrast(color, c) >= minimum:
            return c
    return max(candidates, key=lambda c: contrast(color, c))


def adjust_lightness(h, amount):
    r, g, b = hex_to_rgb(h)
    hh, l, s = colorsys.rgb_to_hls(r, g, b)
    l = max(0.0, min(1.0, l + amount))
    return rgb_to_hex(colorsys.hls_to_rgb(hh, l, s))


def is_hex(v):
    return isinstance(v, str) and v.startswith("#") and len(v) in (4, 7)


# ---------------------------------------------------------------- loading
def load_all():
    themes = {}
    for d, builtin in ((BUILTIN_DIR, True), (USER_DIR, False)):
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if not f.endswith(".json"):
                continue
            try:
                with open(os.path.join(d, f)) as fh:
                    t = json.load(fh)
                t["id"] = f[:-5]
                t["builtin"] = builtin
                themes[t["id"]] = t
            except Exception as e:  # a broken user theme must never break the list
                print(f"[themes] skipping {f}: {e}", file=sys.stderr)
    return themes


def resolve(theme, ref, fallback):
    if ref is None:
        return fallback
    if is_hex(ref):
        return ref
    accents = theme.get("accents", {})
    pal = theme.get("palette", {})
    return accents.get(ref) or pal.get(ref) or fallback


def complete_palette(theme):
    """Fill in whatever a (possibly user-written, minimal) palette leaves out."""
    p = dict(theme.get("palette", {}))
    dark = theme.get("mode", "dark") == "dark"
    bg, fg = p.get("bg", "#1e1e1e" if dark else "#fafafa"), p.get("fg", "#e0e0e0" if dark else "#202020")
    p["bg"], p["fg"] = bg, fg
    p.setdefault("bgAlt", mix(bg, "#000000", 0.18 if dark else 0.04))
    p.setdefault("bgDeep", mix(bg, "#000000", 0.32 if dark else 0.08))
    p.setdefault("surface0", mix(bg, fg, 0.10))
    p.setdefault("surface1", mix(bg, fg, 0.17))
    p.setdefault("surface2", mix(bg, fg, 0.26))
    p.setdefault("overlay", mix(bg, fg, 0.45))
    p.setdefault("fgDim", mix(fg, bg, 0.22))
    defaults = {"red": "#e06c75", "orange": "#d19a66", "yellow": "#e5c07b", "green": "#98c379",
                "cyan": "#56b6c2", "blue": "#61afef", "magenta": "#c678dd"}
    for k, v in defaults.items():
        p.setdefault(k, v)
    p.setdefault("pink", p["magenta"])
    return p


# ---------------------------------------------------------------- M3 mapping
def build_roles(theme, accent=None):
    p = complete_palette(theme)
    dark = theme.get("mode", "dark") == "dark"
    roles_cfg = theme.get("roles", {})
    primary = resolve(theme, accent, None) or resolve(theme, roles_cfg.get("primary"), p["blue"])
    secondary = resolve(theme, roles_cfg.get("secondary"), p["cyan"])
    tertiary = resolve(theme, roles_cfg.get("tertiary"), p["magenta"])
    error = resolve(theme, roles_cfg.get("error"), p["red"])
    success = resolve(theme, roles_cfg.get("success"), p["green"])

    bg, fg = p["bg"], p["fg"]
    s0, s1, s2 = p["surface0"], p["surface1"], p["surface2"]
    white, black = "#ffffff", "#000000"
    on_candidates = [p["bgDeep"], p["bg"], fg, white, black]

    def container(c):
        # Tinted container: strongly towards the background, keeps the hue
        return mix(c, bg, 0.72 if dark else 0.78)

    def on_container(c):
        return mix(c, white if dark else black, 0.55 if dark else 0.45)

    def fixed(c):
        return mix(c, white, 0.62)

    def fixed_dim(c):
        return mix(c, white, 0.35)

    def on_fixed(c):
        return mix(c, black, 0.8)

    def on_fixed_variant(c):
        return mix(c, black, 0.55)

    r = {}
    r["source_color"] = primary
    r["background"] = bg
    r["on_background"] = fg
    r["surface"] = bg
    r["surface_dim"] = p["bgAlt"] if dark else mix(bg, s1, 0.5)
    r["surface_bright"] = mix(s1, s2, 0.5) if dark else mix(bg, white, 0.6)
    r["surface_container_lowest"] = p["bgDeep"] if dark else mix(bg, white, 0.7)
    r["surface_container_low"] = mix(bg, s0, 0.40)
    r["surface_container"] = mix(bg, s0, 0.75)
    r["surface_container_high"] = mix(s0, s1, 0.40)
    r["surface_container_highest"] = mix(s0, s1, 0.85)
    r["on_surface"] = fg
    r["surface_variant"] = s1
    r["on_surface_variant"] = p["fgDim"]
    r["inverse_surface"] = fg
    r["inverse_on_surface"] = bg
    r["outline"] = p["overlay"]
    r["outline_variant"] = s2 if dark else s1
    r["shadow"] = black
    r["scrim"] = black
    r["surface_tint"] = primary

    for name, c in (("primary", primary), ("secondary", secondary), ("tertiary", tertiary)):
        r[name] = c
        r[f"on_{name}"] = best_on(c, on_candidates)
        r[f"{name}_container"] = container(c)
        r[f"on_{name}_container"] = on_container(c)
        r[f"{name}_fixed"] = fixed(c)
        r[f"{name}_fixed_dim"] = fixed_dim(c)
        r[f"on_{name}_fixed"] = on_fixed(c)
        r[f"on_{name}_fixed_variant"] = on_fixed_variant(c)
    r["inverse_primary"] = mix(primary, black if dark else white, 0.45)

    r["error"] = error
    r["on_error"] = best_on(error, on_candidates)
    r["error_container"] = mix(error, bg, 0.7 if dark else 0.8)
    r["on_error_container"] = on_container(error)

    extra = {
        "success": success,
        "on_success": best_on(success, on_candidates),
        "success_container": container(success),
        "on_success_container": on_container(success),
    }

    term = theme.get("terminal")
    if not term or len(term) != 16:
        base = [s1 if dark else fg, p["red"], p["green"], p["yellow"], p["blue"], p["magenta"], p["cyan"], p["fgDim"] if dark else s2]
        bright = [s2 if dark else p["fgDim"]] + [adjust_lightness(c, 0.06 if dark else -0.06) for c in base[1:7]] + [fg if dark else bg]
        term = base + bright
    return r, extra, term, dark


# ---------------------------------------------------------------- output
def matugen_import_json(roles, wallpaper):
    colors = {k: {"default": {"color": v}, "dark": {"color": v}, "light": {"color": v}} for k, v in roles.items()}
    return {"colors": colors, "image": wallpaper or ""}


def scss(roles, extra, term, dark):
    def camel(k):
        parts = k.split("_")
        return parts[0] + "".join(x.capitalize() for x in parts[1:])
    lines = [f"$darkmode: {'True' if dark else 'False'};", "$transparent: False;"]
    for k, v in roles.items():
        if k == "source_color":
            continue
        lines.append(f"${camel(k)}: {v.upper()};")
    for k, v in extra.items():
        lines.append(f"${camel(k)}: {v.upper()};")
    for i, c in enumerate(term):
        lines.append(f"$term{i}: {c.upper()};")
    return "\n".join(lines) + "\n"


def read_config():
    try:
        with open(SHELL_CONFIG_FILE) as f:
            return json.load(f)
    except Exception:
        return {}


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, check=False, **kw)
    except FileNotFoundError as e:
        print(f"[themes] {e}", file=sys.stderr)


def apply(theme, accent, roles, extra, term, dark):
    os.makedirs(GEN_DIR, exist_ok=True)
    cfg = read_config()
    wallpaper = cfg.get("background", {}).get("wallpaperPath", "")
    wt = cfg.get("appearance", {}).get("wallpaperTheming", {})

    # 1. System dark/light preference (GTK apps, portals)
    if wt.get("enableAppsAndShell", True) is not False:
        run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark" if dark else "prefer-light"])
        run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "adw-gtk3-dark" if dark else "adw-gtk3"])

    # 2. Render every matugen template (colors.json for the shell, GTK, Hyprland, fuzzel...)
    import_path = os.path.join(GEN_DIR, "theme-import.json")
    with open(import_path, "w") as f:
        json.dump(matugen_import_json(roles, wallpaper), f)
    cfg_path = subprocess.run(["bash", os.path.join(SCRIPT_DIR, "matugen-config.sh")], capture_output=True, text=True).stdout.strip()
    run(["matugen", "json", import_path, "-c", cfg_path, "--mode", "dark" if dark else "light", "-q"])

    # 3. Shell extras: success + terminal colors go straight into colors.json
    colors_path = os.path.join(GEN_DIR, "colors.json")
    try:
        with open(colors_path) as f:
            colors = json.load(f)
    except Exception:
        colors = dict(roles)
    colors.update(extra)
    for i, c in enumerate(term):
        colors[f"term{i}"] = c
    tmp = colors_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(colors, f, indent=2)
    os.replace(tmp, colors_path)

    # 4. Terminal + Qt/Kvantum through the same path wallpaper theming uses
    with open(os.path.join(GEN_DIR, "material_colors.scss"), "w") as f:
        f.write(scss(roles, extra, term, dark))
    with open(os.path.join(GEN_DIR, "color.txt"), "w") as f:
        f.write(roles["primary"] + "\n")
    if os.environ.get("TALOSHELL_TEST") != "1":
        run(["bash", os.path.join(SCRIPT_DIR, "applycolor.sh")])
        run(["bash", os.path.join(SCRIPT_DIR, "code", "material-code-set-color.sh")])
        kde = os.path.join(SHELL_DIR, "defaults", "matugen", "templates", "kde", "kde-material-you-colors-wrapper.sh")
        if wt.get("enableQtApps", True) is not False and os.path.exists(kde):
            subprocess.Popen(["bash", kde, "--scheme-variant", "scheme-tonal-spot"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # 5. Remember what's applied (the shell reads this for the UI state)
    with open(os.path.join(GEN_DIR, "theme.json"), "w") as f:
        json.dump({"id": theme["id"], "name": theme.get("name"), "accent": accent or "", "mode": "dark" if dark else "light"}, f)


def swatches(theme):
    roles, extra, term, dark = build_roles(theme)
    p = complete_palette(theme)
    return {
        "bg": roles["background"], "surface": roles["surface_container"], "fg": roles["on_surface"],
        "primary": roles["primary"], "secondary": roles["secondary"], "tertiary": roles["tertiary"],
        "strip": [p["red"], p["orange"], p["yellow"], p["green"], p["cyan"], p["blue"], p["magenta"]],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["list", "roles", "apply"])
    ap.add_argument("id", nargs="?")
    ap.add_argument("--accent", default=None)
    ap.add_argument("--mode", choices=["dark", "light", "auto", ""], default="")
    a = ap.parse_args()

    themes = load_all()
    if a.cmd == "list":
        out = []
        for tid, t in themes.items():
            out.append({
                "id": tid, "name": t.get("name", tid), "family": t.get("family", t.get("name", tid)),
                "variant": t.get("variant", ""), "mode": t.get("mode", "dark"), "author": t.get("author", ""),
                "url": t.get("url", ""), "builtin": t["builtin"], "counterpart": t.get("counterpart", ""),
                "accents": t.get("accents", {}), "defaultAccent": t.get("roles", {}).get("primary", ""),
                "swatches": swatches(t),
            })
        out.sort(key=lambda x: (x["family"].lower(), x["mode"] != "dark", x["name"].lower()))
        print(json.dumps(out))
        return

    if not a.id or a.id not in themes:
        print(f"Unknown theme: {a.id}", file=sys.stderr)
        sys.exit(1)
    theme = themes[a.id]
    if a.mode in ("dark", "light") and theme.get("mode", "dark") != a.mode:
        cp = theme.get("counterpart")
        if cp and cp in themes:
            theme = themes[cp]
    accent = a.accent if a.accent not in (None, "", "default") else None
    if accent and not is_hex(accent) and accent not in theme.get("accents", {}):
        accent = None  # accent name doesn't exist in the counterpart; use its default
    roles, extra, term, dark = build_roles(theme, accent)
    if a.cmd == "roles":
        print(json.dumps({"roles": roles, "extra": extra, "terminal": term, "dark": dark}, indent=2))
        return
    apply(theme, accent, roles, extra, term, dark)
    print(theme["id"])


if __name__ == "__main__":
    main()
