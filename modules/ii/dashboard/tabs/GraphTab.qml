pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.ii.dashboard.tabs.graph

/**
 * Desmos-style graphing calculator. The math and rasterization run in the
 * `metis` backend (see services/Metis.qml); the graph/ components only draw
 * the vector data it returns, so it stays smooth while panning and zooming.
 */
Item {
    id: root

    property int focusRow: -1 // row whose editor should grab focus once created
    property bool showHelp: false
    property bool showAddMenu: false
    readonly property alias graph: graphView
    property var lastEditor: null // expression editor the keypad types into
    property bool showKeypad: false

    function typeKey(text, back) {
        const ed = root.lastEditor;
        if (!ed) return;
        ed.forceActiveFocus();
        if (back) {
            if (ed.selectedText.length > 0) ed.remove(ed.selectionStart, ed.selectionEnd);
            else if (ed.cursorPosition > 0) ed.remove(ed.cursorPosition - 1, ed.cursorPosition);
            return;
        }
        if (ed.selectedText.length > 0) ed.remove(ed.selectionStart, ed.selectionEnd);
        ed.insert(ed.cursorPosition, text);
    }

    Component.onCompleted: Metis.acquire()
    Component.onDestruction: Metis.release()

    function focusRowEditor(i) {
        if (i < 0 || i >= Metis.rows.count) return;
        const item = list.itemAtIndex(i);
        if (item && item.content) item.content.focusEditor();
        else root.focusRow = i;
        list.positionViewAtIndex(i, ListView.Contain);
    }
    function focusGraph() { graphView.focusPaper(); }
    function openStyle(i, anchor) {
        const p = anchor.mapToItem(root, anchor.width, 0);
        styleMenu.rowIndex = i;
        styleMenu.x = Math.min(root.width - styleMenu.width - 8, p.x + 8);
        styleMenu.y = Math.max(8, Math.min(root.height - styleMenu.implicitHeight - 8, p.y));
        styleMenu.visible = true;
        Metis.selected = i;
    }
    function add(kind) {
        root.showAddMenu = false;
        const at = Metis.rows.count;
        if (kind === "table") Metis.addTable(at);
        else Metis.insertRow(at, kind === "note" ? "\" " : "");
        root.focusRowEditor(at);
    }

    // undo / redo when no text field wants the keys
    Shortcut { sequences: [StandardKey.Undo]; enabled: root.visible; onActivated: Metis.undo() }
    Shortcut { sequences: [StandardKey.Redo, "Ctrl+Y"]; enabled: root.visible; onActivated: Metis.redo() }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // ================================================= expression list
        Rectangle {
            id: listPanel
            Layout.preferredWidth: Math.min(350, Math.max(260, root.width * 0.37))
            Layout.fillHeight: true
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.large
            border.width: Appearance.sizes.borderWidth > 1 ? Appearance.sizes.borderWidth : 0
            border.color: Appearance.colors.colLayer0Border
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                anchors.bottomMargin: root.showKeypad ? keypad.implicitHeight + 16 : 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    MaterialSymbol {
                        text: "function"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: Translation.tr("Graph")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    HeaderButton { symbol: "undo"; tip: Translation.tr("Undo (Ctrl+Z)"); enabled: Metis.canUndo; onClicked: Metis.undo() }
                    HeaderButton { symbol: "redo"; tip: Translation.tr("Redo (Ctrl+Shift+Z)"); enabled: Metis.canRedo; onClicked: Metis.redo() }
                    RippleButton {
                        implicitWidth: 42
                        implicitHeight: 26
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colSecondaryContainer
                        onClicked: Metis.deg = !Metis.deg
                        contentItem: StyledText {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: Metis.deg ? "DEG" : "RAD"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        StyledToolTip { text: Translation.tr("Angle unit for trig functions") }
                    }
                    HeaderButton { symbol: "keyboard"; tip: Translation.tr("Math keypad"); toggled: root.showKeypad; onClicked: root.showKeypad = !root.showKeypad }
                    HeaderButton { symbol: "help"; tip: Translation.tr("Syntax help"); toggled: root.showHelp; onClicked: root.showHelp = !root.showHelp }
                    HeaderButton { symbol: "add"; tip: Translation.tr("Add, examples, saved graphs"); toggled: root.showAddMenu; onClicked: root.showAddMenu = !root.showAddMenu }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: Metis.rows
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 2000
                    ScrollBar.vertical: StyledScrollBar {}
                    delegate: Item {
                        id: wrapper
                        required property int index
                        required property string kind
                        required property string text
                        required property string tableJson
                        required property int hue
                        required property bool hidden
                        required property real min
                        required property real max
                        required property real step
                        required property bool playing
                        required property real speed
                        required property string loopMode
                        readonly property Item content: loader.item
                        width: ListView.view.width
                        implicitHeight: loader.item?.implicitHeight ?? 0
                        Loader {
                            id: loader
                            width: parent.width
                            sourceComponent: wrapper.kind === "table" ? tableComponent : exprComponent
                            onLoaded: {
                                if (root.focusRow === wrapper.index) {
                                    root.focusRow = -1;
                                    item.focusEditor();
                                }
                            }
                        }
                        Component {
                            id: exprComponent
                            ExpressionRow { row: wrapper; tab: root; width: wrapper.width }
                        }
                        Component {
                            id: tableComponent
                            TableRow { row: wrapper; tab: root; width: wrapper.width }
                        }
                    }
                    footer: Item {
                        z: 2
                        width: list.width
                        height: 44
                        RowLayout {
                            anchors.fill: parent
                            anchors.topMargin: 4
                            spacing: 4
                            FooterButton { symbol: "add"; label: Translation.tr("Expression"); onClicked: root.add("expr") }
                            FooterButton { symbol: "table_chart"; label: Translation.tr("Table"); onClicked: root.add("table") }
                            FooterButton { symbol: "notes"; label: Translation.tr("Note"); onClicked: root.add("note") }
                        }
                    }
                }
            }

            // add menu (see below) and keypad
            Keypad {
                id: keypad
                visible: root.showKeypad
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                onKey: (text, back) => root.typeKey(text, back)
            }

        }

        // ================================================= graph
        GraphView {
            id: graphView
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    // ---- click-away catcher for the style and add menus
    MouseArea {
        anchors.fill: parent
        visible: styleMenu.visible || root.showAddMenu
        z: 50
        onPressed: event => {
            styleMenu.visible = false;
            root.showAddMenu = false;
            event.accepted = true;
        }
    }
    GraphMenu {
        visible: root.showAddMenu
        x: listPanel.width - width - 10
        y: 44
        maxHeight: listPanel.height - 56
        z: 51
        onAddRequested: kind => root.add(kind)
        onCloseRequested: root.showAddMenu = false
    }
    StyleMenu {
        id: styleMenu
        visible: false
        z: 51
        onCloseRequested: visible = false
    }

    // ---- syntax help
    Rectangle {
        visible: root.showHelp
        z: 40
        x: listPanel.width + 20
        y: 10
        width: Math.min(root.width - listPanel.width - 80, 480)
        height: Math.min(root.height - 20, helpText.implicitHeight + 24)
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer3Base
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        clip: true
        StyledFlickable {
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: helpText.implicitHeight
            StyledText {
                id: helpText
                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer3
                text: [
                    "<b>Graphs</b>",
                    "y = x^2 − 3 · x = sin(y) · x^2 + y^2 = 25 · r = 1 + cos θ",
                    "(cos t, 2 sin t) parametric · (1, 2) point · y > x^2 region",
                    "y = x^2 {x > 0} restriction · {x < 0: −x, x^2} piecewise",
                    "<b>Movable points</b>",
                    "a = 1, b = 2, then (a, b): drag the point to change the sliders. (3, 4) literals can be dragged too.",
                    "<b>Tables</b>",
                    "+ → Table. Type x and y values; a header like x_1^2 is computed. The regression button fits linear, quadratic, exponential, logistic, sinusoidal… (two points give the exact line).",
                    "<b>Definitions</b>",
                    "f(x) = x sin x · f'(x) · d/dx x^3 · a = 2 (unknown letters become sliders when you press Enter)",
                    "<b>Math</b>",
                    "sum(n^2, n, 1, 10) · int(e^-t^2, t, 0, x) · nCr(5,2) · 5! · log_2(8) · |x|",
                    "L = [1...10] · L[L > 3] · mean(L) · [n^2 for n = [1...5]] · y_1 ~ m x_1 + b",
                    "<b>Graph</b>",
                    "drag paper to pan · scroll to zoom (Shift/Ctrl: one axis when unlocked) · press on a curve and drag to trace it · click a point for its coordinates, then + to add it as an expression or table row · right-click clears",
                    "gray dots: roots, extrema and intersections of the selected curve (hover them)",
                    "<b>Rows</b>",
                    "Enter: new row · ↑/↓: move · Alt+↑/↓: reorder · Backspace on empty row: delete · Ctrl+Z / Ctrl+Shift+Z: undo/redo · click a dot to hide, right-click it (or the palette button) for style",
                ].join("<br>")
            }
        }
    }

    component HeaderButton: RippleButton {
        id: hb
        property string symbol
        property string tip
        implicitWidth: 28
        implicitHeight: 28
        buttonRadius: Appearance.rounding.full
        opacity: enabled ? 1 : 0.4
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: hb.symbol
            iconSize: 18
            color: hb.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        }
        StyledToolTip { text: hb.tip }
    }
    component FooterButton: RippleButton {
        id: fb
        property string symbol
        property string label
        Layout.fillWidth: true
        implicitHeight: 34
        buttonRadius: Appearance.rounding.small
        contentItem: RowLayout {
            spacing: 4
            Item { Layout.fillWidth: true }
            MaterialSymbol { text: fb.symbol; iconSize: 16; color: Appearance.colors.colSubtext }
            StyledText { text: fb.label; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
            Item { Layout.fillWidth: true }
        }
    }
}
