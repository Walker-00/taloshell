import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Preview of a "look" (LookEngine.looks entry): draws a tiny desktop using the
 * current theme colors but the look's own shapes, bar style and borders.
 */
RippleButton {
    id: root
    required property var look
    property bool selected: false

    readonly property var cfg: look?.config ?? ({})
    readonly property var st: cfg.appearance?.style ?? ({})
    readonly property var bar: cfg.bar ?? ({})
    readonly property bool waffle: cfg.panelFamily === "waffle"
    readonly property real r: 10 * (st.roundingScale ?? 1)
    readonly property bool pills: st.pillShapes ?? true
    readonly property real bw: st.borderWidth ?? 1
    readonly property color borderCol: {
        switch (st.borderColor ?? "default") {
            case "primary": return Appearance.colors.colPrimary;
            case "outline": return Appearance.colors.colOutline;
            case "onSurface": return Appearance.colors.colOnLayer0;
            default: return Appearance.colors.colOutlineVariant;
        }
    }
    readonly property int corner: bar.cornerStyle ?? 0
    readonly property bool vertical: bar.vertical ?? false
    readonly property bool frame: bar.showFrame ?? false
    readonly property bool translucent: cfg.appearance?.transparency?.enable ?? false

    implicitWidth: 184
    implicitHeight: 156
    buttonRadius: Appearance.rounding.normal
    colBackground: root.selected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
    colBackgroundHover: root.selected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
    colRipple: Appearance.colors.colLayer2Active

    function pill(h) { return root.pills ? h / 2 : Math.min(h / 2, root.r); }

    contentItem: ColumnLayout {
        spacing: 6

        Rectangle {
            id: desk
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            radius: Appearance.rounding.small
            clip: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Appearance.colors.colPrimaryContainer }
                GradientStop { position: 1; color: Appearance.colors.colTertiaryContainer }
            }
            border.width: root.selected ? 2 : 0
            border.color: Appearance.colors.colPrimary

            // Screen frame (bezel)
            Rectangle {
                visible: root.frame
                anchors.fill: parent
                color: "transparent"
                radius: parent.radius
                border.width: 5
                border.color: Appearance.colors.colLayer0
            }

            // Horizontal bars
            Item {
                id: hbar
                visible: !root.vertical && !root.waffle
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 16

                // hug / plain / panel / float background
                Rectangle {
                    visible: root.corner !== 3
                    anchors.fill: parent
                    anchors.margins: root.corner === 1 ? 4 : 0
                    color: Appearance.colors.colLayer0
                    opacity: root.translucent ? 0.7 : 1
                    radius: root.corner === 1 ? root.pill(height) : 0
                    bottomLeftRadius: root.corner === 0 ? root.r : radius
                    bottomRightRadius: root.corner === 0 ? root.r : radius
                    border.width: root.corner === 1 ? root.bw : 0
                    border.color: root.borderCol
                }
                // groups
                Row {
                    anchors { left: parent.left; leftMargin: root.corner === 1 ? 8 : 5; verticalCenter: parent.verticalCenter }
                    spacing: root.corner === 3 ? 4 : 2
                    Repeater {
                        model: 2
                        delegate: Rectangle {
                            width: 22; height: 9
                            radius: root.pill(height)
                            color: root.corner === 3 ? Appearance.colors.colLayer0 : Appearance.colors.colLayer1
                            border.width: (root.bar.borderless === "segmented" || root.corner === 3) ? root.bw : 0
                            border.color: root.borderCol
                        }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 30; height: 9
                    radius: root.pill(height)
                    color: root.corner === 3 ? Appearance.colors.colLayer0 : Appearance.colors.colLayer1
                    border.width: (root.bar.borderless === "segmented" || root.corner === 3) ? root.bw : 0
                    border.color: root.borderCol
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: root.corner === 1 ? 8 : 5; verticalCenter: parent.verticalCenter }
                    width: 26; height: 9
                    radius: root.pill(height)
                    color: root.corner === 3 ? Appearance.colors.colLayer0 : Appearance.colors.colLayer1
                    border.width: (root.bar.borderless === "segmented" || root.corner === 3) ? root.bw : 0
                    border.color: root.borderCol
                }
            }

            // Vertical rail
            Rectangle {
                visible: root.vertical && !root.waffle
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: root.corner === 1 ? 4 : 0 }
                width: 14
                color: Appearance.colors.colLayer0
                radius: root.corner === 1 ? root.pill(width) : 0
                border.width: root.bw
                border.color: root.borderCol
                Column {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
                    spacing: 4
                    Repeater {
                        model: 3
                        delegate: Rectangle { width: 6; height: 6; radius: root.pill(6); color: Appearance.colors.colPrimary }
                    }
                }
            }

            // Waffle taskbar
            Rectangle {
                visible: root.waffle
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 14
                color: Appearance.colors.colLayer0
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater {
                        model: 6
                        delegate: Rectangle {
                            required property int index
                            width: 8; height: 8; radius: 2
                            color: index === 0 ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                        }
                    }
                }
            }

            // Window
            Rectangle {
                x: root.vertical ? 24 : 12
                y: root.vertical ? 12 : 24
                width: parent.width * 0.55
                height: 46
                radius: root.r
                color: Appearance.colors.colLayer1
                opacity: root.translucent ? 0.85 : 1
                border.width: root.bw
                border.color: root.borderCol
                Rectangle {
                    anchors { left: parent.left; top: parent.top; margins: 7 }
                    width: 40; height: 4; radius: 2
                    color: Appearance.colors.colOnLayer1
                }
                Rectangle {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 7 }
                    width: 24; height: 10
                    radius: root.pill(10)
                    color: Appearance.colors.colPrimary
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            MaterialSymbol {
                text: root.look?.icon ?? "palette"
                iconSize: Appearance.font.pixelSize.larger
                color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                text: root.look?.name ?? ""
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
            }
        }
        StyledText {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            text: root.look?.description ?? ""
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }
    }
}
