pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "MathFormat.js" as MathFormat

/**
 * One expression row: typeset display (raw text while editing), results,
 * errors, sliders with their settings, and the colour/visibility dot.
 */
Rectangle {
    id: rowItem
    required property var row // delegate wrapper exposing the model roles + index
    required property var tab // GraphTab

    readonly property int index: row.index
    readonly property var info: Metis.result?.rows?.[index] ?? null
    readonly property bool isSelected: Metis.selected === index
    readonly property color swatch: Metis.colorOf(row.hue)
    readonly property bool isNote: /^\s*["#]/.test(row.text)
    readonly property bool isSlider: info?.type === "slider"
    property string committed: row.text
    property bool showSliderSettings: false

    function focusEditor() {
        editor.forceActiveFocus();
        editor.cursorPosition = editor.text.length;
    }
    function commit() {
        if (editor.text === rowItem.committed) return 0;
        rowItem.committed = editor.text;
        return Metis.commitRow(index);
    }

    implicitHeight: body.implicitHeight + 14
    radius: Appearance.rounding.small
    color: isSelected ? Appearance.colors.colLayer2 : rowHover.hovered ? Appearance.colors.colLayer1Hover : "transparent"

    HoverHandler { id: rowHover }

    Rectangle {
        visible: rowItem.isSelected
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 6 }
        width: 3
        radius: 2
        color: rowItem.swatch
    }

    RowLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7; leftMargin: 10 }
        spacing: 8

        // colour / visibility toggle (right-click: style menu)
        Item {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            implicitWidth: 18
            implicitHeight: 18
            Rectangle {
                anchors.fill: parent
                radius: 9
                visible: rowItem.row.text.trim().length > 0 && !rowItem.isNote
                readonly property bool plotted: rowItem.info?.plotted ?? false
                color: plotted && !rowItem.row.hidden ? rowItem.swatch : "transparent"
                border.width: 2
                border.color: rowItem.info?.type === "error" ? Appearance.colors.colError : plotted ? rowItem.swatch : Appearance.colors.colOutlineVariant
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: rowItem.info?.type === "error"
                    text: "priority_high"
                    iconSize: 12
                    color: Appearance.colors.colError
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        if (event.button === Qt.RightButton) rowItem.tab.openStyle(rowItem.index, rowItem);
                        else Metis.setProp(rowItem.index, "hidden", !rowItem.row.hidden);
                    }
                    onPressAndHold: rowItem.tab.openStyle(rowItem.index, rowItem)
                }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: rowItem.isNote
                text: "notes"
                iconSize: 16
                color: Appearance.colors.colSubtext
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Item {
                Layout.fillWidth: true
                implicitHeight: editor.activeFocus || editor.text.length === 0 ? editor.implicitHeight : Math.max(pretty.implicitHeight, 18)

                TextEdit {
                    id: editor
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    text: rowItem.row.text
                    wrapMode: TextEdit.WrapAnywhere
                    selectByMouse: true
                    opacity: activeFocus || text.length === 0 ? 1 : 0
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: rowItem.row.hidden ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                    selectionColor: Appearance.colors.colSecondaryContainer
                    selectedTextColor: Appearance.colors.colOnSecondaryContainer

                    StyledText {
                        visible: editor.text.length === 0
                        text: Translation.tr("Expression, e.g. y = sin x")
                        font: editor.font
                        color: Appearance.colors.colSubtext
                        opacity: 0.7
                    }

                    onTextChanged: {
                        if (!activeFocus) return;
                        if (text.includes("\n")) {
                            // pasted several lines: one row per line
                            const lines = text.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                            const i = rowItem.index;
                            Metis.setText(i, lines[0] ?? "");
                            for (let k = 1; k < lines.length; k++) Metis.insertRow(i + k, lines[k]);
                            editor.text = lines[0] ?? "";
                            rowItem.tab.focusRowEditor(i + Math.max(0, lines.length - 1));
                            return;
                        }
                        Metis.setText(rowItem.index, text);
                    }
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            Metis.selected = rowItem.index;
                            rowItem.tab.lastEditor = editor;
                        } else {
                            rowItem.commit();
                        }
                    }
                    function newRowAfter() {
                        const i = rowItem.index;
                        const added = rowItem.commit();
                        const at = i + 1 + added;
                        if (editor.text.trim().length > 0 && !(at < Metis.rows.count && Metis.rows.get(at).kind === "expr" && Metis.rows.get(at).text.trim().length === 0))
                            Metis.insertRow(at, "");
                        rowItem.tab.focusRowEditor(at);
                    }
                    Keys.onReturnPressed: event => { editor.newRowAfter(); event.accepted = true; }
                    Keys.onEnterPressed: event => { editor.newRowAfter(); event.accepted = true; }
                    Keys.onUpPressed: event => {
                        if (rowItem.index > 0) rowItem.tab.focusRowEditor(rowItem.index - 1);
                        event.accepted = true;
                    }
                    Keys.onDownPressed: event => {
                        if (rowItem.index + 1 < Metis.rows.count) rowItem.tab.focusRowEditor(rowItem.index + 1);
                        event.accepted = true;
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Backspace && editor.text.length === 0 && Metis.rows.count > 1) {
                            const i = rowItem.index;
                            Metis.removeRow(i);
                            rowItem.tab.focusRowEditor(Math.max(0, i - 1));
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            rowItem.tab.focusGraph();
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.AltModifier) && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                            Metis.moveRow(rowItem.index, event.key === Qt.Key_Up ? -1 : 1);
                            rowItem.tab.focusRowEditor(Metis.selected);
                            event.accepted = true;
                        }
                    }
                }

                // typeset display while not editing
                StyledText {
                    id: pretty
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    visible: !editor.activeFocus && editor.text.length > 0
                    textFormat: rowItem.isNote ? Text.PlainText : Text.RichText
                    text: rowItem.isNote ? rowItem.row.text.replace(/^\s*["#]\s?/, "") : MathFormat.format(rowItem.row.text)
                    wrapMode: Text.Wrap
                    font.family: rowItem.isNote ? Appearance.font.family.main : Appearance.font.family.reading
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: rowItem.row.hidden ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: rowItem.focusEditor()
                    }
                }
            }

            // result / error / derivative line
            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                horizontalAlignment: rowItem.info?.type === "value" ? Text.AlignRight : Text.AlignLeft
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 4
                elide: Text.ElideRight
                font.family: rowItem.info?.type === "error" ? Appearance.font.family.main : Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: rowItem.info?.type === "error" ? Appearance.colors.colError
                    : rowItem.info?.type === "value" || rowItem.info?.type === "regression" ? Appearance.colors.colPrimary
                    : Appearance.colors.colSubtext
                text: {
                    const i = rowItem.info;
                    if (!i || rowItem.row.text.trim().length === 0 || rowItem.isNote) return "";
                    const lines = [];
                    if (i.type === "error") {
                        lines.push(i.text);
                        if ((i.undefined ?? []).length > 0)
                            lines.push(Translation.tr("Press Enter to add slider: %1").arg(i.undefined.join(", ")));
                    } else if (i.type === "value" || i.type === "regression") {
                        lines.push(i.type === "value" ? `= ${i.text}` : i.text);
                    }
                    if (i.symbolic) lines.push(`= ${i.symbolic}`);
                    if (rowItem.isSelected && i.kind && i.type !== "error") lines.push(i.kind);
                    if (rowItem.isSelected && i.drag) lines.push(Translation.tr("drag the point on the graph to move it"));
                    return lines.join("\n");
                }
            }

            // parameter range for parametric / polar curves: 0 ≤ t ≤ 2π
            RowLayout {
                visible: !!rowItem.info?.range
                spacing: 4
                RangeInput {
                    id: rangeFrom
                    value: rowItem.info?.range?.from ?? 0
                    onCommitted: t => Metis.setParamRange(rowItem.index, rowItem.info.range.var, t, rangeTo.text)
                }
                StyledText {
                    text: `≤ ${rowItem.info?.range?.var ?? "t"} ≤`
                    font.family: Appearance.font.family.reading
                    font.italic: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                RangeInput {
                    id: rangeTo
                    value: rowItem.info?.range?.to ?? 1
                    onCommitted: t => Metis.setParamRange(rowItem.index, rowItem.info.range.var, rangeFrom.text, t)
                }
            }

            // slider
            RowLayout {
                visible: rowItem.isSlider
                Layout.fillWidth: true
                spacing: 4
                RippleButton {
                    implicitWidth: 26
                    implicitHeight: 26
                    buttonRadius: Appearance.rounding.full
                    colBackground: rowItem.row.playing ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                    onClicked: Metis.togglePlay(rowItem.index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: rowItem.row.playing ? "pause" : "play_arrow"
                        iconSize: 16
                        color: rowItem.row.playing ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    }
                }
                BoundInput {
                    value: rowItem.row.min
                    onCommitted: v => { if (v < rowItem.row.max) Metis.setProp(rowItem.index, "min", v); }
                }
                StyledSlider {
                    Layout.fillWidth: true
                    configuration: StyledSlider.Configuration.XS
                    from: rowItem.row.min
                    to: rowItem.row.max
                    stepSize: rowItem.row.step > 0 ? rowItem.row.step : 0
                    usePercentTooltip: false
                    tooltipContent: String(parseFloat(value.toPrecision(6)))
                    value: rowItem.info?.value ?? 0
                    onMoved: Metis.setSliderValue(rowItem.index, value)
                }
                BoundInput {
                    value: rowItem.row.max
                    onCommitted: v => { if (v > rowItem.row.min) Metis.setProp(rowItem.index, "max", v); }
                }
                RippleButton {
                    implicitWidth: 24
                    implicitHeight: 24
                    buttonRadius: Appearance.rounding.full
                    toggled: rowItem.showSliderSettings
                    onClicked: rowItem.showSliderSettings = !rowItem.showSliderSettings
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "tune"
                        iconSize: 15
                        color: rowItem.showSliderSettings ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    }
                    StyledToolTip { text: Translation.tr("Slider settings") }
                }
            }
            // slider settings: step, speed, repeat mode
            ColumnLayout {
                visible: rowItem.isSlider && rowItem.showSliderSettings
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    spacing: 6
                    StyledText { text: Translation.tr("Step"); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                    BoundInput {
                        Layout.preferredWidth: 44
                        value: rowItem.row.step
                        onCommitted: v => { if (v >= 0) Metis.setProp(rowItem.index, "step", v); }
                    }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [0.25, 0.5, 1, 2, 4]
                        delegate: Chip {
                            required property real modelData
                            text: `${modelData === 0.25 ? "¼" : modelData === 0.5 ? "½" : modelData}×`
                            active: rowItem.row.speed === modelData
                            onClicked: Metis.setProp(rowItem.index, "speed", modelData)
                        }
                    }
                }
                RowLayout {
                    spacing: 4
                    Repeater {
                        model: [
                            { v: "bounce", t: Translation.tr("⇄ back and forth") },
                            { v: "loop", t: Translation.tr("↻ loop") },
                            { v: "once", t: Translation.tr("→ once") },
                        ]
                        delegate: Chip {
                            required property var modelData
                            text: modelData.t
                            active: rowItem.row.loopMode === modelData.v
                            onClicked: Metis.setProp(rowItem.index, "loopMode", modelData.v)
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 0
            visible: (rowHover.hovered || rowItem.isSelected) && rowItem.row.text.length > 0
            SmallButton {
                symbol: "close"
                tip: Translation.tr("Delete")
                onClicked: Metis.removeRow(rowItem.index)
            }
            SmallButton {
                visible: !rowItem.isNote
                symbol: "palette"
                tip: Translation.tr("Style")
                onClicked: rowItem.tab.openStyle(rowItem.index, rowItem)
            }
        }
    }

    component SmallButton: RippleButton {
        id: sb
        property string symbol
        property string tip
        implicitWidth: 22
        implicitHeight: 22
        buttonRadius: Appearance.rounding.full
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: sb.symbol
            iconSize: 14
            color: Appearance.colors.colSubtext
        }
        StyledToolTip { text: sb.tip }
    }
    component Chip: RippleButton {
        id: chip
        property bool active
        implicitHeight: 22
        implicitWidth: chipText.implicitWidth + 12
        buttonRadius: Appearance.rounding.full
        colBackground: chip.active ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
        contentItem: StyledText {
            id: chipText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: chip.text
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: chip.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
        }
    }
    /// Editable range end: shows the number, accepts expressions like 2pi.
    component RangeInput: Rectangle {
        id: ri
        property real value
        property alias text: riInput.text
        signal committed(string text)
        implicitWidth: Math.max(40, riInput.contentWidth + 14)
        implicitHeight: 22
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.width: riInput.activeFocus ? 1 : 0
        border.color: Appearance.colors.colPrimary
        TextInput {
            id: riInput
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            selectByMouse: true
            text: String(parseFloat(ri.value.toPrecision(5)))
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer1
            onEditingFinished: ri.committed(text)
        }
    }
    /// Small editable number (slider bounds, step).
    component BoundInput: TextInput {
        id: bound
        property real value
        signal committed(real v)
        text: String(parseFloat(value.toPrecision(6)))
        Layout.preferredWidth: Math.max(22, contentWidth + 4)
        horizontalAlignment: Text.AlignHCenter
        selectByMouse: true
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: Appearance.colors.colSubtext
        onEditingFinished: {
            const v = parseFloat(text);
            if (isFinite(v)) bound.committed(v);
            text = Qt.binding(() => String(parseFloat(bound.value.toPrecision(6))));
        }
    }
}
