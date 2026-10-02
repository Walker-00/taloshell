#!/usr/bin/env bash
# taloshell config helpers
#   config-tools.sh import-ii   Merge ~/.config/illogical-impulse/config.json (used by ii & end4-pC)
#                               into taloshell's config and copy to-dos/notes/presets. Makes a backup first.
#   config-tools.sh backup      Tar config + state into ~/taloshell-backup-DATE.tar.gz
#   config-tools.sh reset       Move the config aside so defaults are regenerated
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
TALOS_CONFIG_DIR="$XDG_CONFIG_HOME/taloshell"
TALOS_CONFIG="$TALOS_CONFIG_DIR/config.json"
TALOS_STATE="$XDG_STATE_HOME/taloshell/user"
II_CONFIG_DIR="$XDG_CONFIG_HOME/illogical-impulse"
II_CONFIG="$II_CONFIG_DIR/config.json"
II_STATE="$XDG_STATE_HOME/quickshell/user"
stamp="$(date +%Y%m%d-%H%M%S)"

notify() { notify-send -a "taloshell" "$@" 2>/dev/null || echo "$@"; }

case "${1:-}" in
    import-ii)
        [[ -f "$II_CONFIG" ]] || { notify "Nothing to import" "No $II_CONFIG found"; exit 1; }
        mkdir -p "$TALOS_CONFIG_DIR" "$TALOS_STATE"
        [[ -f "$TALOS_CONFIG" ]] && cp "$TALOS_CONFIG" "$TALOS_CONFIG.bak-$stamp"
        [[ -f "$TALOS_CONFIG" ]] || echo '{}' > "$TALOS_CONFIG"
        # Deep merge: ii values win, taloshell-only keys survive. panelFamily is kept as is.
        jq -s '(.[0] * (.[1] | del(.panelFamily)))' "$TALOS_CONFIG" "$II_CONFIG" > "$TALOS_CONFIG.tmp"
        mv "$TALOS_CONFIG.tmp" "$TALOS_CONFIG"
        for f in todo.json notes.txt desktopnotes.txt; do
            [[ -f "$II_STATE/$f" && ! -f "$TALOS_STATE/$f" ]] && cp "$II_STATE/$f" "$TALOS_STATE/$f"
        done
        if [[ -d "$II_CONFIG_DIR/presets" ]]; then
            mkdir -p "$TALOS_CONFIG_DIR/presets"
            cp -n "$II_CONFIG_DIR/presets/"*.json "$TALOS_CONFIG_DIR/presets/" 2>/dev/null || true
        fi
        if [[ -d "$II_CONFIG_DIR/actions" ]]; then
            mkdir -p "$TALOS_CONFIG_DIR/actions"
            cp -rn "$II_CONFIG_DIR/actions/." "$TALOS_CONFIG_DIR/actions/" 2>/dev/null || true
        fi
        notify "Settings imported" "Your illogical-impulse settings, to-dos, notes and presets are now in taloshell. Backup: config.json.bak-$stamp"
        ;;
    backup)
        out="$HOME/taloshell-backup-$stamp.tar.gz"
        tar czf "$out" -C "$XDG_CONFIG_HOME" taloshell -C "$XDG_STATE_HOME" taloshell 2>/dev/null || tar czf "$out" -C "$XDG_CONFIG_HOME" taloshell
        notify "Backup saved" "$out"
        echo "$out"
        ;;
    reset)
        [[ -f "$TALOS_CONFIG" ]] && mv "$TALOS_CONFIG" "$TALOS_CONFIG.bak-$stamp"
        notify "Settings reset" "Defaults restored. Old config: config.json.bak-$stamp"
        ;;
    *)
        echo "usage: $0 import-ii|backup|reset" >&2
        exit 1
        ;;
esac
