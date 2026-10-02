import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Open task count from the Kanban board; red when something is overdue.
RippleButton {
    id: root
    property bool vertical: Config.options.bar.vertical
    readonly property bool overdue: Kanban.overdueCount > 0

    implicitWidth: vertical ? 22 : content.implicitWidth + 12
    implicitHeight: vertical ? content.implicitHeight + 8 : 22
    buttonRadius: Appearance.rounding.full
    colBackground: overdue ? Appearance.colors.colErrorContainer : "transparent"
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active

    onPressed: { GlobalStates.dashboardTab = "tasks"; GlobalStates.dashboardOpen = true; }
    altAction: () => TalosLauncher.toggle("tasks")

    GridLayout {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        rowSpacing: 0
        columnSpacing: 4
        MaterialSymbol {
            Layout.alignment: Qt.AlignCenter
            text: root.overdue ? "assignment_late" : "task_alt"
            iconSize: 17
            color: root.overdue ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer0
        }
        StyledText {
            Layout.alignment: Qt.AlignCenter
            text: Kanban.openCount
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.overdue ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer0
        }
    }
    StyledToolTip {
        text: Translation.tr("%1 open · %2 due today · %3 overdue\nClick: board · Right-click: quick add").arg(Kanban.openCount).arg(Kanban.dueTodayCount).arg(Kanban.overdueCount)
    }
}
