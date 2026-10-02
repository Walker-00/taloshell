pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions

/**
 * Talos Launcher engine: a multi-mode command palette.
 * Modes are picked by prefix (configurable) or by the chips in the UI.
 * Every result is a plain object:
 *   { key, mode, title, subtitle, icon, iconType: "material"|"system"|"image"|"text", image,
 *     badge, run(), actions: [{ name, icon, run() }], preview: {...} }
 * IPC: qs -c taloshell ipc call launcher <toggle|open|close|mode <id>|query <text>>
 */
Singleton {
    id: root

    property string query: ""
    property string forcedMode: "" // set by chips / shortcuts; "" = detect from prefix
    property list<var> results: []
    property bool busy: calcProc.running || filesProc.running
    readonly property var cfg: Config.options.launcher

    readonly property string stateFile: FileUtils.trimFileProtocol(`${Directories.state}/user/launcher.json`)
    property var frecency: ({}) // key -> { count, last }

    // ---------------------------------------------------------------- modes
    readonly property var modeDefs: [
        { id: "all", name: Translation.tr("All"), icon: "apps", hint: Translation.tr("Search apps, commands, windows, settings…") },
        { id: "apps", name: Translation.tr("Apps"), icon: "grid_view", hint: Translation.tr("Search applications") },
        { id: "commands", name: Translation.tr("Commands"), icon: "terminal", hint: Translation.tr("Run a shell command or action") },
        { id: "calc", name: Translation.tr("Calculator"), icon: "calculate", hint: Translation.tr("Math, units, currency: 5 ft to cm") },
        { id: "run", name: Translation.tr("Run"), icon: "code", hint: Translation.tr("Run in a shell (Ctrl+Enter: in terminal)") },
        { id: "web", name: Translation.tr("Web"), icon: "travel_explore", hint: Translation.tr("Search the web · !g !yt !gh !w !aur …") },
        { id: "files", name: Translation.tr("Files"), icon: "folder_open", hint: Translation.tr("Find files in your home") },
        { id: "clipboard", name: Translation.tr("Clipboard"), icon: "content_paste", hint: Translation.tr("Clipboard history") },
        { id: "emoji", name: Translation.tr("Emoji"), icon: "mood", hint: Translation.tr("Search emoji") },
        { id: "windows", name: Translation.tr("Windows"), icon: "select_window", hint: Translation.tr("Switch to an open window") },
        { id: "themes", name: Translation.tr("Themes"), icon: "palette", hint: Translation.tr("Apply a color theme") },
        { id: "looks", name: Translation.tr("Looks"), icon: "auto_awesome_mosaic", hint: Translation.tr("Apply a look") },
        { id: "wallpapers", name: Translation.tr("Wallpapers"), icon: "wallpaper", hint: Translation.tr("Pick a wallpaper") },
        { id: "settings", name: Translation.tr("Settings"), icon: "settings", hint: Translation.tr("Jump to a setting") },
        { id: "tasks", name: Translation.tr("Tasks"), icon: "task_alt", hint: Translation.tr("Add or find a task: title !0-4 @today #tag") },
    ]
    readonly property var enabledModes: modeDefs.filter(m => m.id === "all" || cfg.modes.includes(m.id))
    function modeDef(id) { return root.modeDefs.find(m => m.id === id) ?? root.modeDefs[0]; }
    function prefixOf(id) { return cfg.prefixes[id] ?? ""; }

    // Longest matching prefix wins, e.g. "=" vs "=="
    readonly property var detected: {
        if (root.forcedMode.length > 0) return { mode: root.forcedMode, text: root.query };
        let best = null;
        for (const m of root.enabledModes) {
            const p = root.prefixOf(m.id);
            if (p.length > 0 && root.query.startsWith(p) && (!best || p.length > best.prefix.length))
                best = { mode: m.id, prefix: p };
        }
        return best ? { mode: best.mode, text: root.query.slice(best.prefix.length).replace(/^\s+/, "") } : { mode: "all", text: root.query };
    }
    readonly property string mode: detected.mode
    readonly property string text: detected.text

    function setMode(id) {
        // Chips replace any typed prefix
        root.forcedMode = id === "all" ? "" : id;
        root.query = root.text;
    }
    function cycleMode(step) {
        const ids = root.enabledModes.map(m => m.id);
        const i = ids.indexOf(root.mode);
        root.setMode(ids[(i + step + ids.length) % ids.length]);
    }
    function reset() {
        root.query = "";
        root.forcedMode = "";
    }

    onQueryChanged: refreshTimer.restart()
    onForcedModeChanged: refreshTimer.restart()
    Timer {
        id: refreshTimer
        interval: 25
        onTriggered: root.refresh()
    }

    // ---------------------------------------------------------------- helpers
    function fuzzy(items, q, key = "title", limit = 60) {
        if (q.trim().length === 0) return items.slice(0, limit);
        return Fuzzy.go(q, items, { key: key, limit: limit, threshold: 0.2 }).map(r => Object.assign({}, r.obj, { score: r.score }));
    }

    function frecencyBoost(key) {
        const f = root.frecency[key];
        if (!f || !root.cfg.frecency) return 0;
        const ageDays = (Date.now() - f.last) / 86400000;
        const recency = ageDays < 1 ? 1 : ageDays < 7 ? 0.6 : ageDays < 30 ? 0.3 : 0.1;
        return Math.min(0.45, Math.log2(f.count + 1) * 0.07 * recency + recency * 0.08);
    }

    function remember(key) {
        if (!key) return;
        const f = Object.assign({}, root.frecency);
        f[key] = { count: (f[key]?.count ?? 0) + 1, last: Date.now() };
        root.frecency = f;
        stateView.setText(JSON.stringify({ frecency: root.frecency }));
    }

    function forgetHistory() {
        root.frecency = {};
        stateView.setText(JSON.stringify({ frecency: {} }));
    }

    function close() {
        GlobalStates.launcherOpen = false;
    }

    // Run a result's main or alternate action
    function activate(item, alternate = false) {
        if (!item) return;
        root.remember(item.key);
        const action = alternate && item.actions && item.actions.length > 0 ? item.actions[0].run : item.run;
        const keepOpen = item.keepOpen === true;
        if (!keepOpen) root.close();
        if (action) Qt.callLater(action);
    }

    function copyText(text) {
        Quickshell.execDetached(["wl-copy", "--", text]);
    }
    function runInTerminal(cmd) {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} -e bash -c '${StringUtils.shellSingleQuoteEscape(cmd)}; echo; read -n1 -p "Press any key to close"'`]);
    }

    // ---------------------------------------------------------------- providers
    function appItems(q) {
        let entries;
        if (q.trim().length === 0) {
            const pinned = root.cfg.pinnedApps.map(id => DesktopEntries.byId(id)).filter(e => e);
            const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
            const recent = all.filter(e => root.frecency[`app:${e.id}`] && !pinned.includes(e))
                .sort((a, b) => root.frecencyBoost(`app:${b.id}`) - root.frecencyBoost(`app:${a.id}`));
            const rest = all.filter(e => !pinned.includes(e) && !recent.includes(e)).sort((a, b) => a.name.localeCompare(b.name));
            entries = [...pinned, ...recent, ...rest];
            return entries.slice(0, root.cfg.maxResults).map((e, i) => root.appItem(e, 1 - i * 0.001, pinned.includes(e)));
        }
        entries = AppSearch.fuzzyQuery(q);
        return entries.slice(0, 40).map((e, i) => root.appItem(e, 1 - i / 40 + root.frecencyBoost(`app:${e.id}`), root.cfg.pinnedApps.includes(e.id)));
    }

    function appItem(entry, score, pinned) {
        return {
            key: `app:${entry.id}`, mode: "apps", score: score,
            title: entry.name, subtitle: entry.comment || entry.genericName || entry.id,
            icon: AppSearch.guessIcon(entry.icon || entry.id), iconType: "system",
            badge: pinned ? "push_pin" : "",
            run: () => entry.execute(),
            actions: [
                ...entry.actions.map(a => ({ name: a.name, icon: "bolt", run: () => a.execute() })),
                { name: pinned ? Translation.tr("Unpin") : Translation.tr("Pin to top"), icon: "push_pin", run: () => root.togglePin(entry.id), keepOpen: true },
                { name: Translation.tr("Copy launch command"), icon: "content_copy", run: () => root.copyText(entry.command.join(" ")) },
            ],
            preview: { kind: "app", name: entry.name, description: entry.comment, generic: entry.genericName, categories: entry.categories, command: entry.command.join(" "), id: entry.id, icon: AppSearch.guessIcon(entry.icon || entry.id) },
        };
    }

    function togglePin(id) {
        const pins = Config.options.launcher.pinnedApps;
        Config.options.launcher.pinnedApps = pins.includes(id) ? pins.filter(p => p !== id) : [id, ...pins];
        refreshTimer.restart();
    }

    readonly property var commandList: {
        let list = [
            { title: Translation.tr("Lock screen"), icon: "lock", keywords: "lock", run: () => Session.lock() },
            { title: Translation.tr("Suspend"), icon: "bedtime", keywords: "sleep suspend", run: () => Session.suspend() },
            { title: Translation.tr("Log out"), icon: "logout", keywords: "logout exit quit", run: () => Session.logout() },
            { title: Translation.tr("Reboot"), icon: "restart_alt", keywords: "restart reboot", run: () => Session.reboot() },
            { title: Translation.tr("Shut down"), icon: "power_settings_new", keywords: "poweroff shutdown", run: () => Session.poweroff() },
            { title: Translation.tr("Session menu"), icon: "power", keywords: "power session", run: () => GlobalStates.sessionOpen = true },
            { title: Translation.tr("Toggle dark mode"), icon: "contrast", keywords: "dark light theme mode", run: () => ThemeEngine.toggleDarkMode() },
            { title: Translation.tr("Random theme"), icon: "shuffle", keywords: "theme random colors", run: () => ThemeEngine.random() },
            { title: Translation.tr("Next look"), icon: "auto_awesome_mosaic", keywords: "look style next", run: () => LookEngine.cycle(1) },
            { title: Translation.tr("Use wallpaper colors"), icon: "wallpaper", keywords: "material you wallpaper colors", run: () => ThemeEngine.useWallpaperColors() },
            { title: Translation.tr("Random wallpaper"), icon: "casino", keywords: "wallpaper random", run: () => Wallpapers.randomFromCurrentFolder() },
            { title: Translation.tr("Wallpaper selector"), icon: "image", keywords: "wallpaper picker", run: () => GlobalStates.wallpaperSelectorOpen = true },
            { title: Translation.tr("Dashboard"), icon: "dashboard", keywords: "dashboard overview", run: () => GlobalStates.dashboardOpen = true },
            { title: Translation.tr("Screen recorder"), icon: "screen_record", keywords: "record video capture", run: () => GlobalStates.recorderOpen = true },
            { title: Translation.tr("Screenshot region"), icon: "screenshot_region", keywords: "screenshot snip capture", run: () => GlobalStates.regionSelectorOpen = true },
            { title: Translation.tr("Color picker"), icon: "colorize", keywords: "pick color eyedropper hyprpicker", run: () => Quickshell.execDetached(["bash", "-c", "sleep 0.3; hyprpicker -a"]) },
            { title: Translation.tr("Settings"), icon: "settings", keywords: "settings preferences config", run: () => GlobalStates.settingsOpen = true },
            { title: Translation.tr("Keybinds cheatsheet"), icon: "keyboard", keywords: "keys shortcuts cheatsheet help", run: () => Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("shell.qml"), "ipc", "call", "cheatsheet", "toggle"]) },
            { title: Translation.tr("Toggle bar"), icon: "toast", keywords: "bar hide show", run: () => GlobalStates.barOpen = !GlobalStates.barOpen },
            { title: Translation.tr("Toggle Do Not Disturb"), icon: "notifications_paused", keywords: "dnd silent notifications", run: () => Notifications.silent = !Notifications.silent },
            { title: Translation.tr("Clear notifications"), icon: "clear_all", keywords: "notifications clear dismiss", run: () => Notifications.discardAllNotifications() },
            { title: Translation.tr("Reload shell"), icon: "refresh", keywords: "reload restart quickshell", run: () => Quickshell.reload(true) },
            { title: Translation.tr("Wipe clipboard history"), icon: "delete_sweep", keywords: "clipboard wipe clear", run: () => Cliphist.wipe() },
        ]
        if (Config.options.mail.enable) {
            list.push({ title: Translation.tr("Check mail"), icon: "refresh", keywords: "mail sync pigeon fetch", run: () => Pigeon.sync() })
            list.push({ title: Translation.tr("Mail"), icon: "mail", keywords: "mail inbox pigeon read", run: () => GlobalStates.sidebarRightOpen = true })
            list.push({ title: Translation.tr("Lock mail vault"), icon: "lock", keywords: "mail lock vault pigeon", run: () => Pigeon.lock() })
        }
        return list
    }

    function commandItems(q) {
        const builtins = root.commandList.map(c => ({
            key: `cmd:${c.title}`, mode: "commands", title: c.title, subtitle: Translation.tr("Action"), icon: c.icon, iconType: "material",
            search: `${c.title} ${c.keywords}`, run: c.run, preview: { kind: "text", title: c.title, body: c.keywords },
        }));
        const user = LauncherSearch.userActionScripts.map(a => ({
            key: `action:${a.action}`, mode: "commands", title: a.action, subtitle: Translation.tr("Your action script"), icon: "bolt", iconType: "material",
            search: a.action, run: () => a.execute(q.split(" ").slice(1).join(" ")),
        }));
        const firstWord = q.split(" ")[0];
        const list = root.fuzzy([...builtins, ...user], firstWord, "search", 30);
        return list.map(i => Object.assign(i, { score: (i.score ?? 1) * 0.95 + root.frecencyBoost(i.key) }));
    }

    function runItems(q) {
        if (q.trim().length === 0) return [];
        return [{
            key: "", mode: "run", title: q, subtitle: Translation.tr("Run in background · Ctrl+Enter: in terminal"), icon: "terminal", iconType: "material", score: 2,
            run: () => Quickshell.execDetached(["bash", "-c", q]),
            actions: [{ name: Translation.tr("Run in terminal"), icon: "terminal", run: () => root.runInTerminal(q) }],
            preview: { kind: "text", title: Translation.tr("Shell command"), body: q, mono: true },
        }];
    }

    function webItems(q, fallback = false) {
        if (q.trim().length === 0) return root.cfg.webEngines.map(e => ({
            key: `web:${e.key}`, mode: "web", title: e.name, subtitle: `!${e.key} ${Translation.tr("query")}`, icon: e.icon ?? "travel_explore", iconType: "material",
            run: () => root.query = `${root.prefixOf("web")}!${e.key} `, keepOpen: true,
        }));
        let engine = root.cfg.webEngines.find(e => e.key === root.cfg.defaultWebEngine) ?? root.cfg.webEngines[0];
        let text = q;
        // "!g query" or "query !g" picks an engine
        let bangKey = "", bangText = "";
        const leading = q.match(/^!(\S+)\s*(.*)$/);
        const trailing = q.match(/^(.*?)\s+!(\S+)$/);
        if (leading) { bangKey = leading[1]; bangText = leading[2]; }
        else if (trailing) { bangKey = trailing[2]; bangText = trailing[1]; }
        const bangEngine = root.cfg.webEngines.find(e => e.key === bangKey);
        if (bangEngine) { engine = bangEngine; text = bangText; }
        const url = engine.url.replace("%s", encodeURIComponent(text));
        const isUrl = /^(https?:\/\/)?[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(q.trim()) && !q.includes(" ");
        const items = [];
        if (isUrl && !fallback) items.push({
            key: "", mode: "web", title: q.trim(), subtitle: Translation.tr("Open website"), icon: "link", iconType: "material", score: 2,
            run: () => Qt.openUrlExternally(q.startsWith("http") ? q.trim() : `https://${q.trim()}`),
        });
        items.push({
            key: "", mode: "web", title: fallback ? Translation.tr("Search the web for “%1”").arg(text) : text, subtitle: Translation.tr("Search with %1").arg(engine.name),
            icon: engine.icon ?? "travel_explore", iconType: "material", score: fallback ? 0.01 : 1.5, run: () => Qt.openUrlExternally(url),
            actions: [{ name: Translation.tr("Copy link"), icon: "content_copy", run: () => root.copyText(url) }],
        });
        return items;
    }

    property string calcResult: ""
    property string calcExpression: ""
    function looksLikeMath(q) {
        return /^[\s\d(.-]/.test(q) && /[\d)]\s*([-+*/^%×÷]|\*\*)\s*[\d(.]/.test(q)
            || /\b(to|in)\s+[a-zA-Z°$€£¥]+\s*$/.test(q) && /\d/.test(q)
            || /^(sqrt|sin|cos|tan|log|ln|exp|pi|e\^|abs|round|floor|ceil)\b/.test(q);
    }
    function calcItems(q, forced) {
        if (q.trim().length === 0 || (!forced && !root.looksLikeMath(q))) return [];
        if (root.calcExpression !== q) {
            root.calcExpression = q;
            calcProc.running = false;
            calcProc.command = ["qalc", "-t", "--", q];
            calcProc.running = true;
        }
        if (root.calcResult.length === 0) return [];
        return [{
            key: "", mode: "calc", title: root.calcResult, subtitle: `${q}  ·  ${Translation.tr("Enter to copy")}`, icon: "calculate", iconType: "material", score: 3,
            run: () => root.copyText(root.calcResult),
            preview: { kind: "calc", expression: q, result: root.calcResult },
        }];
    }

    property list<string> fileResults: []
    property string filesQuery: ""
    function fileItems(q) {
        if (q.trim().length < 2) return [];
        if (root.filesQuery !== q) {
            root.filesQuery = q;
            filesProc.running = false;
            filesProc.command = ["bash", "-c", `cd ~ && fd --max-results 60 --max-depth 6 --hidden --exclude .git --exclude .cache --exclude node_modules --exclude .local/share/Trash -i -- '${StringUtils.shellSingleQuoteEscape(q)}' 2>/dev/null`];
            filesProc.running = true;
        }
        const home = FileUtils.trimFileProtocol(Directories.home).replace(/\/$/, "");
        return root.fileResults.map((rel, i) => {
            const path = `${home}/${rel}`;
            const isDir = rel.endsWith("/");
            const name = rel.replace(/\/$/, "").split("/").pop();
            const isImage = /\.(png|jpe?g|webp|gif|bmp|svg|avif)$/i.test(name);
            return {
                key: "", mode: "files", title: name, subtitle: `~/${rel}`, score: 1 - i / 100,
                icon: isDir ? "folder" : isImage ? "image" : "description", iconType: "material",
                run: () => Qt.openUrlExternally(`file://${path}`),
                actions: [
                    { name: Translation.tr("Open containing folder"), icon: "folder_open", run: () => Qt.openUrlExternally(`file://${path.substring(0, path.replace(/\/$/, "").lastIndexOf("/"))}`) },
                    { name: Translation.tr("Copy path"), icon: "content_copy", run: () => root.copyText(path) },
                ],
                preview: { kind: isImage ? "image" : "file", path: path, name: name, isDir: isDir },
            };
        });
    }

    function clipboardItems(q) {
        return Cliphist.fuzzyQuery(q).slice(0, 60).map((entry, i) => {
            const isImage = Cliphist.entryIsImage(entry);
            const text = entry.replace(/^\s*\S+\s+/, "");
            return {
                key: "", mode: "clipboard", title: isImage ? Translation.tr("Image") + " " + (text.match(/\d+x\d+/)?.[0] ?? "") : text.trim().split("\n")[0].slice(0, 200),
                subtitle: isImage ? Translation.tr("Image in clipboard history") : `${text.length} ${Translation.tr("chars")}`,
                icon: isImage ? "image" : "content_paste", iconType: "material", score: 1 - i / 100,
                run: () => Cliphist.copy(entry),
                actions: [
                    { name: Translation.tr("Paste"), icon: "content_paste_go", run: () => Cliphist.paste(entry) },
                    { name: Translation.tr("Delete from history"), icon: "delete", run: () => Cliphist.deleteEntry(entry), keepOpen: true },
                ],
                preview: { kind: isImage ? "clipImage" : "text", entry: entry, body: text, mono: true },
            };
        });
    }

    function emojiItems(q) {
        const matches = q.trim().length === 0 ? Emojis.list.slice(0, 160)
            : Fuzzy.go(q, Emojis.preparedEntries, { key: "name", threshold: 0.45, limit: 160 }).map(r => r.obj.entry);
        return matches.map((e, i) => {
            const glyph = e.split(" ")[0];
            const name = e.slice(glyph.length).trim();
            return {
                key: `emoji:${glyph}`, mode: "emoji", title: name, subtitle: Translation.tr("Enter to copy · Ctrl+Enter to type"), icon: glyph, iconType: "text", score: 1 - i / 200,
                run: () => root.copyText(glyph),
                actions: [{ name: Translation.tr("Type it"), icon: "keyboard", run: () => Quickshell.execDetached(["bash", "-c", `sleep 0.25; wtype '${glyph}'`]) }],
                preview: { kind: "emoji", glyph: glyph, name: name },
            };
        });
    }

    function windowItems(q) {
        const wins = HyprlandData.windowList.filter(w => w.mapped !== false).map(w => ({
            key: "", mode: "windows", title: w.title || w.class, subtitle: `${w.class} · ${Translation.tr("workspace %1").arg(w.workspace?.name ?? "?")}`,
            icon: AppSearch.guessIcon(w.class), iconType: "system", search: `${w.title} ${w.class}`,
            run: () => WM.focusWindow(w.address),
            actions: [{ name: Translation.tr("Close window"), icon: "close", run: () => WM.closeWindow(w.address) }],
            preview: { kind: "window", title: w.title, cls: w.class, workspace: w.workspace?.name, size: `${w.size?.[0]}×${w.size?.[1]}`, floating: w.floating },
        }));
        return root.fuzzy(wins, q, "search", 40);
    }

    function themeItems(q) {
        const items = ThemeEngine.themes.map(t => ({
            key: `theme:${t.id}`, mode: "themes", title: t.name, subtitle: `${t.family} · ${t.mode === "light" ? Translation.tr("Light") : Translation.tr("Dark")}`,
            icon: "palette", iconType: "swatch", swatches: t.swatches, search: `${t.name} ${t.family} ${t.mode}`,
            badge: ThemeEngine.presetActive && ThemeEngine.currentId === t.id ? "check" : "",
            run: () => ThemeEngine.apply(t.id),
            actions: [{ name: ThemeEngine.isFavorite(t.id) ? Translation.tr("Unfavorite") : Translation.tr("Favorite"), icon: "star", run: () => ThemeEngine.toggleFavorite(t.id), keepOpen: true }],
            preview: { kind: "theme", theme: t },
        }));
        return root.fuzzy(items, q, "search", 80);
    }

    function lookItems(q) {
        const items = LookEngine.looks.map(l => ({
            key: `look:${l.id}`, mode: "looks", title: l.name, subtitle: l.description ?? "", icon: l.icon ?? "palette", iconType: "material",
            search: `${l.name} ${l.description}`, badge: LookEngine.currentId === l.id ? "check" : "",
            run: () => LookEngine.apply(l.id),
            actions: l.suggestedTheme ? [{ name: Translation.tr("Apply with its theme"), icon: "palette", run: () => LookEngine.apply(l.id, true) }] : [],
            preview: { kind: "look", look: l },
        }));
        return root.fuzzy(items, q, "search", 40);
    }

    property list<string> wallpaperFiles: []
    function wallpaperItems(q) {
        const items = root.wallpaperFiles.map(p => ({
            key: `wall:${p}`, mode: "wallpapers", title: p.split("/").pop(), subtitle: p.replace(FileUtils.trimFileProtocol(Directories.home), "~"),
            icon: "wallpaper", iconType: "image", image: `file://${p}`, search: p.split("/").pop(),
            badge: Config.options.background.wallpaperPath === p ? "check" : "",
            run: () => Wallpapers.apply(p),
            actions: [
                { name: Translation.tr("Only use its colors"), icon: "palette", run: () => Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--image", p]) },
                { name: Translation.tr("Open"), icon: "open_in_new", run: () => Qt.openUrlExternally(`file://${p}`) },
            ],
            preview: { kind: "image", path: p, name: p.split("/").pop() },
        }));
        return root.fuzzy(items, q, "search", 120);
    }
    function reloadWallpapers() {
        wallsProc.running = false;
        wallsProc.running = true;
    }

    readonly property var settingsPages: [
        { page: "Quick", icon: "instant_mix" }, { page: "Themes", icon: "palette" }, { page: "Looks", icon: "auto_awesome_mosaic" },
        { page: "General", icon: "browse" }, { page: "Bar", icon: "toast" }, { page: "Desktop", icon: "texture" },
        { page: "Interface", icon: "bottom_app_bar" }, { page: "Dashboard", icon: "dashboard" }, { page: "Launcher", icon: "search" },
        { page: "Services", icon: "settings" }, { page: "Hyprland", icon: "select_window_2" }, { page: "About", icon: "info" },
    ]
    function settingsItems(q) {
        const items = [];
        for (const p of root.settingsPages) {
            items.push({ key: `settings:${p.page}`, mode: "settings", title: p.page, subtitle: Translation.tr("Settings page"), icon: p.icon, iconType: "material",
                search: `${p.page} ${LauncherSearch.settingsKeywordsCache[p.page] ?? ""}`, run: () => { GlobalStates.settingsOpen = true; GlobalStates.settingsPage = p.page; } });
            const sections = (LauncherSearch.settingsKeywordsCache[p.page] ?? "").split(/\s{2,}|\n/).map(s => s.trim()).filter(s => s.length > 0);
            for (const s of sections) {
                items.push({ key: `settings:${p.page}:${s}`, mode: "settings", title: s, subtitle: Translation.tr("%1 settings").arg(p.page), icon: p.icon, iconType: "material",
                    search: `${s} ${p.page}`, run: () => { GlobalStates.settingsOpen = true; GlobalStates.settingsPage = `${p.page}:${s}`; } });
            }
        }
        return root.fuzzy(items, q, "search", 30);
    }

    function taskItems(q) {
        const items = [];
        if (q.trim().length > 0) items.push({
            key: "", mode: "tasks", title: Translation.tr("Add task: %1").arg(q), subtitle: Translation.tr("!0-4 priority · @today/@tomorrow/@YYYY-MM-DD · #tag"),
            icon: "add_task", iconType: "material", score: 2, run: () => Kanban.quickAdd(q),
        });
        const tasks = Kanban.tasks.filter(t => t.column !== Kanban.doneColumn).map(t => ({
            key: "", mode: "tasks", title: t.title, subtitle: [Kanban.columns.find(c => c.id === t.column)?.name, Kanban.formatDue(t), ...(t.tags ?? []).map(x => `#${x}`)].filter(s => s).join(" · "),
            icon: Kanban.isOverdue(t) ? "assignment_late" : "radio_button_unchecked", iconType: "material", search: `${t.title} ${(t.tags ?? []).join(" ")}`,
            run: () => Kanban.moveTask(t.id, Kanban.doneColumn),
            actions: [{ name: Translation.tr("Open board"), icon: "view_kanban", run: () => { GlobalStates.dashboardTab = "tasks"; GlobalStates.dashboardOpen = true; } }],
        }));
        return items.concat(root.fuzzy(tasks, q, "search", 30));
    }

    // ---------------------------------------------------------------- aggregate
    function refresh() {
        const q = root.text;
        let out = [];
        switch (root.mode) {
            case "apps": out = root.appItems(q); break;
            case "commands": out = root.commandItems(q); break;
            case "calc": out = root.calcItems(q, true); break;
            case "run": out = root.runItems(q); break;
            case "web": out = root.webItems(q); break;
            case "files": out = root.fileItems(q); break;
            case "clipboard": out = root.clipboardItems(q); break;
            case "emoji": out = root.emojiItems(q); break;
            case "windows": out = root.windowItems(q); break;
            case "themes": out = root.themeItems(q); break;
            case "looks": out = root.lookItems(q); break;
            case "wallpapers": out = root.wallpaperItems(q); break;
            case "settings": out = root.settingsItems(q); break;
            case "tasks": out = root.taskItems(q); break;
            default: {
                if (q.trim().length === 0) {
                    out = root.appItems("");
                    break;
                }
                const groups = [
                    root.cfg.mathInAll ? root.calcItems(q, false) : [],
                    root.appItems(q),
                    root.cfg.modes.includes("windows") ? root.windowItems(q).map(i => Object.assign(i, { score: (i.score ?? 0) * 0.8 })) : [],
                    root.commandItems(q).map(i => Object.assign(i, { score: (i.score ?? 0) * 0.85 })),
                    root.settingsItems(q).map(i => Object.assign(i, { score: (i.score ?? 0) * 0.6 })),
                ];
                out = [].concat(...groups).sort((a, b) => (b.score ?? 0) - (a.score ?? 0));
                if (root.cfg.webFallback) out = out.concat(root.webItems(q, true));
            }
        }
        root.results = out.slice(0, root.cfg.maxResults);
    }

    // ---------------------------------------------------------------- processes
    Process {
        id: calcProc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim();
                const valid = r.length > 0 && !/^error|^warning/i.test(r) && r !== root.calcExpression;
                root.calcResult = valid ? r : "";
                root.refresh();
            }
        }
    }
    Process {
        id: filesProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.fileResults = text.split("\n").filter(l => l.length > 0);
                root.refresh();
            }
        }
    }
    Process {
        id: wallsProc
        command: ["bash", "-c", `for d in "$(xdg-user-dir PICTURES)/Wallpapers" '${FileUtils.trimFileProtocol(Config.options.wallpaperSelector.userPath ?? "")}' '${FileUtils.trimFileProtocol(Wallpapers.effectiveDirectory ?? "")}'; do [ -d "$d" ] && fd -t f -e jpg -e jpeg -e png -e webp -e gif -e avif -e mp4 -e webm --max-depth 3 . "$d" 2>/dev/null; done | sort -u | head -500`]
        stdout: StdioCollector {
            onStreamFinished: root.wallpaperFiles = text.split("\n").filter(l => l.length > 0)
        }
    }

    FileView {
        id: stateView
        path: root.stateFile
        onLoaded: {
            try { root.frecency = JSON.parse(stateView.text()).frecency ?? {}; } catch (e) { root.frecency = {}; }
        }
        onLoadFailed: error => { if (error == FileViewError.FileNotFound) stateView.setText(JSON.stringify({ frecency: {} })); }
    }

    Connections {
        target: GlobalStates
        function onLauncherOpenChanged() {
            if (GlobalStates.launcherOpen) {
                if (root.mode === "clipboard" || root.mode === "all") Cliphist.refresh();
                if (root.wallpaperFiles.length === 0) root.reloadWallpapers();
                root.refresh();
            }
        }
    }

    function open(mode = "", query = "") {
        root.forcedMode = mode === "all" ? "" : mode;
        root.query = query;
        GlobalStates.launcherOpen = true;
    }
    function toggle(mode = "") {
        if (GlobalStates.launcherOpen && (mode === "" || root.mode === mode)) {
            GlobalStates.launcherOpen = false;
        } else {
            root.open(mode);
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(""); }
        function open(): void { root.open(""); }
        function close(): void { GlobalStates.launcherOpen = false; }
        function mode(id: string): void { root.toggle(id); }
        function query(text: string): void { root.open("", text); }
    }
}
