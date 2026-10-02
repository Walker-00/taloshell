pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/**
 * taloshell theme engine front-end.
 * - Lists static theme presets (defaults/themes + ~/.config/taloshell/themes)
 * - Applies them through scripts/colors/themes.py (shell + GTK + Hyprland + terminals...)
 * - Switches back to Material You wallpaper colors
 * - Optional day/night schedule
 * IPC: qs -c taloshell ipc call theme <set|accent|random|next|prev|wallpaper|toggleMode|list|current>
 */
Singleton {
    id: root

    readonly property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/themes.py`)
    readonly property string userThemesDir: FileUtils.trimFileProtocol(`${Directories.shellConfig}/themes`)

    property list<var> themes: []
    property bool loading: false
    property bool applying: applyProc.running

    readonly property bool presetActive: Config.options.appearance.theme.source === "preset"
    readonly property string currentId: Config.options.appearance.theme.preset
    readonly property var currentTheme: themes.find(t => t.id === currentId) ?? null
    readonly property string currentAccent: Config.options.appearance.theme.accent
    readonly property list<string> favorites: Config.options.appearance.theme.favorites
    readonly property list<string> families: {
        const seen = [];
        for (const t of root.themes) if (!seen.includes(t.family)) seen.push(t.family);
        return seen;
    }

    function themeById(id) {
        return root.themes.find(t => t.id === id) ?? null;
    }

    function refresh() {
        root.loading = true;
        listProc.running = false;
        listProc.running = true;
    }

    // Apply a preset. accent: "" = the preset's default, an accent name, or "#rrggbb"
    function apply(id, accent = "") {
        if (!themeById(id) && root.themes.length > 0) {
            console.warn("[ThemeEngine] Unknown theme", id);
            return;
        }
        Config.options.appearance.theme.source = "preset";
        Config.options.appearance.theme.preset = id;
        Config.options.appearance.theme.accent = accent;
        applyProc.command = ["python3", root.scriptPath, "apply", id, "--accent", accent];
        applyProc.running = false;
        applyProc.running = true;
    }

    function setAccent(accent) {
        root.apply(root.currentId, accent);
    }

    // Back to Material You colors generated from the wallpaper
    function useWallpaperColors() {
        Config.options.appearance.theme.source = "wallpaper";
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"]);
    }

    // Works for both sources: presets jump to their light/dark counterpart
    function setDarkMode(dark) {
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", dark ? "dark" : "light", "--noswitch"]);
    }

    function toggleDarkMode() {
        root.setDarkMode(!Appearance.m3colors.darkmode);
    }

    function isFavorite(id) {
        return root.favorites.includes(id);
    }

    function toggleFavorite(id) {
        const favs = Config.options.appearance.theme.favorites;
        Config.options.appearance.theme.favorites = favs.includes(id) ? favs.filter(f => f !== id) : favs.concat([id]);
    }

    function cycle(step, favoritesOnly = false) {
        let pool = root.themes.map(t => t.id);
        if (favoritesOnly && root.favorites.length > 0) pool = pool.filter(id => root.favorites.includes(id));
        if (pool.length === 0) return;
        const i = pool.indexOf(root.currentId);
        root.apply(pool[(i + step + pool.length) % pool.length]);
    }

    function random(favoritesOnly = false) {
        let pool = root.themes.map(t => t.id).filter(id => id !== root.currentId);
        if (favoritesOnly && root.favorites.length > 0) pool = pool.filter(id => root.favorites.includes(id));
        if (pool.length === 0) return;
        root.apply(pool[Math.floor(Math.random() * pool.length)]);
    }

    function openUserThemesFolder() {
        Quickshell.execDetached(["bash", "-c", `mkdir -p '${root.userThemesDir}' && xdg-open '${root.userThemesDir}'`]);
    }



    Process {
        id: listProc
        command: ["python3", root.scriptPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = JSON.parse(text);
                } catch (e) {
                    console.warn("[ThemeEngine] Failed to parse theme list:", e);
                }
                root.loading = false;
            }
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                const applied = text.trim();
                if (applied.length > 0 && applied !== Config.options.appearance.theme.preset)
                    Config.options.appearance.theme.preset = applied;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) console.warn("[ThemeEngine]", text.trim())
        }
    }

    // Day/night schedule
    function minutesOf(hhmm) {
        const parts = (hhmm ?? "").split(":");
        return parseInt(parts[0] ?? 0) * 60 + parseInt(parts[1] ?? 0);
    }
    function shouldBeDarkNow() {
        const now = new Date();
        const m = now.getHours() * 60 + now.getMinutes();
        const lightFrom = minutesOf(Config.options.appearance.theme.lightFrom);
        const darkFrom = minutesOf(Config.options.appearance.theme.darkFrom);
        const isLight = lightFrom < darkFrom ? (m >= lightFrom && m < darkFrom) : (m >= lightFrom || m < darkFrom);
        return !isLight;
    }
    Timer {
        running: Config.ready && Config.options.appearance.theme.followSystemTime
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const dark = root.shouldBeDarkNow();
            if (dark !== Appearance.m3colors.darkmode) root.setDarkMode(dark);
        }
    }

    IpcHandler {
        target: "theme"

        function set(id: string): void { root.apply(id, ""); }
        function accent(accent: string): void { root.setAccent(accent); }
        function random(): void { root.random(false); }
        function randomFavorite(): void { root.random(true); }
        function next(): void { root.cycle(1); }
        function prev(): void { root.cycle(-1); }
        function wallpaper(): void { root.useWallpaperColors(); }
        function toggleMode(): void { root.toggleDarkMode(); }
        function reload(): void { root.refresh(); }
        function list(): string { return root.themes.map(t => t.id).join("\n"); }
        function current(): string { return root.presetActive ? `${root.currentId}${root.currentAccent ? ":" + root.currentAccent : ""}` : "wallpaper"; }
    }
}
