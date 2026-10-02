import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

// Desktop card for the Kanban board: next tasks + quick add.
AbstractBackgroundWidget {
    id: root
    configEntryName: "kanban"
    hoverEnabled: true

    implicitWidth: 300
    implicitHeight: 320

    readonly property var upcoming: Kanban.tasks.filter(t => t.column !== Kanban.doneColumn)
        .sort((a, b) => (Kanban.isOverdue(b) - Kanban.isOverdue(a)) || (b.priority - a.priority) || ((a.due || "9999") < (b.due || "9999") ? -1 : 1))
        .slice(0, 6)

    StyledDropShadow {
        target: card
        visible: Config.options.background.widgets.shadow
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding.verylarge
        color: Appearance.colors.colLayer1

        FastBlurred {
            anchors.fill: parent
            blurSource: root.wallpaperItem
            cardRadius: card.radius
            tint: Appearance.colors.colLayer1
            tintOpacity: 0.55
            trackX: root.x
            trackY: root.y
            visible: Config.options.background.widgets.blurWidgets
        }

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                MaterialSymbol { text: "view_kanban"; iconSize: 22; color: Appearance.colors.colPrimary }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Tasks")
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
                Rectangle {
                    visible: Kanban.overdueCount > 0
                    implicitHeight: 22
                    implicitWidth: overdueText.implicitWidth + 14
                    radius: Math.min(height / 2, Appearance.rounding.full)
                    color: Appearance.colors.colErrorContainer
                    StyledText { id: overdueText; anchors.centerIn: parent; text: Translation.tr("%1 late").arg(Kanban.overdueCount); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colOnErrorContainer }
                }
                RippleButton {
                    implicitWidth: 30; implicitHeight: 30
                    buttonRadius: Appearance.rounding.full
                    onClicked: { GlobalStates.dashboardTab = "tasks"; GlobalStates.dashboardOpen = true; }
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "open_in_full"; iconSize: 18; color: Appearance.colors.colOnLayer1 }
                }
            }

            Repeater {
                model: root.upcoming
                delegate: RippleButton {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 34
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    onClicked: Kanban.moveTask(modelData.id, Kanban.doneColumn)
                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Rectangle { width: 4; Layout.fillHeight: true; Layout.margins: 6; radius: 2; color: Kanban.priorityColor(row.modelData.priority) }
                        StyledText { Layout.fillWidth: true; text: row.modelData.title; elide: Text.ElideRight; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer2 }
                        StyledText {
                            visible: row.modelData.due !== ""
                            text: Kanban.formatDue(row.modelData)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Kanban.isOverdue(row.modelData) ? Appearance.colors.colError : Appearance.colors.colSubtext
                        }
                    }
                }
            }
            StyledText {
                visible: root.upcoming.length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20
                text: Translation.tr("Nothing to do ✨")
                color: Appearance.colors.colSubtext
            }
            Item { Layout.fillHeight: true }
            ToolbarTextField {
                Layout.fillWidth: true
                Layout.fillHeight: false
                implicitHeight: 38
                placeholderText: Translation.tr("Add task (!3 @today #tag)")
                onActiveFocusChanged: GlobalStates.desktopWidgetKeyboardFocus = activeFocus
                onAccepted: { Kanban.quickAdd(text); text = ""; }
            }
        }
    }
}
