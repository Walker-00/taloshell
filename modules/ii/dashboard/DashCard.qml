import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Rounded dashboard tile with an optional header (icon + title + trailing item).
 */
Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    property real padding: 14
    property alias headerTrailing: trailingSlot.data
    default property alias content: body.data

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.large
    border.width: Appearance.sizes.borderWidth > 1 ? Appearance.sizes.borderWidth : 0
    border.color: Appearance.colors.colLayer0Border
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 8

        RowLayout {
            visible: root.title.length > 0
            Layout.fillWidth: true
            spacing: 6
            MaterialSymbol {
                visible: root.icon.length > 0
                text: root.icon
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }
            Item {
                id: trailingSlot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }

        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
