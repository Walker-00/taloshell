import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    required property var item
    property bool selected: false
    property bool compact: false
    property int shortcutIndex: 0
    signal hoverEntered()
    signal activated(bool alternate)

    implicitHeight: compact ? 40 : 56
    buttonRadius: Appearance.rounding.normal
    colBackground: selected ? Appearance.colors.colSecondaryContainer : "transparent"
    colBackgroundHover: selected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colSecondaryContainerActive
    onClicked: root.activated(false)
    altAction: () => root.activated(true)

    HoverHandler {
        onHoveredChanged: if (hovered) root.hoverEntered()
    }

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: 12

        LauncherIcon {
            item: root.item
            size: root.compact ? 26 : 36
            highlighted: root.selected
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.item?.title ?? ""
                elide: Text.ElideRight
                font.pixelSize: root.compact ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.normal
                font.weight: root.selected ? Font.Medium : Font.Normal
                color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                visible: !root.compact && (root.item?.subtitle ?? "").length > 0
                text: root.item?.subtitle ?? ""
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        // Mode tag (useful in the mixed "All" mode)
        Rectangle {
            visible: TalosLauncher.mode === "all" && (root.item?.mode ?? "") !== "apps"
            implicitHeight: 20
            implicitWidth: modeTag.implicitWidth + 12
            radius: Math.min(height / 2, Appearance.rounding.full)
            color: Appearance.colors.colLayer2
            StyledText {
                id: modeTag
                anchors.centerIn: parent
                text: TalosLauncher.modeDef(root.item?.mode ?? "all").name
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
        }

        StyledText {
            visible: root.shortcutIndex > 0 && !root.compact
            text: `^${root.shortcutIndex}`
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.family: Appearance.font.family.monospace
            color: Appearance.colors.colSubtext
            opacity: root.selected ? 1 : 0.5
        }
    }
}
