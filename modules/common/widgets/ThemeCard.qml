import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * A theme preset preview: a tiny desktop painted with the theme's own colors.
 * `theme` is an entry of ThemeEngine.themes.
 */
RippleButton {
    id: root
    required property var theme
    property bool selected: false
    property bool favorite: false
    signal favoriteToggled()

    readonly property var sw: theme?.swatches ?? ({})

    implicitWidth: 184
    implicitHeight: 150
    buttonRadius: Appearance.rounding.normal
    colBackground: root.selected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
    colBackgroundHover: root.selected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
    colRipple: Appearance.colors.colLayer2Active

    contentItem: ColumnLayout {
        spacing: 6

        // Mini desktop
        Rectangle {
            id: preview
            Layout.fillWidth: true
            Layout.preferredHeight: 86
            radius: Appearance.rounding.small
            color: root.sw.bg ?? "#222"
            border.width: root.selected ? 2 : 1
            border.color: root.selected ? Appearance.colors.colPrimary : Qt.rgba(1, 1, 1, 0.06)
            clip: true

            // Bar
            Rectangle {
                id: miniBar
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 5 }
                height: 11
                radius: Math.min(height / 2, Appearance.rounding.full)
                color: root.sw.surface ?? "#333"
                Row {
                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Repeater {
                        model: [root.sw.primary, root.sw.secondary, root.sw.tertiary]
                        delegate: Rectangle {
                            required property var modelData
                            width: 5; height: 5
                            radius: Math.min(width / 2, Appearance.rounding.full)
                            color: modelData ?? "#888"
                        }
                    }
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    width: 16; height: 4; radius: 2
                    color: root.sw.fg ?? "#ddd"
                    opacity: 0.7
                }
            }

            // Window
            Rectangle {
                anchors { left: parent.left; top: miniBar.bottom; leftMargin: 10; topMargin: 7 }
                width: parent.width * 0.58
                height: 44
                radius: Appearance.rounding.verysmall
                color: root.sw.surface ?? "#333"
                Column {
                    anchors { left: parent.left; top: parent.top; margins: 6 }
                    spacing: 4
                    Rectangle { width: 46; height: 4; radius: 2; color: root.sw.fg ?? "#ddd" }
                    Rectangle { width: 32; height: 4; radius: 2; color: root.sw.fg ?? "#ddd"; opacity: 0.55 }
                    Rectangle { width: 38; height: 4; radius: 2; color: root.sw.fg ?? "#ddd"; opacity: 0.55 }
                }
                Rectangle {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                    width: 22; height: 9
                    radius: Math.min(height / 2, Appearance.rounding.full)
                    color: root.sw.primary ?? "#88f"
                }
            }

            // Floating accent "fab"
            Rectangle {
                anchors { right: parent.right; bottom: strip.top; margins: 8 }
                width: 18; height: 18
                radius: Appearance.rounding.small
                color: root.sw.tertiary ?? "#f8a"
            }

            // Palette strip
            Row {
                id: strip
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 6
                Repeater {
                    model: root.sw.strip ?? []
                    delegate: Rectangle {
                        required property var modelData
                        width: strip.width / Math.max(1, (root.sw.strip ?? []).length)
                        height: strip.height
                        color: modelData
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: root.theme?.name ?? ""
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                }
                StyledText {
                    Layout.fillWidth: true
                    text: `${root.theme?.mode === "light" ? "Light" : "Dark"} · ${root.theme?.builtin === false ? "Custom" : (root.theme?.author ?? "")}`
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }
            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                onClicked: root.favoriteToggled()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "star"
                    fill: root.favorite ? 1 : 0
                    iconSize: Appearance.font.pixelSize.larger
                    color: root.favorite ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
            }
        }
    }
}
