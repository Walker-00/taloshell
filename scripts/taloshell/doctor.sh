#!/usr/bin/env bash
# taloshell doctor: checks what taloshell needs and tells you what's missing.
# Usage: bash ~/.config/quickshell/taloshell/scripts/taloshell/doctor.sh

ok=0; warn=0; bad=0
green=$'\e[32m'; yellow=$'\e[33m'; red=$'\e[31m'; dim=$'\e[2m'; reset=$'\e[0m'

check_cmd() { # name, required(1/0), what for
    if command -v "$1" >/dev/null 2>&1; then
        printf "  ${green}✓${reset} %-22s ${dim}%s${reset}\n" "$1" "$3"; ok=$((ok+1))
    elif [[ "$2" == 1 ]]; then
        printf "  ${red}✗${reset} %-22s %s ${red}(required)${reset}\n" "$1" "$3"; bad=$((bad+1))
    else
        printf "  ${yellow}!${reset} %-22s %s ${dim}(optional)${reset}\n" "$1" "$3"; warn=$((warn+1))
    fi
}
check_font() { # family, required, what for
    # Match with or without spaces ("JetBrains Mono" == "JetBrainsMono")
    if fc-list : family | tr -d ' ' | grep -qiF "${1// /}"; then
        printf "  ${green}✓${reset} %-22s ${dim}%s${reset}\n" "$1" "$3"; ok=$((ok+1))
    elif [[ "$2" == 1 ]]; then
        printf "  ${red}✗${reset} %-22s %s ${red}(required)${reset}\n" "$1" "$3"; bad=$((bad+1))
    else
        printf "  ${yellow}!${reset} %-22s %s ${dim}(optional)${reset}\n" "$1" "$3"; warn=$((warn+1))
    fi
}

echo "Core"
check_cmd qs 1 "Quickshell"
check_cmd jq 1 "config & theme scripts"
check_cmd matugen 1 "color generation (Material You + theme presets)"
check_cmd python3 1 "theme engine, helpers"
check_cmd hyprctl 0 "Hyprland integration"

echo "Python venv (Material You terminal colors, image tools)"
venv="${TALOSHELL_VIRTUAL_ENV:-${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}}"
venv="$(eval echo "$venv")"
if [[ -x "$venv/bin/python" ]] && "$venv/bin/python" -c "import materialyoucolor" 2>/dev/null; then
    printf "  ${green}✓${reset} %-22s ${dim}%s${reset}\n" "venv" "$venv"; ok=$((ok+1))
else
    printf "  ${yellow}!${reset} %-22s %s\n" "venv" "not found at $venv — install illogical-impulse's venv or set TALOSHELL_VIRTUAL_ENV"; warn=$((warn+1))
fi

echo "Launcher"
check_cmd qalc 0 "calculator mode"
check_cmd fd 0 "file search mode"
check_cmd metis 0 "dashboard Graph tab (cargo install --path <metis repo>)"
check_cmd cliphist 0 "clipboard mode"
check_cmd wl-copy 1 "copying results"
check_cmd wtype 0 "typing emoji"

echo "Recorder & capture"
check_cmd wf-recorder 0 "recording (default engine)"
check_cmd gpu-screen-recorder 0 "recording (GPU engine)"
check_cmd wl-screenrec 0 "recording (wl-screenrec engine)"
check_cmd slurp 0 "region/window selection"
check_cmd grim 0 "screenshots"
check_cmd ffmpeg 0 "GIF export, video wallpapers"
check_cmd pactl 0 "recording audio"

echo "Extras"
check_cmd cava 0 "audio visualizer"
check_cmd hyprpicker 0 "color picker"
check_cmd curl 0 "weather, online wallpapers"
check_cmd notify-send 0 "notifications from scripts"

echo "Fonts"
check_font "Material Symbols Rounded" 1 "icons"
check_font "Google Sans Flex" 0 "default UI font"
check_font "JetBrains Mono" 0 "monospace / terminal looks"

echo
printf "%s ok, %s optional missing, %s required missing\n" "$ok" "$warn" "$bad"
[[ $bad -eq 0 ]]
