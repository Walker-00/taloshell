<div align="center">

# ✦ taloshell

**A Quickshell desktop shell for Hyprland that merges the best of illogical-impulse, end4-pC, caelestia, Brain_Shell and octashell, then adds a lot of its own.**

Themes · Looks · Command palette · Dashboard · Kanban · Screen recorder · Two whole panel families

</div>

---

## What's inside

Everything from **illogical-impulse** and **end4-pC** is still here: bar with a drag-and-drop layout editor, dynamic island, sidebars with AI chat, translator and quick toggles, the overview, lock screen, OSD, notifications, dock, wallpaper selector with online wallpapers, desktop widgets, lyrics, equalizer, presets, polkit agent, on-screen keyboard, the region/OCR/Lens tool and the settings app.

On top of that, taloshell adds:

| | |
|---|---|
| 🎨 **Theme engine** | 51 hand-mapped themes from 26 families: Catppuccin (all 4), Rosé Pine (all 3), Tokyo Night (4), Kanagawa (3), Gruvbox, Nord, Dracula/Alucard, Everforest, One, Solarized, Monokai Pro, Ayu, Nightfox, Oxocarbon, GitHub, Flexoki, Synthwave '84, Poimandres, Night Owl, Palenight, Everblush, Horizon, Cyberdream, Vesper, Moonfly, Graphite/Paper/AMOLED. Pick any accent (e.g. Catppuccin *mauve*, *sapphire*, *peach*…). Themes recolor **the shell, GTK 3/4, Qt/KDE, Hyprland borders, hyprlock, fuzzel and every open terminal**. Light/dark toggles jump to the theme's counterpart (Mocha ⇄ Latte). You can also schedule day/night switching. Material You from the wallpaper is still one click away. |
| 🧩 **Looks** | 14 one-click style bundles: Material Expressive, Islands, Frosted Glass, Minimal Flat, Brutalist, Retro Terminal, Cozy, Framed (a bezel, like caelestia/octashell), Classic Panel, Vertical Rail, Compact, Neon, Zen (auto-hide) and Windows 11. Fine-tune roundness, pill shapes, density, text size, animation length, springy vs calm motion, outline width/color/opacity and shadows. **Save your own looks.** |
| ⚡ **Talos launcher** | A command palette with 15 modes: apps (frecency-ranked, pin to top), commands, calculator (qalc: units, currency…), run, web (`!g !yt !gh !w !aur`…), files (fd), clipboard (with image previews), emoji, windows, themes, looks, wallpapers (image grid), settings (jumps to a section) and tasks. It has a preview pane, per-result actions, list/grid/compact layouts and full keyboard control. |
| 📊 **Dashboard** | caelestia-style tabbed panel. **Overview** (clock/profile, weather + hourly, calendar, media, gauges, up-next tasks), **Media** (cover, visualizer, seek, shuffle/loop, lyrics), **Performance** (6 gauges, CPU history, per-core bars, network graph, killable top processes), **Tasks** (full Kanban), **Weather** (hourly + 7-day forecast from Open-Meteo) and **Graph**, a Desmos-style graphing calculator: curves, implicit equations, inequalities, polar/parametric (editable t/θ ranges), sliders with animation (speed, loop/bounce/once), derivatives, lists, **tables** with computed columns and one-click regressions (linear, quadratic, exponential, logistic, sinusoidal…), **draggable points** (`(a, b)` moves its sliders), drag along a curve to trace it, click any point to pin its coordinates and add it as an expression or table row, per-row styles (colour, dashed/dotted, thickness, opacity, point style, labels), graph settings (grid, polar grid, axes, bounds, labels), undo/redo, a math keypad, examples, saved graphs and PNG export. Graph needs the `metis` backend in `PATH` (`cargo install --path <metis repo>`, or set `apps.metis`); enable it in Settings → Dashboard. |
| 🗂️ **Kanban** | Brain_Shell-inspired board. Custom columns, drag-and-drop, priorities, due dates, tags, notes and due reminders. Quick-add syntax works everywhere: `Write report !3 @tomorrow #work`. |
| 🎬 **Screen recorder** | Screen, region or window capture. Audio off, mic, system or **both mixed**. MP4/MKV/WebM/**GIF**, 24–120 fps, countdown. Engines: wf-recorder, gpu-screen-recorder or wl-screenrec. A floating pill shows the timer with stop and discard. Notifications offer open, show in folder and copy path. |
| 🪟 **Waffle family** | ii's Windows 11 recreation (taskbar, start menu, action center, task view…) is restored. Switch with the *Windows 11* look or `panelFamily`. |
| 🧱 **New widgets** | Bar: Dashboard button, Theme switcher (scroll to cycle), Tasks counter, Recorder. Desktop: Kanban card and speedometer gauges (with network rates). |
| 📬 **Mail** | A real email client in the sidebar, backed by **pigeon** running as a headless daemon over a unix socket. Folder chips with unread counts, message list with hover actions (flag, read/unread, archive, trash), a reader with quote folding and attachments, inline reply, an unread badge on the bar, new-mail notifications, and the whole setup — vault passphrase, provider autodetection, live IMAP/SMTP login test, accounts and passwords — inside the settings app. Mail is encrypted at rest by pigeon; the shell never stores any of it. |

## Install

```bash
# 1. Put it in your quickshell config dir
cp -r taloshell ~/.config/quickshell/taloshell

# 2. Check dependencies
bash ~/.config/quickshell/taloshell/scripts/taloshell/doctor.sh

# 3. Try it (stop your current shell first)
killall qs; qs -c taloshell & disown
```

**Make it the default.** In `~/.config/hypr/hyprland/variables.lua`, set:

```lua
hl.env("qsConfig", "taloshell")
```

**Coming from illogical-impulse or end4-pC?** Settings → About → *Import from illogical-impulse* (or the welcome app) merges your settings, to-dos, notes, presets and action scripts. A backup is kept, and your ii/end4-pC setup is never touched. taloshell keeps its own files:

| What | Where |
|---|---|
| Config | `~/.config/taloshell/config.json` |
| Your themes / looks | `~/.config/taloshell/themes/*.json`, `~/.config/taloshell/looks/*.json` |
| Extra matugen templates | `~/.config/taloshell/matugen/*.toml` |
| State (colors, kanban, launcher history…) | `~/.local/state/taloshell/` |

It still uses illogical-impulse's Python venv for Material You terminal colors (`$ILLOGICAL_IMPULSE_VIRTUAL_ENV`, or set `TALOSHELL_VIRTUAL_ENV`).

## Keybinds

Your existing ii keybinds keep working. With `launcher.engine = "talos"` (the default), Super, Super+V and Super+. open the Talos launcher; Super+Tab still opens the overview.

Optional extra binds (dashboard, launcher modes, recorder) are in [`defaults/hypr/taloshell-keybinds.lua`](defaults/hypr/taloshell-keybinds.lua). Load them from `~/.config/hypr/custom/keybinds.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/quickshell/taloshell/defaults/hypr/taloshell-keybinds.lua")
```

| Keys | Action |
|---|---|
| Super+D / Super+Shift+D / Super+Ctrl+D | Dashboard / tasks / performance |
| Super+R | Launcher: commands |
| Super+Shift+T / W / F | Launcher: themes / windows / files |
| Super+Shift+R / Super+Ctrl+R | Start/stop recording / recorder options |

## Launcher cheatsheet

| Prefix | Mode | | Prefix | Mode |
|---|---|---|---|---|
| *(none)* | Everything | | `;` | Clipboard |
| `'` | Apps | | `:` | Emoji |
| `>` | Commands | | `%` | Windows |
| `=` | Calculator | | `#` | Themes |
| `$` | Run shell command | | `&` | Looks |
| `?` | Web (`!g`, `!yt`, `!gh`, `!w`, `!aur`, `!aw`, `!r`, `!maps`, `!tr`, `!d`) | | `@` | Wallpapers |
| `/` | Files | | `!` | Settings |
| `+` | Tasks | | | |

**Enter** opens the result. **Ctrl+Enter** runs the first alternate action. **Alt+1…9** runs a specific action. **Ctrl+1…9** is a quick pick. **Tab** cycles modes. **Ctrl+P** toggles the preview. **Esc** clears the query, then closes. All prefixes and modes can be changed in Settings → Launcher.

## IPC

```bash
qs -c taloshell ipc call theme set catppuccin-mocha     # also: accent, random, next, prev, wallpaper, toggleMode, list, current
qs -c taloshell ipc call look set glass                 # also: setWithTheme, next, prev, save "My look", list, current
qs -c taloshell ipc call launcher toggle                # also: open, close, mode themes, query "=2^10"
qs -c taloshell ipc call dashboard tab performance      # also: toggle, open, close
qs -c taloshell ipc call kanban add "Ship it !4 @today #work"
qs -c taloshell ipc call graph add "y = sin(x)"           # also: open, clear
qs -c taloshell ipc call recorder toggle                # also: start, stop, discard, panel
qs -c taloshell ipc call settings page "Launcher:Modes"
```

## Mail

Mail comes from **pigeon**, a pure-Rust terminal mail client that can also run
headless. The shell talks to `pigeon daemon` over a unix socket in
`$XDG_RUNTIME_DIR`; pigeon owns the accounts, the IMAP/SMTP connections and an
encrypted local store, and the shell is only a front end. Nothing about your mail
is written on the Quickshell side.

```bash
# 1. Build and install pigeon somewhere on PATH
cargo install --path /path/to/pigeon     # or set mail.command to the binary

# 2. Turn mail on
Settings -> Mail -> Enable mail
```

The shell starts the daemon itself (*Start the daemon with the shell*), or leave
that off and run `pigeon daemon` from your session autostart.

Everything else happens in **Settings → Mail**:

* **Vault** — create the passphrase that encrypts the local store, unlock it, or
  lock it again. Until it is unlocked the sidebar shows a passphrase prompt
  instead of your mail.
* **Accounts** — *Add account* takes an address, looks the provider up (built-in
  table, then Mozilla's ISPDB), signs in to IMAP **and** SMTP for real and shows
  what each said, then saves. The password goes to the system keyring, or to
  pigeon's encrypted vault when no keyring answers. Per account you can change
  the password, sync now, disable it or remove it.
* **Syncing** — push (IMAP IDLE), poll interval, offline body download,
  attachment limit and how long bodies are cached.

Reading happens in the right sidebar's **Mail** tab: account picker, folder
chips, filter box, and hover actions on each row. Clicking a message opens the
reader in place, with quoted text folded, attachments as chips that open with
`xdg-open`, and a reply box. HTML mail is off by default; when switched on, the
daemon strips scripts, event handlers and every remote URL before the shell sees
it, so opening a message cannot tell the sender you did.

The launcher gains *Mail*, *Check mail* and *Lock mail vault*.


## Make your own theme

Only `name`, `mode` and a `palette` with `bg` and `fg` are required. Everything else is derived. Drop it in `~/.config/taloshell/themes/mytheme.json`, then press *Reload themes*:

```json
{
  "name": "My Theme",
  "mode": "dark",
  "counterpart": "my-theme-light",
  "palette": { "bg": "#1b1d2b", "fg": "#d8dae8", "red": "#ff7a93", "green": "#a6e3a1", "blue": "#7aa2f7", "magenta": "#bb9af7" },
  "accents": { "blue": "#7aa2f7", "pink": "#ff79c6" },
  "roles": { "primary": "blue", "secondary": "magenta", "tertiary": "pink" },
  "terminal": ["16 hex colors, optional"]
}
```

Optional palette keys are `bgAlt`, `bgDeep`, `surface0-2`, `overlay`, `fgDim`, `orange`, `yellow`, `cyan` and `pink`. See `defaults/themes/` for 51 examples.

## Credits

- [illogical-impulse](https://github.com/end-4/dots-hyprland) by **end-4**: the foundation (GPL-3.0)
- [end4-pC](https://github.com/pctrade/end4-pC) by **pctrade**: the fork taloshell grew from (GPL-3.0)
- [caelestia](https://github.com/caelestia-dots/shell) by **soramane**: dashboard design ideas
- [Brain_Shell](https://github.com/Brainitech/Brain_Shell) by **Brainitech**: Kanban, recorder and gauge ideas
- [octashell](https://github.com/octagonemusic/octashell) by **octagonemusic**: bezel frame idea
- Theme palettes by their respective authors. Built with [Quickshell](https://quickshell.outfoxxed.me).

Licensed under GPL-3.0, like its upstream.
