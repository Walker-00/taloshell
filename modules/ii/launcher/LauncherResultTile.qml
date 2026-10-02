import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var item
    property bool selected: false
    property bool imageMode: false
    signal hoverEntered()
    signal activated(bool alternate)

    RippleButton {
        anchors.fill: parent
        anchors.margins: 4
        buttonRadius: Appearance.rounding.normal
        colBackground: root.selected ? Appearance.colors.colSecondaryContainer : "transparent"
        colBackgroundHover: root.selected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
        onClicked: root.activated(false)
        altAction: () => root.activated(true)
        HoverHandler {
            onHoveredChanged: if (hovered) root.hoverEntered()
        }

        // Wallpaper tile: full-bleed image
        Rectangle {
            visible: root.imageMode
            anchors.fill: parent
            anchors.margins: 4
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            clip: true
            border.width: root.selected ? 3 : 0
            border.color: Appearance.colors.colPrimary
            Image {
                anchors.fill: parent
                anchors.margins: parent.border.width
                source: root.imageMode ? (root.item?.image ?? "") : ""
                sourceSize: Qt.size(width * 1.5, height * 1.5)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                visible: (root.item?.badge ?? "") !== ""
                anchors { right: parent.right; top: parent.top; margins: 6 }
                width: 22; height: 22
                radius: Math.min(width / 2, Appearance.rounding.full)
                color: Appearance.colors.colPrimary
                MaterialSymbol { anchors.centerIn: parent; text: "check"; iconSize: 16; color: Appearance.colors.colOnPrimary }
            }
        }

        ColumnLayout {
            visible: !root.imageMode
            anchors.centerIn: parent
            width: parent.width - 8
            spacing: 4
            LauncherIcon {
                Layout.alignment: Qt.AlignHCenter
                item: root.item
                size: root.item?.iconType === "text" ? 40 : 48
                highlighted: root.selected
            }
            StyledText {
                visible: root.item?.iconType !== "text"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.item?.title ?? ""
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
            }
        }
    }
}
