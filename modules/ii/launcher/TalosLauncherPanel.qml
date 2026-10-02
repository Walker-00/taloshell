pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * Window for the Talos Launcher (see services/TalosLauncher.qml).
 */
Scope {
    id: root
    property bool closing: false

    Connections {
        target: GlobalStates
        function onLauncherOpenChanged() {
            if (!GlobalStates.launcherOpen) {
                root.closing = true;
                closeTimer.restart();
            }
        }
    }
    Timer {
        id: closeTimer
        interval: Appearance.animation.elementMoveExit.duration + 30
        onTriggered: {
            root.closing = false;
            TalosLauncher.reset();
        }
    }

    Loader {
        active: GlobalStates.launcherOpen || root.closing
        sourceComponent: PanelWindow {
            id: window
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            Rectangle {
                anchors.fill: parent
                color: Config.options.launcher.dimBackground ? Appearance.colors.colScrim : "transparent"
                opacity: GlobalStates.launcherOpen ? 1 : 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.launcherOpen = false
                }
            }

            Item {
                id: card
                width: Math.min(Config.options.launcher.width, window.width - 40)
                height: Math.min(Config.options.launcher.height, window.height - 80)
                anchors.horizontalCenter: parent.horizontalCenter
                y: Config.options.launcher.position === "top" ? Appearance.sizes.barHeight + 40 : (window.height - height) / 2.4

                opacity: GlobalStates.launcherOpen ? 1 : 0
                scale: GlobalStates.launcherOpen ? 1 : 0.94
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on scale {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }

                StyledRectangularShadow {
                    target: background
                }
                Rectangle {
                    id: background
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
                    radius: Appearance.rounding.screenRounding
                    border.width: Appearance.sizes.borderWidth
                    border.color: Appearance.colors.colLayer0Border
                    MouseArea { anchors.fill: parent }
                }

                LauncherContent {
                    anchors.fill: parent
                    focus: true
                }
            }
        }
    }

    CompositorGlobalShortcut {
        name: "launcherToggle"
        description: "Toggles the Talos launcher"
        onPressed: TalosLauncher.toggle("")
    }
    CompositorGlobalShortcut {
        name: "launcherCommands"
        description: "Opens the launcher in command mode"
        onPressed: TalosLauncher.toggle("commands")
    }
    CompositorGlobalShortcut {
        name: "launcherThemes"
        description: "Opens the launcher in theme mode"
        onPressed: TalosLauncher.toggle("themes")
    }
    CompositorGlobalShortcut {
        name: "launcherWindows"
        description: "Opens the launcher in window switcher mode"
        onPressed: TalosLauncher.toggle("windows")
    }
    CompositorGlobalShortcut {
        name: "launcherFiles"
        description: "Opens the launcher in file search mode"
        onPressed: TalosLauncher.toggle("files")
    }
}
