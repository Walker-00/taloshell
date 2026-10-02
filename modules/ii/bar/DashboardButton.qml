import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Opens the taloshell dashboard. Right click: performance tab.
RippleButton {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: isMaterial ? 32 : 22
    implicitHeight: implicitWidth
    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? Appearance.colors.colSecondaryContainer : "transparent"
    colBackgroundHover: isMaterial ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    toggled: GlobalStates.dashboardOpen
    colBackgroundToggled: Appearance.colors.colSecondaryContainer

    onPressed: GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
    altAction: () => { GlobalStates.dashboardTab = "performance"; GlobalStates.dashboardOpen = true; }

    MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 18
        text: "dashboard"
        fill: GlobalStates.dashboardOpen ? 1 : 0
        color: Appearance.colors.colOnLayer0
    }
    StyledToolTip { text: Translation.tr("Dashboard · right-click: performance") }
}
