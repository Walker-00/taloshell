pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

FocusScope {
    id: root
    readonly property var cfg: Config.options.launcher
    readonly property var results: TalosLauncher.results
    property int currentIndex: 0
    readonly property var currentItem: results[currentIndex] ?? null
    readonly property bool gridMode: ["wallpapers", "emoji"].includes(TalosLauncher.mode)
        || (cfg.style === "grid" && (TalosLauncher.mode === "apps" || (TalosLauncher.mode === "all" && TalosLauncher.text.length === 0)))
    readonly property int columns: TalosLauncher.mode === "emoji" ? 8 : TalosLauncher.mode === "wallpapers" ? 4 : cfg.gridColumns
    readonly property bool compact: cfg.style === "compact"
    property bool previewVisible: cfg.showPreview && !compact

    onResultsChanged: currentIndex = Math.min(currentIndex, Math.max(0, results.length - 1))
    Connections {
        target: TalosLauncher
        function onQueryChanged() { root.currentIndex = 0; }
        function onForcedModeChanged() { root.currentIndex = 0; }
    }

    function move(delta) {
        if (root.results.length === 0) return;
        root.currentIndex = Math.max(0, Math.min(root.results.length - 1, root.currentIndex + delta));
        const view = root.gridMode ? grid : list;
        view.positionViewAtIndex(root.currentIndex, ListView.Contain);
    }

    function focusSearch() {
        searchField.forceActiveFocus();
        searchField.cursorPosition = searchField.text.length;
    }

    Component.onCompleted: focusSearch()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ===== Search =====
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 54
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1
            border.width: searchField.activeFocus ? 2 : 0
            border.color: Appearance.colors.colPrimary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 12
                spacing: 8

                RippleButton {
                    id: modeButton
                    implicitHeight: 38
                    implicitWidth: modeRow.implicitWidth + 20
                    buttonRadius: Appearance.rounding.normal
                    colBackground: Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    onClicked: { TalosLauncher.cycleMode(1); root.focusSearch(); }
                    contentItem: RowLayout {
                        id: modeRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: TalosLauncher.modeDef(TalosLauncher.mode).icon
                            iconSize: 20
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: TalosLauncher.modeDef(TalosLauncher.mode).name
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                    StyledToolTip { text: Translation.tr("Switch mode (Tab)") }
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: null
                    color: Appearance.colors.colOnLayer1
                    placeholderText: TalosLauncher.modeDef(TalosLauncher.mode).hint
                    placeholderTextColor: Appearance.colors.colSubtext
                    selectedTextColor: Appearance.colors.colOnSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.larger
                    text: TalosLauncher.query
                    onTextEdited: TalosLauncher.query = text
                    Connections {
                        target: TalosLauncher
                        function onQueryChanged() {
                            if (searchField.text !== TalosLauncher.query) searchField.text = TalosLauncher.query;
                        }
                    }

                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        const shift = event.modifiers & Qt.ShiftModifier;
                        switch (event.key) {
                        case Qt.Key_Escape:
                            if (TalosLauncher.query.length > 0 || TalosLauncher.forcedMode.length > 0) TalosLauncher.reset();
                            else TalosLauncher.close();
                            break;
                        case Qt.Key_Down: root.move(root.gridMode ? root.columns : 1); break;
                        case Qt.Key_Up: root.move(root.gridMode ? -root.columns : -1); break;
                        case Qt.Key_PageDown: root.move(8); break;
                        case Qt.Key_PageUp: root.move(-8); break;
                        case Qt.Key_Right:
                            if (root.gridMode && searchField.cursorPosition === searchField.text.length) root.move(1);
                            else { event.accepted = false; return; }
                            break;
                        case Qt.Key_Left:
                            if (root.gridMode && searchField.cursorPosition === searchField.text.length) root.move(-1);
                            else { event.accepted = false; return; }
                            break;
                        case Qt.Key_Tab: TalosLauncher.cycleMode(1); break;
                        case Qt.Key_Backtab: TalosLauncher.cycleMode(-1); break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            TalosLauncher.activate(root.currentItem, ctrl || shift);
                            break;
                        case Qt.Key_P:
                            if (ctrl) { root.previewVisible = !root.previewVisible; break; }
                            event.accepted = false; return;
                        default:
                            if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                                TalosLauncher.activate(root.results[event.key - Qt.Key_1]);
                                break;
                            }
                            if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                                const action = root.currentItem?.actions?.[event.key - Qt.Key_1];
                                if (action) { if (!action.keepOpen) TalosLauncher.close(); action.run(); }
                                break;
                            }
                            if (event.key === Qt.Key_Backspace && searchField.text.length === 0 && TalosLauncher.forcedMode.length > 0) {
                                TalosLauncher.setMode("all");
                                break;
                            }
                            event.accepted = false;
                            return;
                        }
                        event.accepted = true;
                    }
                }

                MaterialLoadingIndicator {
                    visible: TalosLauncher.busy
                    implicitSize: 26
                    loading: TalosLauncher.busy
                }
                StyledText {
                    text: root.results.length > 0 ? `${root.results.length}` : ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // ===== Mode chips =====
        StyledFlickable {
            visible: root.cfg.showModeChips
            Layout.fillWidth: true
            implicitHeight: 34
            contentWidth: chipRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            Row {
                id: chipRow
                spacing: 6
                Repeater {
                    model: TalosLauncher.enabledModes
                    delegate: RippleButton {
                        id: chip
                        required property var modelData
                        readonly property bool active: TalosLauncher.mode === modelData.id
                        implicitHeight: 32
                        implicitWidth: chipContent.implicitWidth + 22
                        buttonRadius: Appearance.rounding.full
                        colBackground: active ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer1
                        colBackgroundHover: active ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
                        onClicked: { TalosLauncher.setMode(modelData.id); root.focusSearch(); }
                        contentItem: Row {
                            id: chipContent
                            anchors.centerIn: parent
                            spacing: 5
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.icon
                                iconSize: 16
                                fill: chip.active ? 1 : 0
                                color: chip.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.name
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: chip.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: TalosLauncher.prefixOf(chip.modelData.id).length > 0 && chip.modelData.id !== "all"
                                text: TalosLauncher.prefixOf(chip.modelData.id)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.monospace
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }
        }

        // ===== Results + preview =====
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledListView {
                    id: list
                    anchors.fill: parent
                    visible: !root.gridMode
                    clip: true
                    spacing: 2
                    model: root.gridMode ? [] : root.results
                    currentIndex: root.currentIndex
                    highlightFollowsCurrentItem: false
                    delegate: LauncherResultRow {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        item: modelData
                        compact: root.compact
                        selected: index === root.currentIndex
                        shortcutIndex: index < 9 ? index + 1 : 0
                        onHoverEntered: root.currentIndex = index
                        onActivated: alternate => TalosLauncher.activate(modelData, alternate)
                    }
                }

                GridView {
                    id: grid
                    anchors.fill: parent
                    visible: root.gridMode
                    clip: true
                    cellWidth: width / root.columns
                    cellHeight: TalosLauncher.mode === "wallpapers" ? cellWidth * 0.75 : TalosLauncher.mode === "emoji" ? cellWidth : cellWidth * 1.05
                    model: root.gridMode ? root.results : []
                    currentIndex: root.currentIndex
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: StyledScrollBar {}
                    delegate: LauncherResultTile {
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight
                        item: modelData
                        imageMode: TalosLauncher.mode === "wallpapers"
                        selected: index === root.currentIndex
                        onHoverEntered: root.currentIndex = index
                        onActivated: alternate => TalosLauncher.activate(modelData, alternate)
                    }
                }

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    spacing: 8
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: TalosLauncher.busy ? "hourglass_top" : TalosLauncher.modeDef(TalosLauncher.mode).icon
                        iconSize: 48
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: TalosLauncher.busy ? Translation.tr("Working…") : TalosLauncher.text.length > 0 ? Translation.tr("No results") : TalosLauncher.modeDef(TalosLauncher.mode).hint
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            LauncherPreview {
                visible: root.previewVisible && root.currentItem !== null
                Layout.fillHeight: true
                Layout.preferredWidth: 280
                item: root.currentItem
            }
        }

        // ===== Hints =====
        RowLayout {
            visible: root.cfg.showHints
            Layout.fillWidth: true
            spacing: 14
            Repeater {
                model: [
                    { keys: "↵", label: Translation.tr("open") },
                    { keys: "Ctrl ↵", label: root.currentItem?.actions?.[0]?.name ?? Translation.tr("alt action") },
                    { keys: "Tab", label: Translation.tr("mode") },
                    { keys: "Ctrl 1-9", label: Translation.tr("quick pick") },
                    { keys: "Ctrl P", label: Translation.tr("preview") },
                    { keys: "Esc", label: Translation.tr("close") },
                ]
                delegate: Row {
                    required property var modelData
                    spacing: 5
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: keyText.implicitWidth + 10
                        implicitHeight: 20
                        radius: Appearance.rounding.unsharpenmore
                        color: Appearance.colors.colLayer2
                        StyledText {
                            id: keyText
                            anchors.centerIn: parent
                            text: modelData.keys
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }
    }
}
