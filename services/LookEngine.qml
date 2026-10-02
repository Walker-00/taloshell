pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services

/**
 * "Looks": one-click style bundles (shape, motion, borders, bar style, fonts,
 * transparency, window decoration). Built-ins live in defaults/looks, user looks
 * in ~/.config/taloshell/looks (same format; same id overrides a built-in).
 * IPC: qs -c taloshell ipc call look <set|next|prev|list|current|save>
 */
Singleton {
    id: root

    readonly property string builtinDir: FileUtils.trimFileProtocol(Quickshell.shellPath("defaults/looks"))
    readonly property string userDir: FileUtils.trimFileProtocol(`${Directories.shellConfig}/looks`)
    property list<var> looks: []
    readonly property string currentId: Config.options.appearance.style.look

    // Keys a saved look captures from the live config
    readonly property var capturedKeys: [
        "panelFamily",
        "appearance.style", "appearance.transparency", "appearance.fonts",
        "bar.cornerStyle", "bar.borderless", "bar.showBackground", "bar.showFrame", "bar.frameThickness",
        "bar.followFrameColor", "bar.frameColor", "bar.vertical", "bar.floatStyleShadow", "bar.verbose", "bar.autoHide.enable",
        "hyprland.decoration.rounding", "hyprland.decoration.blur.enabled", "hyprland.decoration.shadow.enabled",
        "hyprland.general.gapsIn", "hyprland.general.gapsOut",
    ]

    function lookById(id) {
        return root.looks.find(l => l.id === id) ?? null;
    }

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    function flatten(obj, prefix, out) {
        for (const key in obj) {
            const value = obj[key];
            const path = prefix ? `${prefix}.${key}` : key;
            if (value !== null && typeof value === "object" && !Array.isArray(value))
                root.flatten(value, path, out);
            else
                out.push([path, value]);
        }
        return out;
    }

    function getNested(path) {
        let obj = Config.options;
        for (const k of path.split(".")) {
            if (obj === undefined || obj === null) return undefined;
            obj = obj[k];
        }
        return obj;
    }

    function setNested(path, value) {
        const keys = path.split(".");
        let obj = Config.options;
        for (let i = 0; i < keys.length - 1; i++) {
            if (obj[keys[i]] === undefined || obj[keys[i]] === null) return; // unknown section: ignore
            obj = obj[keys[i]];
        }
        const last = keys[keys.length - 1];
        if (!(last in obj)) return; // don't invent keys the shell doesn't know
        obj[last] = value;
    }

    // withTheme: also apply the look's suggested color theme (if any)
    function apply(id, withTheme = false) {
        const look = root.lookById(id);
        if (!look) {
            console.warn("[LookEngine] Unknown look", id);
            return;
        }
        const entries = root.flatten(look.config ?? {}, "", []);
        for (const [path, value] of entries)
            root.setNested(path, value);
        Config.options.appearance.style.look = id;

        // Push window decoration straight to Hyprland
        const h = look.config?.hyprland;
        if (h && WM.compositor !== "niri") {
            const hyprEntries = {};
            if (h.decoration?.rounding !== undefined) hyprEntries["decoration:rounding"] = h.decoration.rounding;
            if (h.decoration?.blur?.enabled !== undefined) hyprEntries["decoration:blur:enabled"] = h.decoration.blur.enabled ? 1 : 0;
            if (h.decoration?.shadow?.enabled !== undefined) hyprEntries["decoration:shadow:enabled"] = h.decoration.shadow.enabled ? 1 : 0;
            if (h.general?.gapsIn !== undefined) hyprEntries["general:gaps_in"] = h.general.gapsIn;
            if (h.general?.gapsOut !== undefined) hyprEntries["general:gaps_out"] = h.general.gapsOut;
            if (Object.keys(hyprEntries).length > 0) HyprlandConfig.setMany(hyprEntries);
        }
        if (withTheme && look.suggestedTheme)
            ThemeEngine.apply(look.suggestedTheme);
    }

    function cycle(step) {
        if (root.looks.length === 0) return;
        const i = root.looks.findIndex(l => l.id === root.currentId);
        root.apply(root.looks[(i + step + root.looks.length) % root.looks.length].id);
    }

    // Save the current style as a user look
    function saveCurrent(name, description = "") {
        const id = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "custom";
        const config = {};
        for (const path of root.capturedKeys) {
            const value = root.getNested(path);
            if (value === undefined) continue;
            const keys = path.split(".");
            let obj = config;
            for (let i = 0; i < keys.length - 1; i++) obj = obj[keys[i]] = obj[keys[i]] ?? {};
            // JsonObject -> plain object
            obj[keys[keys.length - 1]] = (value !== null && typeof value === "object") ? JSON.parse(JSON.stringify(value)) : value;
        }
        if (config.appearance?.style) config.appearance.style.look = id;
        const look = { name: name, description: description, icon: "palette", order: 100, config: config };
        if (ThemeEngine.presetActive) look.suggestedTheme = ThemeEngine.currentId;
        saveProc.command = ["bash", "-c", `mkdir -p '${root.userDir}' && cat > '${root.userDir}/${id}.json'`];
        saveProc.pendingText = JSON.stringify(look, null, 2);
        saveProc.running = true;
        Config.options.appearance.style.look = id;
    }

    function remove(id) {
        const look = root.lookById(id);
        if (!look || look.builtin) return;
        Quickshell.execDetached(["rm", "-f", `${root.userDir}/${id}.json`]);
        Qt.callLater(root.refresh);
    }

    function openUserFolder() {
        Quickshell.execDetached(["bash", "-c", `mkdir -p '${root.userDir}' && xdg-open '${root.userDir}'`]);
    }



    Process {
        id: listProc
        command: ["bash", "-c", `
            shopt -s nullglob
            for f in '${root.builtinDir}'/*.json; do jq -c --arg id "$(basename "$f" .json)" '. + {id: $id, builtin: true}' "$f"; done
            for f in '${root.userDir}'/*.json; do jq -c --arg id "$(basename "$f" .json)" '. + {id: $id, builtin: false}' "$f"; done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const byId = {};
                for (const line of text.split("\n")) {
                    if (line.trim().length === 0) continue;
                    try {
                        const look = JSON.parse(line);
                        byId[look.id] = look;
                    } catch (e) {
                        console.warn("[LookEngine] Bad look file:", e);
                    }
                }
                root.looks = Object.values(byId).sort((a, b) => (a.order ?? 100) - (b.order ?? 100) || a.name.localeCompare(b.name));
            }
        }
    }

    Process {
        id: saveProc
        property string pendingText: ""
        stdinEnabled: true
        onStarted: {
            write(pendingText);
            stdinEnabled = false;
        }
        onExited: {
            stdinEnabled = true;
            root.refresh();
        }
    }

    IpcHandler {
        target: "look"

        function set(id: string): void { root.apply(id, false); }
        function setWithTheme(id: string): void { root.apply(id, true); }
        function next(): void { root.cycle(1); }
        function prev(): void { root.cycle(-1); }
        function save(name: string): void { root.saveCurrent(name); }
        function reload(): void { root.refresh(); }
        function list(): string { return root.looks.map(l => l.id).join("\n"); }
        function current(): string { return root.currentId; }
    }
}
