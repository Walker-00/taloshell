pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * On-screen math keys for mouse users. Keys never take keyboard focus, so
 * the expression being edited keeps its cursor.
 */
Rectangle {
    id: root
    signal key(string text, bool back)

    implicitHeight: grid.implicitHeight + 12
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer2

    readonly property var keys: [
        { l: "x", t: "x" }, { l: "y", t: "y" }, { l: "a²", t: "^2" }, { l: "aᵇ", t: "^" }, { l: "√", t: "sqrt(" },
        { l: "π", t: "pi" }, { l: "θ", t: "theta" }, { l: "(", t: "(" }, { l: ")", t: ")" }, { l: "|a|", t: "abs(" },
        { l: "sin", t: "sin(" }, { l: "cos", t: "cos(" }, { l: "tan", t: "tan(" }, { l: "ln", t: "ln(" }, { l: "log", t: "log(" },
        { l: "eˣ", t: "e^" }, { l: "≤", t: "<=" }, { l: "≥", t: ">=" }, { l: "÷", t: "/" }, { l: "×", t: "*" },
        { l: "a₁", t: "_" }, { l: "{", t: "{" }, { l: "}", t: "}" }, { l: ",", t: ", " }, { l: "⌫", t: "", back: true },
    ]

    GridLayout {
        id: grid
        anchors.fill: parent
        anchors.margins: 6
        columns: 5
        rowSpacing: 4
        columnSpacing: 4
        Repeater {
            model: root.keys
            delegate: Rectangle {
                id: k
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Appearance.rounding.small
                color: area.pressed ? Appearance.colors.colLayer3Active : area.containsMouse ? Appearance.colors.colLayer3Hover : Appearance.colors.colLayer3
                StyledText {
                    anchors.centerIn: parent
                    text: k.modelData.l
                    font.family: Appearance.font.family.reading
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer3
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.key(k.modelData.t, !!k.modelData.back)
                }
            }
        }
    }
}
