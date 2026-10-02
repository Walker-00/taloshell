import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Unread mail badge. Clicking it opens the sidebar, where the mail tab lives.
 */
MaterialSymbol {
    id: root
    readonly property bool isDi: GlobalStates.dynamicIslandEnabled && Config.options.bar.dynamicIsland.rightWidget === "systemIcons"

    text: "mail"
    iconSize: Appearance.font.pixelSize.larger
    color: root.isDi ? Appearance.colors.colOnLayer1 : (Config.options.bar.cornerStyle === 3 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
    }

    Rectangle {
        id: badge
        anchors.right: parent.right
        anchors.top: parent.top
        radius: Appearance.rounding.full
        color: root.isDi ? Appearance.colors.colOnLayer1 : (Config.options.bar.cornerStyle === 3 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0)
        z: 1

        implicitHeight: Math.max(counter.implicitWidth, counter.implicitHeight)
        implicitWidth: implicitHeight

        StyledText {
            id: counter
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: root.isDi ? Appearance.colors.colOnPrimary : (Config.options.bar.cornerStyle === 3 ? Appearance.colors.colPrimary : Appearance.colors.colLayer0)
            // Three digits would push the badge past the icon it sits on.
            text: Pigeon.unread > 99 ? "99+" : Pigeon.unread
        }
    }
}
