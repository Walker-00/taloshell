pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Graph paper settings (the Desmos wrench menu): grid kinds, axes, labels,
 * explicit bounds and angle mode.
 */
Rectangle {
    id: root
    signal closeRequested()

    implicitWidth: 270
    implicitHeight: col.implicitHeight + 24
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer3Base
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant

    // swallow clicks so they don't reach the graph
    MouseArea { anchors.fill: parent }

    function fmt(v) { return String(parseFloat(v.toPrecision(5))); }
    function refreshBounds() {
        xmin.text = fmt(Metis.cx - Metis.width / 2 * Metis.sx);
        xmax.text = fmt(Metis.cx + Metis.width / 2 * Metis.sx);
        ymin.text = fmt(Metis.cy - Metis.height / 2 * Metis.sy);
        ymax.text = fmt(Metis.cy + Metis.height / 2 * Metis.sy);
    }
    onVisibleChanged: if (visible) refreshBounds()

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Graph settings")
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer3
            }
            RippleButton {
                implicitWidth: 24
                implicitHeight: 24
                buttonRadius: Appearance.rounding.full
                onClicked: root.closeRequested()
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 16; color: Appearance.colors.colOnLayer3 }
            }
        }

        Toggle { label: Translation.tr("Grid"); key: "grid" }
        Toggle { label: Translation.tr("Minor gridlines"); key: "minorGrid"; enabled: Metis.settings.grid }
        Toggle { label: Translation.tr("Polar grid"); key: "polarGrid" }
        Toggle { label: Translation.tr("Axes"); key: "axes" }
        Toggle { label: Translation.tr("Axis numbers"); key: "axisNumbers" }
        Toggle { label: Translation.tr("Lock square aspect"); key: "lockSquare" }
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Angles")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer3
            }
            Repeater {
                model: [{ v: false, t: "RAD" }, { v: true, t: "DEG" }]
                delegate: Chip {
                    required property var modelData
                    text: modelData.t
                    active: Metis.deg === modelData.v
                    onClicked: Metis.deg = modelData.v
                }
            }
        }

        StyledText {
            Layout.topMargin: 6
            text: Translation.tr("Axis labels")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Field {
                placeholder: "x"
                text: Metis.settings.xLabel
                onCommitted: t => Metis.setSetting("xLabel", t)
            }
            Field {
                placeholder: "y"
                text: Metis.settings.yLabel
                onCommitted: t => Metis.setSetting("yLabel", t)
            }
        }

        StyledText {
            Layout.topMargin: 6
            text: Translation.tr("Bounds")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 6
            rowSpacing: 4
            Label { text: "x" }
            Field { id: xmin; onCommitted: root.apply() }
            Label { text: "…" }
            Field { id: xmax; onCommitted: root.apply() }
            Label { text: "y" }
            Field { id: ymin; onCommitted: root.apply() }
            Label { text: "…" }
            Field { id: ymax; onCommitted: root.apply() }
        }
    }

    function apply() {
        const v = [xmin.text, xmax.text, ymin.text, ymax.text].map(parseFloat);
        if (v.every(isFinite) && Metis.setBounds(v[0], v[1], v[2], v[3])) return;
        root.refreshBounds();
    }
    Connections {
        target: Metis
        enabled: root.visible
        function onChanged() { if (!xmin.activeFocus && !xmax.activeFocus && !ymin.activeFocus && !ymax.activeFocus) root.refreshBounds(); }
    }

    component Toggle: RowLayout {
        id: tg
        property string label
        property string key
        Layout.fillWidth: true
        opacity: enabled ? 1 : 0.5
        StyledText {
            Layout.fillWidth: true
            text: tg.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer3
        }
        StyledSwitch {
            checked: !!Metis.settings[tg.key]
            onToggled: Metis.setSetting(tg.key, checked)
        }
    }
    component Label: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }
    component Chip: RippleButton {
        id: chip
        property bool active
        implicitHeight: 24
        implicitWidth: chipText.implicitWidth + 16
        buttonRadius: Appearance.rounding.full
        colBackground: chip.active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
        contentItem: StyledText {
            id: chipText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: chip.text
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: chip.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        }
    }
    component Field: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder
        signal committed(string text)
        Layout.fillWidth: true
        implicitHeight: 26
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        border.width: input.activeFocus ? 1 : 0
        border.color: Appearance.colors.colPrimary
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            selectByMouse: true
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer2
            onEditingFinished: field.committed(text)
            StyledText {
                visible: input.text.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: field.placeholder
                font: input.font
                color: Appearance.colors.colSubtext
            }
        }
    }
}
