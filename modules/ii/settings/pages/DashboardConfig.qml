import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    readonly property var tabDefs: {
        const defs = [
            { id: "overview", name: Translation.tr("Overview"), icon: "dashboard" },
            { id: "media", name: Translation.tr("Media"), icon: "queue_music" },
            { id: "performance", name: Translation.tr("Performance"), icon: "speed" },
            { id: "tasks", name: Translation.tr("Tasks"), icon: "view_kanban" },
            { id: "weather", name: Translation.tr("Weather"), icon: "partly_cloudy_day" },
            { id: "graph", name: Translation.tr("Graph"), icon: "function" },
        ];
        if (Config.options.mail.enable)
            defs.push({ id: "mail", name: Translation.tr("Mail"), icon: "mail" });
        return defs;
    }

    function goTo(term) {
        const t = term.toLowerCase().trim();
        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                const child = rootItem.children[i];
                if (child.title && child.title.toLowerCase().includes(t)) return child;
            }
            for (let i = 0; i < rootItem.children.length; i++) {
                const found = findTarget(rootItem.children[i]);
                if (found) return found;
            }
            return null;
        }
        const target = findTarget(mainLayout);
        if (target) page.contentY = Math.max(0, target.mapToItem(mainLayout, 0, 0).y);
    }

    function moveTab(id, delta) {
        const tabs = Config.options.dashboard.tabs.slice();
        const i = tabs.indexOf(id);
        const j = i + delta;
        if (i < 0 || j < 0 || j >= tabs.length) return;
        tabs.splice(j, 0, tabs.splice(i, 1)[0]);
        Config.options.dashboard.tabs = tabs;
    }

    function toggleTab(id, on) {
        const tabs = Config.options.dashboard.tabs.filter(t => t !== id);
        if (on) tabs.push(id);
        if (tabs.length > 0) Config.options.dashboard.tabs = tabs;
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        spacing: 20

        ContentSection {
            icon: "dashboard"
            shape: MaterialShape.Shape.Cookie7Sided
            title: Translation.tr("Dashboard")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable dashboard")
                    checked: Config.options.dashboard.enable
                    onCheckedChanged: Config.options.dashboard.enable = checked
                }
                ConfigSelectionArray {
                    text: Translation.tr("Position")
                    icon: "vertical_align_top"
                    currentValue: Config.options.dashboard.position
                    onSelected: v => Config.options.dashboard.position = v
                    options: [
                        { displayName: Translation.tr("Below bar"), icon: "vertical_align_top", value: "top" },
                        { displayName: Translation.tr("Center"), icon: "center_focus_strong", value: "center" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "gradient"
                    text: Translation.tr("Dim the background")
                    checked: Config.options.dashboard.dimBackground
                    onCheckedChanged: Config.options.dashboard.dimBackground = checked
                }
                ConfigSwitch {
                    buttonIcon: "waving_hand"
                    text: Translation.tr("Show greeting")
                    checked: Config.options.dashboard.showGreeting
                    onCheckedChanged: Config.options.dashboard.showGreeting = checked
                }
                ConfigSwitch {
                    buttonIcon: "history"
                    text: Translation.tr("Reopen on the last tab")
                    checked: Config.options.dashboard.rememberTab
                    onCheckedChanged: Config.options.dashboard.rememberTab = checked
                }
                ConfigSwitch {
                    buttonIcon: "schedule"
                    text: Translation.tr("Clicking the bar clock opens it")
                    checked: Config.options.dashboard.clockOpensDashboard
                    onCheckedChanged: Config.options.dashboard.clockOpensDashboard = checked
                }
                ConfigSpinBox {
                    icon: "width"
                    text: Translation.tr("Width")
                    from: 700; to: 1600; stepSize: 20
                    value: Config.options.dashboard.width
                    onValueChanged: Config.options.dashboard.width = value
                }
            }
        }

        ContentSection {
            icon: "tab"
            shape: MaterialShape.Shape.Pill
            title: Translation.tr("Tabs")
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Pick which tabs appear and their order. Alt+1…9 jumps to a tab, Ctrl+Tab cycles.")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: page.tabDefs.slice().sort((a, b) => {
                        const tabs = Config.options.dashboard.tabs;
                        const ia = tabs.indexOf(a.id), ib = tabs.indexOf(b.id);
                        return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
                    })
                    delegate: Rectangle {
                        id: tabRow
                        required property var modelData
                        readonly property bool enabledTab: Config.options.dashboard.tabs.includes(modelData.id)
                        Layout.fillWidth: true
                        implicitHeight: tabRowLayout.implicitHeight + 16
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                        RowLayout {
                            id: tabRowLayout
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }

                            spacing: 8
                            MaterialSymbol { text: tabRow.modelData.icon; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                            StyledText { Layout.fillWidth: true; text: tabRow.modelData.name; color: Appearance.colors.colOnSecondaryContainer }
                            RippleButton {
                                implicitWidth: 30; implicitHeight: 30
                                buttonRadius: Appearance.rounding.full
                                enabled: tabRow.enabledTab
                                onClicked: page.moveTab(tabRow.modelData.id, -1)
                                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "arrow_upward"; iconSize: 18; color: Appearance.colors.colOnLayer1 }
                            }
                            RippleButton {
                                implicitWidth: 30; implicitHeight: 30
                                buttonRadius: Appearance.rounding.full
                                enabled: tabRow.enabledTab
                                onClicked: page.moveTab(tabRow.modelData.id, 1)
                                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "arrow_downward"; iconSize: 18; color: Appearance.colors.colOnLayer1 }
                            }
                            StyledSwitch {
                                checked: tabRow.enabledTab
                                onClicked: page.toggleTab(tabRow.modelData.id, checked)
                            }
                    
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "view_kanban"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Tasks board")
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Quick-add syntax works everywhere (dashboard, launcher “+”, IPC): “Write report !3 @tomorrow #work”. !0-4 sets priority, @today/@tomorrow/@YYYY-MM-DD sets the due date, #word adds a tag. You'll get a notification when a task is due.")
            }
            RowLayout {
                spacing: 8
                RippleButtonWithIcon {
                    materialIcon: "view_kanban"
                    mainText: Translation.tr("Open board")
                    onClicked: { GlobalStates.settingsOpen = false; GlobalStates.dashboardTab = "tasks"; GlobalStates.dashboardOpen = true; }
                }
                RippleButtonWithIcon {
                    materialIcon: "playlist_add_check"
                    mainText: Translation.tr("Import sidebar to-dos")
                    onClicked: Kanban.importTodo()
                }
            }
        }
    }
}
