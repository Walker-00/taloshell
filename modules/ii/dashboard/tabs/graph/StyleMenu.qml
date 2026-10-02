pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Per-row style menu (Desmos' long-press menu): colour, line style and
 * thickness, opacity, region fill, point style, labels and row actions.
 */
Rectangle {
    id: root
    property int rowIndex: -1
    signal closeRequested()

    readonly property var row: rowIndex >= 0 && rowIndex < Metis.rows.count ? Metis.rows.get(rowIndex) : null
    readonly property var r: Metis.result
    readonly property bool hasCurve: (r?.curves ?? []).some(c => c.row === rowIndex)
    readonly property bool hasRegion: (r?.regions ?? []).some(c => c.row === rowIndex)
    readonly property bool hasPoints: (r?.points ?? []).some(p => p.row === rowIndex) || row?.kind === "table"
    readonly property bool isPointList: (r?.points ?? []).some(p => p.row === rowIndex)

    implicitWidth: 250
    implicitHeight: col.implicitHeight + 24
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer3Base
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    MouseArea { anchors.fill: parent }

    function set(prop, value) { Metis.setProp(root.rowIndex, prop, value); }

    // The model row object is not reactive; re-read it when roles change.
    property int revision: 0
    Connections {
        target: Metis.rows
        function onDataChanged() { root.revision++; }
    }
    function val(prop) { root.revision; return root.row ? Metis.rows.get(root.rowIndex)[prop] : undefined; }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // colours
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: Metis.palette.length
                delegate: Rectangle {
                    required property int index
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: Metis.palette[index]
                    border.width: (root.val("hue") % Metis.palette.length) === index ? 3 : 0
                    border.color: Appearance.colors.colOnLayer3
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.set("hue", index);
                            if (root.row?.kind === "table") {
                                const t = Metis.tableOf(root.rowIndex);
                                t.columns.forEach(c => c.hue = index);
                                Metis.setTable(root.rowIndex, t);
                            }
                        }
                    }
                }
            }
        }

        Section { visible: root.hasCurve; text: Translation.tr("Line") }
        RowLayout {
            visible: root.hasCurve
            spacing: 4
            Repeater {
                model: [{ v: "solid", icon: "horizontal_rule" }, { v: "dashed", icon: "line_style" }, { v: "dotted", icon: "more_horiz" }]
                delegate: Chip {
                    required property var modelData
                    symbol: modelData.icon
                    active: root.val("lineStyle") === modelData.v
                    onClicked: root.set("lineStyle", modelData.v)
                }
            }
        }
        LabeledSlider {
            visible: root.hasCurve || (root.hasPoints && root.val("connect"))
            label: Translation.tr("Thickness")
            from: 1; to: 8; stepSize: 0.5
            value: root.val("lineWidth") ?? 2.5
            onMoved: root.set("lineWidth", value)
        }
        LabeledSlider {
            visible: root.hasCurve || root.hasPoints
            label: Translation.tr("Opacity")
            from: 0.1; to: 1; stepSize: 0.05
            value: root.val("opacity") ?? 1
            onMoved: root.set("opacity", value)
        }
        LabeledSlider {
            visible: root.hasRegion
            label: Translation.tr("Fill")
            from: 0; to: 1; stepSize: 0.05
            value: root.val("fillOpacity") ?? 0.25
            onMoved: root.set("fillOpacity", value)
        }

        Section { visible: root.hasPoints; text: Translation.tr("Points") }
        RowLayout {
            visible: root.hasPoints
            spacing: 4
            Repeater {
                model: [{ v: "dot", icon: "circle" }, { v: "open", icon: "radio_button_unchecked" }, { v: "cross", icon: "close" }]
                delegate: Chip {
                    required property var modelData
                    symbol: modelData.icon
                    active: root.val("pointStyle") === modelData.v
                    onClicked: root.set("pointStyle", modelData.v)
                }
            }
        }
        Toggle { visible: root.hasPoints; label: Translation.tr("Show coordinates"); prop: "showLabel" }
        Toggle { visible: root.hasPoints; label: Translation.tr("Connect with lines"); prop: "connect" }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Appearance.colors.colOutlineVariant; Layout.topMargin: 4 }
        Action { symbol: "content_copy"; label: Translation.tr("Duplicate"); onClicked: { Metis.duplicateRow(root.rowIndex); root.closeRequested(); } }
        Action {
            visible: (Metis.result?.rows?.[root.rowIndex]?.kind ?? "") === "y = f(x)"
            symbol: "table_rows"
            label: Translation.tr("Table of values")
            onClicked: { Metis.tableOfValues(root.rowIndex); root.closeRequested(); }
        }
        Action {
            visible: root.isPointList
            symbol: "table_chart"
            label: Translation.tr("Convert to table")
            onClicked: { Metis.pointsToTable(root.rowIndex); root.closeRequested(); }
        }
        Action { symbol: "delete"; label: Translation.tr("Delete"); danger: true; onClicked: { Metis.removeRow(root.rowIndex); root.closeRequested(); } }
    }

    component Section: StyledText {
        Layout.topMargin: 2
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colSubtext
    }
    component Chip: RippleButton {
        id: chip
        property string symbol
        property bool active
        implicitWidth: 40
        implicitHeight: 28
        buttonRadius: Appearance.rounding.full
        colBackground: chip.active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: chip.symbol
            iconSize: 18
            color: chip.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        }
    }
    component Toggle: RowLayout {
        id: tg
        property string label
        property string prop
        Layout.fillWidth: true
        StyledText {
            Layout.fillWidth: true
            text: tg.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer3
        }
        StyledSwitch {
            checked: !!root.val(tg.prop)
            onToggled: root.set(tg.prop, checked)
        }
    }
    component LabeledSlider: RowLayout {
        id: ls
        property string label
        property alias from: sl.from
        property alias to: sl.to
        property alias stepSize: sl.stepSize
        property alias value: sl.value
        signal moved()
        Layout.fillWidth: true
        StyledText {
            Layout.preferredWidth: 64
            text: ls.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer3
        }
        StyledSlider {
            id: sl
            Layout.fillWidth: true
            configuration: StyledSlider.Configuration.XS
            usePercentTooltip: false
            tooltipContent: String(parseFloat(value.toFixed(2)))
            onMoved: ls.moved()
        }
    }
    component Action: RippleButton {
        id: act
        property string symbol
        property string label
        property bool danger: false
        Layout.fillWidth: true
        implicitHeight: 30
        buttonRadius: Appearance.rounding.small
        contentItem: RowLayout {
            spacing: 8
            MaterialSymbol { Layout.leftMargin: 6; text: act.symbol; iconSize: 18; color: act.danger ? Appearance.colors.colError : Appearance.colors.colOnLayer3 }
            StyledText {
                Layout.fillWidth: true
                text: act.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: act.danger ? Appearance.colors.colError : Appearance.colors.colOnLayer3
            }
        }
    }
}
