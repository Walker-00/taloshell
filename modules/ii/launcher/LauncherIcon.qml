import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Widgets

/**
 * Renders a launcher result's icon according to its iconType:
 * material symbol, system (freedesktop) icon, image file, text (emoji) or theme swatch.
 */
Item {
    id: root
    required property var item
    property real size: 36
    property bool highlighted: false
    readonly property string type: item?.iconType ?? "material"

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        visible: root.type === "material"
        radius: Appearance.rounding.small
        color: root.highlighted ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
        MaterialSymbol {
            anchors.centerIn: parent
            text: root.item?.icon ?? "apps"
            iconSize: root.size * 0.58
            fill: root.highlighted ? 1 : 0
            color: root.highlighted ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
        }
    }

    IconImage {
        anchors.fill: parent
        visible: root.type === "system"
        source: root.type === "system" ? Quickshell.iconPath(root.item?.icon ?? "", "application-x-executable") : ""
        implicitSize: root.size
    }

    StyledImageRounded {
        anchors.fill: parent
        visible: root.type === "image"
    }
    component StyledImageRounded: Rectangle {
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        clip: true
        Image {
            anchors.fill: parent
            source: root.type === "image" ? (root.item?.image ?? "") : ""
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.type === "text"
        text: root.type === "text" ? (root.item?.icon ?? "") : ""
        font.pixelSize: root.size * 0.75
    }

    // Theme swatch: background with 3 accent dots
    Rectangle {
        anchors.fill: parent
        visible: root.type === "swatch"
        radius: Appearance.rounding.small
        color: root.item?.swatches?.bg ?? "#222"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: 2
            Repeater {
                model: [root.item?.swatches?.primary, root.item?.swatches?.secondary, root.item?.swatches?.tertiary, root.item?.swatches?.fg]
                delegate: Rectangle {
                    required property var modelData
                    width: root.size * 0.26
                    height: width
                    radius: Math.min(width / 2, Appearance.rounding.full)
                    color: modelData ?? "#888"
                }
            }
        }
    }

    // Small corner badge (pinned, current...)
    Rectangle {
        visible: (root.item?.badge ?? "").length > 0
        anchors { right: parent.right; bottom: parent.bottom; margins: -3 }
        width: root.size * 0.42
        height: width
        radius: Math.min(width / 2, Appearance.rounding.full)
        color: Appearance.colors.colPrimary
        MaterialSymbol {
            anchors.centerIn: parent
            text: root.item?.badge ?? ""
            iconSize: parent.width * 0.7
            fill: 1
            color: Appearance.colors.colOnPrimary
        }
    }
}
