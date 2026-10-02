pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string firstRunFilePath: `${Directories.state}/user/first_run.txt`
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property string firstRunNotifSummary: "Welcome!"
    property string firstRunNotifBody: "Hit Super+/ for a list of keybinds"
    property string defaultWallpaperPath: FileUtils.trimFileProtocol(`${Directories.assetsPath}/images/default_wallpaper.png`)
    property string welcomeQmlPath: FileUtils.trimFileProtocol(Quickshell.shellPath("welcome.qml"))

    function load() {
        firstRunFileView.reload()
    }

    function enableNextTime() {
        Quickshell.execDetached(["rm", "-f", root.firstRunFilePath])
    }
    function disableNextTime() {
        Quickshell.execDetached(["bash", "-c", `echo '${root.firstRunFileContent}' > '${root.firstRunFilePath}'`])
    }

    function handleFirstRun() {
        // Coming from illogical-impulse / end4-pC? Keep the wallpaper you already have.
        Quickshell.execDetached(["bash", "-c", `
            ii="\${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
            wall=""
            [ -f "$ii" ] && wall=$(jq -r '.background.wallpaperPath // ""' "$ii")
            [ -n "$wall" ] && [ -f "$wall" ] || wall='${root.defaultWallpaperPath}'
            '${Directories.wallpaperSwitchScriptPath}' "$wall"
        `])
        Quickshell.execDetached(["bash", "-c", `qs -p '${root.welcomeQmlPath}'`])
    }

    FileView {
        id: firstRunFileView
        path: Qt.resolvedUrl(firstRunFilePath)
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                firstRunFileView.setText(root.firstRunFileContent)
                root.handleFirstRun()
            }
        }
    }
}
