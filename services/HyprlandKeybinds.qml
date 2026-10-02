pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * A service that provides access to Hyprland keybinds.
 * Uses the `get_keybinds.py` script to parse comments in config files in a certain format and convert to JSON.
 */
Singleton {
    id: root
    property string keybindParserPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/hyprland/get_keybinds.py`)
    property string defaultKeybindConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/keybinds.lua`)
    property string userKeybindConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/custom/keybinds.lua`)
    property var defaultKeybinds: {"children": []}
    property var userKeybinds: {"children": []}
    property var keybinds: ({
        children: [
            ...(defaultKeybinds.children ?? []),
            ...(userKeybinds.children ?? []),
        ]
    })

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                getDefaultKeybinds.running = true
                getUserKeybinds.running = true
            }
        }
    }

    Process {
        id: getDefaultKeybinds
        running: true
        command: [root.keybindParserPath, "--path", root.defaultKeybindConfigPath]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.defaultKeybinds = JSON.parse(data)
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e)
                }
            }
        }
    }

    Process {
        id: getUserKeybinds
        running: true
        command: [root.keybindParserPath, "--path", root.userKeybindConfigPath]
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.userKeybinds = JSON.parse(data)
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e)
                }
            }
        }
    }

    // Live binds from `hyprctl binds -j`, grouped by the "Category: description" convention.
    // Used by the illogical-impulse cheatsheet (Super+/).
    property var bindList: []
    property var keybindCategories: []

    Process {
        id: getRuntimeBinds
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const binds = JSON.parse(text);
                    const groups = [];
                    for (const b of binds) {
                        const d = b.description ?? "";
                        const group = d.substring(0, d.indexOf(":"));
                        if (group.length > 0 && !groups.includes(group)) groups.push(group);
                    }
                    root.bindList = binds;
                    root.keybindCategories = groups;
                } catch (e) {
                    console.error("[HyprlandKeybinds] Error parsing hyprctl binds:", e);
                }
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name == "configreloaded") getRuntimeBinds.running = true;
        }
    }
}
