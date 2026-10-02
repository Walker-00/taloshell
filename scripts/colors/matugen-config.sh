#!/usr/bin/env bash
# Generates taloshell's own matugen config so theming never touches another
# shell's setup. Prints the path of the generated config.toml.
# Targets can be toggled in config.json under .appearance.theming.targets
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATES="$SHELL_DIR/defaults/matugen/templates"
STATE_DIR="$XDG_STATE_HOME/taloshell"
GEN_DIR="$STATE_DIR/user/generated"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/taloshell/config.json"
OUT="$STATE_DIR/matugen/config.toml"

mkdir -p "$(dirname "$OUT")" "$GEN_DIR/wallpaper"

target_enabled() {
    local name="$1"
    [[ -f "$SHELL_CONFIG_FILE" ]] || return 0
    local v
    v=$(jq -r --arg n "$name" '.appearance.theming.targets[$n] // true' "$SHELL_CONFIG_FILE" 2>/dev/null || echo true)
    [[ "$v" != "false" ]]
}

emit() {
    local name="$1" input="$2" output="$3"
    [[ -f "$TEMPLATES/$input" ]] || return 0
    mkdir -p "$(dirname "$output")"
    printf '[templates.%s]\ninput_path = %s\noutput_path = %s\n\n' "$name" "'$TEMPLATES/$input'" "'$output'"
}

{
    printf '[config]\nversion_check = false\n\n'
    # Always needed by the shell itself
    emit m3colors colors.json "$GEN_DIR/colors.json"
    emit kde_colors kde/color.txt "$GEN_DIR/color.txt"
    emit wallpaper wallpaper.txt "$GEN_DIR/wallpaper/path.txt"
    # Optional app targets
    target_enabled hyprland && [[ -d "$XDG_CONFIG_HOME/hypr/hyprland" ]] && emit hyprland hyprland/colors.lua "$XDG_CONFIG_HOME/hypr/hyprland/colors.lua"
    target_enabled hyprlock && [[ -d "$XDG_CONFIG_HOME/hypr" ]] && emit hyprlock hyprland/hyprlock-colors.conf "$XDG_CONFIG_HOME/hypr/hyprlock/colors.conf"
    target_enabled fuzzel && emit fuzzel fuzzel/fuzzel_theme.ini "$XDG_CONFIG_HOME/fuzzel/fuzzel_theme.ini"
    target_enabled gtk && emit gtk3 gtk-3.0/gtk.css "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
    target_enabled gtk && emit gtk4 gtk-4.0/gtk.css "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
    # User-provided extra templates: ~/.config/taloshell/matugen/*.toml are appended verbatim
    for extra in "$XDG_CONFIG_HOME"/taloshell/matugen/*.toml; do
        [[ -f "$extra" ]] && { cat "$extra"; echo; }
    done
} > "$OUT"

echo "$OUT"
