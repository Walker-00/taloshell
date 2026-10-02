import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true
    readonly property var cfg: Config.options.launcher

    function goTo(term) {
        const t = term.toLowerCase().trim();
        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                const child = rootItem.children[i];
                if (child.title && child.title.toLowerCase().includes(t)) return child;
            }
            for (let i = 0; i < rootItem.children.length; i++) {
                const found = findTarget(rootItem.children[i]);
                if (found) return found;
            }
            return null;
        }
        const target = findTarget(mainLayout);
        if (target) page.contentY = Math.max(0, target.mapToItem(mainLayout, 0, 0).y);
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        spacing: 20

        ContentSection {
            icon: "search"
            shape: MaterialShape.Shape.Cookie9Sided
            title: Translation.tr("Launcher")
            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Engine")
                    icon: "rocket_launch"
                    currentValue: page.cfg.engine
                    onSelected: v => Config.options.launcher.engine = v
                    options: [
                        { displayName: Translation.tr("Talos palette"), icon: "bolt", value: "talos" },
                        { displayName: Translation.tr("Classic overview"), icon: "overview", value: "classic" }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Layout")
                    icon: "view_list"
                    currentValue: page.cfg.style
                    onSelected: v => Config.options.launcher.style = v
                    options: [
                        { displayName: Translation.tr("List"), icon: "view_list", value: "list" },
                        { displayName: Translation.tr("Grid"), icon: "grid_view", value: "grid" },
                        { displayName: Translation.tr("Compact"), icon: "density_small", value: "compact" }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Position")
                    icon: "vertical_align_center"
                    currentValue: page.cfg.position
                    onSelected: v => Config.options.launcher.position = v
                    options: [
                        { displayName: Translation.tr("Center"), icon: "vertical_align_center", value: "center" },
                        { displayName: Translation.tr("Top"), icon: "vertical_align_top", value: "top" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "preview"
                    text: Translation.tr("Preview pane")
                    checked: page.cfg.showPreview
                    onCheckedChanged: Config.options.launcher.showPreview = checked
                }
                ConfigSwitch {
                    buttonIcon: "label"
                    text: Translation.tr("Mode chips")
                    checked: page.cfg.showModeChips
                    onCheckedChanged: Config.options.launcher.showModeChips = checked
                }
                ConfigSwitch {
                    buttonIcon: "keyboard"
                    text: Translation.tr("Keyboard hints")
                    checked: page.cfg.showHints
                    onCheckedChanged: Config.options.launcher.showHints = checked
                }
                ConfigSwitch {
                    buttonIcon: "gradient"
                    text: Translation.tr("Dim the background")
                    checked: page.cfg.dimBackground
                    onCheckedChanged: Config.options.launcher.dimBackground = checked
                }
                ConfigSpinBox {
                    icon: "width"
                    text: Translation.tr("Width")
                    from: 500; to: 1600; stepSize: 20
                    value: page.cfg.width
                    onValueChanged: Config.options.launcher.width = value
                }
                ConfigSpinBox {
                    icon: "height"
                    text: Translation.tr("Height")
                    from: 300; to: 1200; stepSize: 20
                    value: page.cfg.height
                    onValueChanged: Config.options.launcher.height = value
                }
                ConfigSpinBox {
                    icon: "view_module"
                    text: Translation.tr("Grid columns")
                    from: 3; to: 10; stepSize: 1
                    value: page.cfg.gridColumns
                    onValueChanged: Config.options.launcher.gridColumns = value
                }
            }
        }

        ContentSection {
            icon: "psychology"
            shape: MaterialShape.Shape.SoftBurst
            title: Translation.tr("Smarts")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "trending_up"
                    text: Translation.tr("Rank by how often & recently you use things")
                    checked: page.cfg.frecency
                    onCheckedChanged: Config.options.launcher.frecency = checked
                }
                ConfigSwitch {
                    buttonIcon: "calculate"
                    text: Translation.tr("Calculate math right in the All mode")
                    checked: page.cfg.mathInAll
                    onCheckedChanged: Config.options.launcher.mathInAll = checked
                }
                ConfigSwitch {
                    buttonIcon: "travel_explore"
                    text: Translation.tr("Offer a web search at the end")
                    checked: page.cfg.webFallback
                    onCheckedChanged: Config.options.launcher.webFallback = checked
                }
                ConfigSpinBox {
                    icon: "format_list_numbered"
                    text: Translation.tr("Max results")
                    from: 10; to: 300; stepSize: 10
                    value: page.cfg.maxResults
                    onValueChanged: Config.options.launcher.maxResults = value
                }
            }
            RippleButtonWithIcon {
                materialIcon: "restart_alt"
                mainText: Translation.tr("Forget usage history")
                onClicked: TalosLauncher.forgetHistory()
            }
        }

        ContentSection {
            icon: "tune"
            shape: MaterialShape.Shape.Flower
            title: Translation.tr("Modes & prefixes")
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Type a prefix to jump straight into a mode, or press Tab to cycle. Turn off modes you never use.")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: TalosLauncher.modeDefs.filter(m => m.id !== "all")
                    delegate: Rectangle {
                        id: modeRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: modeRowLayout.implicitHeight + 16
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                        RowLayout {
                            id: modeRowLayout
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }

                            spacing: 10
                            MaterialSymbol { text: modeRow.modelData.icon; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText { text: modeRow.modelData.name; color: Appearance.colors.colOnSecondaryContainer }
                                StyledText { Layout.fillWidth: true; text: modeRow.modelData.hint; elide: Text.ElideRight; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                            }
                            MaterialTextField {
                                Layout.preferredWidth: 64
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Appearance.font.family.monospace
                                text: page.cfg.prefixes[modeRow.modelData.id] ?? ""
                                onEditingFinished: Config.options.launcher.prefixes[modeRow.modelData.id] = text
                            }
                            StyledSwitch {
                                checked: page.cfg.modes.includes(modeRow.modelData.id)
                                onClicked: {
                                    const modes = page.cfg.modes.filter(m => m !== modeRow.modelData.id);
                                    if (checked) modes.push(modeRow.modelData.id);
                                    Config.options.launcher.modes = modes;
                                }
                            }
                    
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "travel_explore"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Web search")
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Use a bang to pick an engine: “!yt lofi” or “lofi !yt”. Add engines in the config file under launcher.webEngines (%s is replaced by your query).")
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: page.cfg.webEngines
                    delegate: RippleButton {
                        id: engineChip
                        required property var modelData
                        readonly property bool isDefault: page.cfg.defaultWebEngine === modelData.key
                        implicitHeight: 34
                        implicitWidth: engineRow.implicitWidth + 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: isDefault ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                        onClicked: Config.options.launcher.defaultWebEngine = modelData.key
                        contentItem: RowLayout {
                            id: engineRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol { text: engineChip.modelData.icon ?? "search"; iconSize: 16; color: Appearance.colors.colOnLayer2 }
                            StyledText { text: engineChip.modelData.name; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer2 }
                            StyledText { text: `!${engineChip.modelData.key}`; font.pixelSize: Appearance.font.pixelSize.smallest; font.family: Appearance.font.family.monospace; color: Appearance.colors.colSubtext }
                        }
                        StyledToolTip { text: engineChip.isDefault ? Translation.tr("Default engine") : Translation.tr("Click to make default") }
                    }
                }
            }
        }

        ContentSection {
            icon: "screen_record"
            shape: MaterialShape.Shape.Cookie4Sided
            title: Translation.tr("Screen recorder")
            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Engine")
                    icon: "memory"
                    currentValue: Config.options.screenRecord.backend
                    onSelected: v => Config.options.screenRecord.backend = v
                    options: Recorder.backends.map(b => ({ displayName: b.name, icon: "videocam", value: b.id }))
                }
                ConfigSelectionArray {
                    text: Translation.tr("Codec")
                    icon: "movie"
                    currentValue: Config.options.screenRecord.codec
                    onSelected: v => Config.options.screenRecord.codec = v
                    options: [
                        { displayName: "H.264", icon: "movie", value: "h264" },
                        { displayName: "HEVC", icon: "movie", value: "hevc" },
                        { displayName: "AV1", icon: "movie", value: "av1" },
                        { displayName: "VP9", icon: "movie", value: "vp9" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "arrow_selector_tool"
                    text: Translation.tr("Show cursor (GPU recorder)")
                    checked: Config.options.screenRecord.showCursor
                    onCheckedChanged: Config.options.screenRecord.showCursor = checked
                }
                RowLayout {
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 8
                    MaterialSymbol { text: "folder"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                    StyledText { text: Translation.tr("Save to"); color: Appearance.colors.colOnSecondaryContainer }
                    MaterialTextField {
                        Layout.fillWidth: true
                        text: Config.options.screenRecord.savePath
                        onEditingFinished: Config.options.screenRecord.savePath = text
                    }
                }
            }
            RippleButtonWithIcon {
                materialIcon: "tune"
                mainText: Translation.tr("Open recorder")
                onClicked: { GlobalStates.settingsOpen = false; GlobalStates.recorderOpen = true; }
            }
        }
    }
}
