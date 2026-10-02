pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.dashboard.tabs.graph // registers the Graph tab components with the shell
import QtQuick
import QtQuick.Layouts

FocusScope {
    id: root
    property real padding: 16
    readonly property real pageHeight: 560

    readonly property var allTabs: {
        const tabs = {
            overview: { name: Translation.tr("Overview"), icon: "dashboard", source: "tabs/OverviewTab.qml" },
            media: { name: Translation.tr("Media"), icon: "queue_music", source: "tabs/MediaTab.qml" },
            performance: { name: Translation.tr("Performance"), icon: "speed", source: "tabs/PerformanceTab.qml" },
            tasks: { name: Translation.tr("Tasks"), icon: "view_kanban", source: "tabs/TasksTab.qml" },
            weather: { name: Translation.tr("Weather"), icon: "partly_cloudy_day", source: "tabs/WeatherTab.qml" },
            graph: { name: Translation.tr("Graph"), icon: "function", source: "tabs/GraphTab.qml" },
        };
        // tabIds drops ids that are not here, so mail disappears from the bar
        // when it is switched off without the id having to leave the config.
        if (Config.options.mail.enable)
            tabs.mail = { name: Translation.tr("Mail"), icon: "mail", source: "tabs/MailTab.qml" };
        return tabs;
    }
    readonly property var tabIds: Config.options.dashboard.tabs.filter(t => root.allTabs[t] !== undefined)
    readonly property var fullTabButtonList: tabIds.map(t => ({ name: root.allTabs[t].name, icon: root.allTabs[t].icon }))
    // With many tabs the labelled bar no longer fits the card: fall back to
    // icon-only tabs, and drop the greeting if even that is too wide.
    readonly property real headerAvailable: root.width - root.padding * 2
    readonly property real headerFixed: settingsButton.implicitWidth + header.spacing * 4
    readonly property real greetingWidth: Config.options.dashboard.showGreeting ? greeting.implicitWidth : 0
    readonly property bool compactTabs: fullTabMeasure.implicitWidth + root.greetingWidth + root.headerFixed > root.headerAvailable
    readonly property bool hideGreeting: root.compactTabs && iconTabMeasure.implicitWidth + root.greetingWidth + root.headerFixed > root.headerAvailable
    readonly property var tabButtonList: root.compactTabs
        ? tabIds.map(t => ({ name: "", tooltip: root.allTabs[t].name, icon: root.allTabs[t].icon }))
        : root.fullTabButtonList

    function selectTab(id) {
        const i = root.tabIds.indexOf(id);
        if (i >= 0) tabBar.setCurrentIndex(i);
    }

    function greeting() {
        const h = DateTime.clock.date.getHours();
        if (h < 5) return Translation.tr("Good night");
        if (h < 12) return Translation.tr("Good morning");
        if (h < 18) return Translation.tr("Good afternoon");
        return Translation.tr("Good evening");
    }

    implicitHeight: header.implicitHeight + root.pageHeight + root.padding * 3

    Component.onCompleted: {
        const requested = GlobalStates.dashboardTab;
        const start = requested.length > 0 ? requested
            : Config.options.dashboard.rememberTab ? Config.options.dashboard.lastTab : root.tabIds[0];
        GlobalStates.dashboardTab = "";
        root.selectTab(start);
        root.forceActiveFocus();
    }

    Connections {
        target: GlobalStates
        function onDashboardTabChanged() {
            if (GlobalStates.dashboardTab.length === 0) return;
            root.selectTab(GlobalStates.dashboardTab);
            GlobalStates.dashboardTab = "";
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.dashboardOpen = false;
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Tab || event.key === Qt.Key_PageDown)) {
            tabBar.setCurrentIndex((tabBar.currentIndex + 1) % root.tabIds.length);
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp)) {
            tabBar.setCurrentIndex((tabBar.currentIndex - 1 + root.tabIds.length) % root.tabIds.length);
            event.accepted = true;
        } else if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            const i = event.key - Qt.Key_1;
            if (i < root.tabIds.length) tabBar.setCurrentIndex(i);
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: root.padding

        // off-screen measurements for the compact header decision
        ToolbarTabBar {
            id: fullTabMeasure
            visible: false
            Layout.preferredWidth: 0
            Layout.preferredHeight: 0
            tabButtonList: root.fullTabButtonList
        }
        ToolbarTabBar {
            id: iconTabMeasure
            visible: false
            Layout.preferredWidth: 0
            Layout.preferredHeight: 0
            tabButtonList: root.tabIds.map(t => ({ name: "", icon: root.allTabs[t].icon }))
        }

        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                id: greeting
                visible: Config.options.dashboard.showGreeting && !root.hideGreeting
                spacing: -2
                StyledText {
                    text: `${root.greeting()}, ${Config.options.profile.displayName || SystemInfo.username}`
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.family: Appearance.font.family.title
                    font.variableAxes: Appearance.font.variableAxes.title
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    text: DateTime.collapsedCalendarFormat
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
            Item { Layout.fillWidth: true }
            ToolbarTabBar {
                id: tabBar
                tabButtonList: root.tabButtonList
                onCurrentIndexChanged: {
                    if (Config.options.dashboard.rememberTab && root.tabIds[currentIndex])
                        Config.options.dashboard.lastTab = root.tabIds[currentIndex];
                }
            }
            Item { Layout.fillWidth: true }
            RippleButton {
                id: settingsButton
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                onClicked: {
                    GlobalStates.dashboardOpen = false;
                    GlobalStates.settingsOpen = true;
                    GlobalStates.settingsPage = "Dashboard";
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "tune"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer0
                }
                StyledToolTip { text: Translation.tr("Dashboard settings") }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: root.pageHeight
            clip: true

            Repeater {
                model: root.tabIds
                delegate: Loader {
                    id: tabLoader
                    required property string modelData
                    required property int index
                    readonly property bool current: tabBar.currentIndex === index
                    anchors.fill: parent
                    // Load lazily, keep loaded once visited
                    active: current || item !== null
                    source: root.allTabs[modelData].source
                    visible: opacity > 0
                    opacity: current ? 1 : 0
                    focus: current
                    transform: Translate {
                        x: tabLoader.current ? 0 : (tabLoader.index < tabBar.currentIndex ? -30 : 30)
                        Behavior on x {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
            }
        }
    }
}
