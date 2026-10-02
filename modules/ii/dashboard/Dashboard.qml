pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * taloshell dashboard: a tabbed panel (overview, media, performance, tasks,
 * weather) that drops from the bar or pops up in the center.
 * IPC: qs -c taloshell ipc call dashboard <toggle|open|close|tab <name>>
 */
Scope {
    id: root

    readonly property bool barBottom: Config.options.bar.bottom && !Config.options.bar.vertical
    readonly property bool centered: Config.options.dashboard.position === "center" || Config.options.bar.vertical
    property bool closing: false

    function open(tab = "") {
        if (tab.length > 0) GlobalStates.dashboardTab = tab;
        GlobalStates.dashboardOpen = true;
    }

    Connections {
        target: GlobalStates
        function onDashboardOpenChanged() {
            if (!GlobalStates.dashboardOpen) {
                root.closing = true;
                closeTimer.restart();
            }
        }
    }
    Timer {
        id: closeTimer
        interval: Appearance.animation.elementMoveExit.duration + 30
        onTriggered: root.closing = false
    }

    Loader {
        id: loader
        active: Config.options.dashboard.enable && (GlobalStates.dashboardOpen || root.closing)

        sourceComponent: PanelWindow {
            id: window
            visible: !GlobalStates.dashboardSuspended
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:dashboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.dashboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            // Scrim: click anywhere outside the card to close
            Rectangle {
                anchors.fill: parent
                color: Config.options.dashboard.dimBackground ? Appearance.colors.colScrim : "transparent"
                opacity: GlobalStates.dashboardOpen ? 1 : 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.dashboardOpen = false
                }
            }

            Item {
                id: cardArea
                readonly property real topInset: root.barBottom ? Appearance.sizes.hyprlandGapsOut * 2
                    : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut * 2
                readonly property real bottomInset: root.barBottom ? Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut * 2
                    : Appearance.sizes.hyprlandGapsOut * 2
                width: Math.min(Config.options.dashboard.width, window.width - 40)
                height: Math.min(content.implicitHeight, window.height - topInset - bottomInset)
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.centered ? (window.height - height) / 2
                    : root.barBottom ? window.height - height - bottomInset
                    : topInset

                opacity: GlobalStates.dashboardOpen ? 1 : 0
                scale: GlobalStates.dashboardOpen ? 1 : 0.96
                transform: Translate {
                    y: GlobalStates.dashboardOpen ? 0 : (root.centered ? 0 : (root.barBottom ? 24 : -24))
                    Behavior on y {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on scale {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }

                StyledRectangularShadow {
                    target: cardBackground
                }
                Rectangle {
                    id: cardBackground
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
                    radius: Appearance.rounding.screenRounding
                    border.width: Appearance.sizes.borderWidth
                    border.color: Appearance.colors.colLayer0Border
                    // Swallow clicks so they don't reach the scrim
                    MouseArea { anchors.fill: parent }
                }

                DashboardContent {
                    id: content
                    anchors.fill: parent
                    clip: true // never paint past the card, whatever a tab asks for
                    focus: GlobalStates.dashboardOpen
                }
            }
        }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen; }
        function open(): void { root.open(); }
        function close(): void { GlobalStates.dashboardOpen = false; }
        function tab(name: string): void { root.open(name); }
    }

    CompositorGlobalShortcut {
        name: "dashboardToggle"
        description: "Toggles the dashboard"
        onPressed: GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
    }
    CompositorGlobalShortcut {
        name: "dashboardPerformance"
        description: "Opens the dashboard on the performance tab"
        onPressed: root.open("performance")
    }
    CompositorGlobalShortcut {
        name: "dashboardTasks"
        description: "Opens the dashboard on the tasks tab"
        onPressed: root.open("tasks")
    }
}
