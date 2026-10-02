pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import "MathFormat.js" as MathFormat

/**
 * Desmos-style table: the first column is x, every other column is plotted
 * against it. Headers can be names (x_1, y_1) or expressions of the first
 * column (x_1^2), which are computed. Regressions are one click away.
 */
Rectangle {
    id: tableItem
    required property var row
    required property var tab

    readonly property int index: row.index
    readonly property var info: Metis.result?.rows?.[index] ?? null
    readonly property bool isSelected: Metis.selected === index
    readonly property var table: { tableItem.row.tableJson; return Metis.tableOf(tableItem.index); }
    readonly property var columns: table.columns
    readonly property int dataRows: Math.max(0, ...columns.map((c, k) => (tableItem.info?.columns?.[k]?.computed ? 0 : c.cells.length)),
        ...(tableItem.info?.columns ?? []).map(c => c.computed ? c.values.length : 0))
    // always keep one blank row at the bottom for new data
    readonly property int nRows: {
        const lastFilled = columns.some(c => (c.cells[dataRows - 1] ?? "").trim().length > 0);
        return dataRows === 0 ? 1 : dataRows + (lastFilled ? 1 : 0);
    }
    property var focusCell: null // { c, r } to focus once the cells are recreated
    property bool showRegression: false
    property int regressionColumn: 1

    function isComputed(c) { return tableItem.info?.columns?.[c]?.computed ?? false; }
    function cellText(c, r) {
        if (isComputed(c)) {
            const v = tableItem.info?.columns?.[c]?.values?.[r];
            return v === null || v === undefined ? "" : Metis.num(v);
        }
        return tableItem.columns[c]?.cells?.[r] ?? "";
    }
    function focusAt(c, r) {
        if (c < 0 || c >= columns.length || r < 0) return;
        tableItem.focusCell = { c: c, r: r };
        const cell = cellsRepeater.itemAt(c)?.cell(r);
        if (cell) {
            cell.forceActiveFocus();
            cell.cursorPosition = cell.text.length;
            tableItem.focusCell = null;
        }
    }
    function focusEditor() { tableItem.focusAt(0, Math.max(0, nRows - 1)); }

    implicitHeight: col.implicitHeight + 16
    radius: Appearance.rounding.small
    color: isSelected ? Appearance.colors.colLayer2 : rowHover.hovered ? Appearance.colors.colLayer1Hover : "transparent"
    HoverHandler { id: rowHover }

    Rectangle {
        visible: tableItem.isSelected
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 6 }
        width: 3
        radius: 2
        color: Metis.colorOf(tableItem.row.hue)
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10 }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            MaterialSymbol {
                text: "table_chart"
                iconSize: 18
                color: tableItem.row.hidden ? Appearance.colors.colSubtext : Metis.colorOf(tableItem.row.hue)
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        if (event.button === Qt.RightButton) tableItem.tab.openStyle(tableItem.index, tableItem);
                        else Metis.setProp(tableItem.index, "hidden", !tableItem.row.hidden);
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: tableItem.info?.kind ?? Translation.tr("table")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
            TinyButton { symbol: "timeline"; tip: Translation.tr("Regression"); toggled: tableItem.showRegression; onClicked: tableItem.showRegression = !tableItem.showRegression }
            TinyButton { symbol: "fit_screen"; tip: Translation.tr("Zoom to fit"); onClicked: Metis.zoomFit() }
            TinyButton { symbol: "palette"; tip: Translation.tr("Style"); onClicked: tableItem.tab.openStyle(tableItem.index, tableItem) }
            TinyButton { symbol: "close"; tip: Translation.tr("Delete table"); onClicked: Metis.removeRow(tableItem.index) }
        }

        // ---- the grid
        Flickable {
            id: flick
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight
            contentWidth: grid.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            readonly property real colWidth: Math.max(64, (width - 30) / Math.max(1, tableItem.columns.length))

            Row {
                id: grid
                spacing: 0
                Repeater {
                    id: cellsRepeater
                    model: tableItem.columns.length
                    delegate: Column {
                        id: column
                        required property int index
                        readonly property int c: index
                        readonly property var colInfo: tableItem.info?.columns?.[c] ?? null
                        readonly property bool computed: colInfo?.computed ?? false
                        function cell(r) { return cellRepeater.itemAt(r)?.input ?? null; }
                        width: flick.colWidth

                        // header
                        Rectangle {
                            width: parent.width
                            height: 30
                            color: Appearance.colors.colLayer3
                            radius: 0
                            border.width: 0
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 2
                                spacing: 4
                                Rectangle {
                                    visible: column.c > 0
                                    implicitWidth: 12
                                    implicitHeight: 12
                                    radius: 6
                                    color: Metis.colorOf(tableItem.columns[column.c]?.hue ?? tableItem.row.hue)
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Metis.setColumnHue(tableItem.index, column.c, (tableItem.columns[column.c]?.hue ?? tableItem.row.hue) + 1)
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: 20
                                    TextInput {
                                        id: headerInput
                                        anchors.fill: parent
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: tableItem.columns[column.c]?.header ?? ""
                                        opacity: activeFocus ? 1 : 0
                                        clip: true
                                        selectByMouse: true
                                        font.family: Appearance.font.family.monospace
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnLayer3
                                        onTextEdited: Metis.setHeader(tableItem.index, column.c, text)
                                        onActiveFocusChanged: if (activeFocus) Metis.selected = tableItem.index
                                        Keys.onReturnPressed: tableItem.focusAt(column.c, 0)
                                    }
                                    StyledText {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        visible: !headerInput.activeFocus
                                        textFormat: Text.RichText
                                        text: MathFormat.format(tableItem.columns[column.c]?.header ?? "")
                                        elide: Text.ElideRight
                                        font.family: Appearance.font.family.reading
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: column.colInfo?.error ? Appearance.colors.colError : Appearance.colors.colOnLayer3
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.IBeamCursor
                                            onClicked: headerInput.forceActiveFocus()
                                        }
                                    }
                                }
                                RippleButton {
                                    visible: column.c >= 2 && headerHover.hovered
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    buttonRadius: Appearance.rounding.full
                                    onClicked: Metis.removeColumn(tableItem.index, column.c)
                                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 12; color: Appearance.colors.colSubtext }
                                }
                            }
                            HoverHandler { id: headerHover }
                        }

                        // cells
                        Repeater {
                            id: cellRepeater
                            model: tableItem.nRows
                            delegate: Rectangle {
                                id: cellBox
                                required property int index
                                readonly property int r: index
                                property alias input: cellInput
                                width: column.width
                                height: 28
                                color: cellInput.activeFocus ? Appearance.colors.colLayer1 : "transparent"
                                border.width: 1
                                border.color: cellInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                                TextInput {
                                    id: cellInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 4
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    selectByMouse: true
                                    readOnly: column.computed
                                    text: tableItem.cellText(column.c, cellBox.r)
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: column.computed ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                                    onTextEdited: {
                                        tableItem.focusCell = { c: column.c, r: cellBox.r };
                                        Metis.setCell(tableItem.index, column.c, cellBox.r, text);
                                    }
                                    onActiveFocusChanged: if (activeFocus) Metis.selected = tableItem.index
                                    Keys.onReturnPressed: tableItem.focusAt(column.c, cellBox.r + 1)
                                    Keys.onEnterPressed: tableItem.focusAt(column.c, cellBox.r + 1)
                                    Keys.onDownPressed: tableItem.focusAt(column.c, cellBox.r + 1)
                                    Keys.onUpPressed: {
                                        if (cellBox.r > 0) tableItem.focusAt(column.c, cellBox.r - 1);
                                        else tableItem.tab.focusRowEditor(tableItem.index - 1);
                                    }
                                    Keys.onTabPressed: tableItem.focusAt(column.c + 1 < tableItem.columns.length ? column.c + 1 : 0,
                                        column.c + 1 < tableItem.columns.length ? cellBox.r : cellBox.r + 1)
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Left && cellInput.cursorPosition === 0 && column.c > 0) {
                                            tableItem.focusAt(column.c - 1, cellBox.r);
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Right && cellInput.cursorPosition === cellInput.text.length && column.c + 1 < tableItem.columns.length) {
                                            tableItem.focusAt(column.c + 1, cellBox.r);
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Escape) {
                                            tableItem.tab.focusGraph();
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.ControlModifier)) {
                                            Metis.removeTableRow(tableItem.index, cellBox.r);
                                            tableItem.focusAt(column.c, Math.max(0, cellBox.r - 1));
                                            event.accepted = true;
                                        }
                                    }
                                }
                                Component.onCompleted: {
                                    const f = tableItem.focusCell;
                                    if (f && f.c === column.c && f.r === cellBox.r) {
                                        tableItem.focusCell = null;
                                        cellInput.forceActiveFocus();
                                        cellInput.cursorPosition = cellInput.text.length;
                                    }
                                }
                            }
                        }
                    }
                }
                // add column
                RippleButton {
                    width: 28
                    height: 30
                    buttonRadius: Appearance.rounding.small
                    onClicked: Metis.addColumn(tableItem.index)
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "add"; iconSize: 16; color: Appearance.colors.colSubtext }
                    StyledToolTip { text: Translation.tr("Add column") }
                }
            }
        }

        // column errors
        StyledText {
            Layout.fillWidth: true
            visible: text.length > 0
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colError
            text: (tableItem.info?.columns ?? []).filter(c => c.error).map(c => `${c.name}: ${c.error}`).join("\n")
        }

        // ---- regression chooser
        ColumnLayout {
            visible: tableItem.showRegression
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                visible: tableItem.columns.length > 2
                spacing: 4
                StyledText { text: Translation.tr("fit"); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                Repeater {
                    model: Math.max(0, tableItem.columns.length - 1)
                    delegate: Chip {
                        required property int index
                        text: tableItem.columns[index + 1]?.header ?? ""
                        active: tableItem.regressionColumn === index + 1
                        onClicked: tableItem.regressionColumn = index + 1
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: Metis.regressionModels
                    delegate: Chip {
                        required property var modelData
                        text: modelData.name
                        onClicked: {
                            Metis.addRegression(tableItem.index, modelData.id, Math.min(tableItem.regressionColumn, tableItem.columns.length - 1));
                            tableItem.showRegression = false;
                        }
                        StyledToolTip { text: modelData.tex }
                    }
                }
            }
        }
    }

    component TinyButton: RippleButton {
        id: tb
        property string symbol
        property string tip
        implicitWidth: 24
        implicitHeight: 24
        buttonRadius: Appearance.rounding.full
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: tb.symbol
            iconSize: 15
            color: tb.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
        }
        StyledToolTip { text: tb.tip }
    }
    component Chip: RippleButton {
        id: chip
        property bool active
        implicitHeight: 24
        implicitWidth: chipText.implicitWidth + 14
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
}
