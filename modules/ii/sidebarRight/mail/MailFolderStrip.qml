pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Folder chips for the account in view. Horizontal because the sidebar is far
 * wider than it is tall, and a tree would cost the list its room.
 */
Flickable {
    id: root
    readonly property var accountFolders: Pigeon.folders.filter(f =>
        f.account === Pigeon.currentAccount && f.selectable)

    implicitHeight: 30
    contentWidth: chips.implicitWidth
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    clip: true

    RowLayout {
        id: chips
        height: parent.height
        spacing: 5

        Repeater {
            model: root.accountFolders

            RippleButton {
                required property var modelData
                readonly property bool current: modelData.name === Pigeon.currentFolder

                implicitHeight: 28
                implicitWidth: chipRow.implicitWidth + 20
                buttonRadius: Appearance.rounding.full
                toggled: current
                onClicked: Pigeon.openFolder(modelData.account, modelData.name)

                contentItem: RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        text: modelData.icon
                        iconSize: Appearance.font.pixelSize.normal
                        color: current ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        text: modelData.display
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: current ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        visible: modelData.unread > 0
                        text: modelData.unread
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: current ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3primary
                    }
                }
            }
        }
    }
}
