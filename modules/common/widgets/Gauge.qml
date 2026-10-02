import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.widgets

/**
 * Speedometer-style arc gauge (inspired by Brain_Shell).
 * value: 0..1
 */
Item {
    id: root
    property real value: 0
    property string label: ""
    property string valueText: `${Math.round(root.value * 100)}%`
    property string subText: ""
    property color color: Appearance.colors.colPrimary
    property color trackColor: Appearance.colors.colSecondaryContainer
    property real size: 120
    property real thickness: Math.max(4, size * 0.085)
    property real sweep: 240 // degrees
    property bool showTicks: true
    property bool warnColors: true // turn tertiary/error when high
    readonly property color effectiveColor: !warnColors ? color
        : value >= 0.9 ? Appearance.colors.colError
        : value >= 0.75 ? Appearance.m3colors.m3tertiary
        : color

    implicitWidth: size
    implicitHeight: size * 0.92

    property real animatedValue: value
    Behavior on animatedValue {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    readonly property real startAngle: 90 + (360 - sweep) / 2 // from +x axis, clockwise (Shape coords)
    readonly property real radius: (size - thickness) / 2

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: Appearance.pillShapes || Appearance.roundingScale > 0.3 ? ShapePath.RoundCap : ShapePath.FlatCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngle
                sweepAngle: root.sweep
            }
        }
        ShapePath {
            strokeColor: root.effectiveColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: Appearance.pillShapes || Appearance.roundingScale > 0.3 ? ShapePath.RoundCap : ShapePath.FlatCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngle
                sweepAngle: Math.max(0.01, root.sweep * Math.max(0, Math.min(1, root.animatedValue)))
            }
        }
    }

    // Tick marks
    Repeater {
        model: root.showTicks ? 11 : 0
        delegate: Rectangle {
            required property int index
            readonly property real angle: (root.startAngle + root.sweep * index / 10) * Math.PI / 180
            readonly property real r: root.radius - root.thickness * 1.3
            width: index % 5 === 0 ? 2 : 1
            height: index % 5 === 0 ? root.thickness * 0.9 : root.thickness * 0.5
            radius: 1
            color: Appearance.colors.colOutline
            opacity: 0.6
            x: root.size / 2 + Math.cos(angle) * r - width / 2
            y: root.size / 2 + Math.sin(angle) * r - height / 2
            rotation: angle * 180 / Math.PI + 90
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.size * 0.02
        spacing: 0
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valueText
            font.pixelSize: Math.round(root.size * 0.2)
            font.family: Appearance.font.family.numbers
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text.length > 0
            text: root.subText
            font.pixelSize: Math.max(9, Math.round(root.size * 0.085))
            color: Appearance.colors.colSubtext
        }
    }

    StyledText {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        text: root.label
        font.pixelSize: Math.max(10, Math.round(root.size * 0.105))
        font.weight: Font.Medium
        color: Appearance.colors.colOnLayer1
    }
}
