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
    baseWidth: 780

    property string filterText: ""
    property string filterMode: "all" // all, dark, light, favorites

    readonly property var filteredThemes: ThemeEngine.themes.filter(t => {
        if (page.filterMode === "dark" && t.mode !== "dark") return false;
        if (page.filterMode === "light" && t.mode !== "light") return false;
        if (page.filterMode === "favorites" && !ThemeEngine.isFavorite(t.id)) return false;
        const q = page.filterText.toLowerCase().trim();
        if (q.length === 0) return true;
        return t.name.toLowerCase().includes(q) || t.family.toLowerCase().includes(q) || (t.author ?? "").toLowerCase().includes(q);
    })

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

        // ===== Current =====
        ContentSection {
            icon: "palette"
            shape: MaterialShape.Shape.Cookie9Sided
            title: Translation.tr("Color source")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Colors from")
                    icon: "colors"
                    currentValue: Config.options.appearance.theme.source
                    onSelected: newValue => {
                        if (newValue === "preset") ThemeEngine.apply(ThemeEngine.currentId, ThemeEngine.currentAccent);
                        else ThemeEngine.useWallpaperColors();
                    }
                    options: [
                        { displayName: Translation.tr("Wallpaper"), icon: "wallpaper", value: "wallpaper" },
                        { displayName: Translation.tr("Theme preset"), icon: "format_paint", value: "preset" }
                    ]
                }
                RowLayout {
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 8
                    MaterialSymbol {
                        text: ThemeEngine.presetActive ? "format_paint" : "wallpaper"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: ThemeEngine.presetActive
                                ? (ThemeEngine.currentTheme?.name ?? ThemeEngine.currentId)
                                : Translation.tr("Material You from wallpaper")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: ThemeEngine.applying ? Translation.tr("Applying…")
                                : ThemeEngine.presetActive ? Translation.tr("Accent: %1").arg(ThemeEngine.currentAccent || Translation.tr("default"))
                                : Translation.tr("Colors follow your wallpaper")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                    RippleButtonWithIcon {
                        materialIcon: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                        mainText: Appearance.m3colors.darkmode ? Translation.tr("Light") : Translation.tr("Dark")
                        onClicked: ThemeEngine.toggleDarkMode()
                        StyledToolTip { text: Translation.tr("Presets switch to their light/dark counterpart") }
                    }
                    RippleButtonWithIcon {
                        materialIcon: "shuffle"
                        mainText: Translation.tr("Surprise me")
                        onClicked: ThemeEngine.random(page.filterMode === "favorites")
                    }
                }
            }
        }

        // ===== Gallery =====
        ContentSection {
            icon: "style"
            shape: MaterialShape.Shape.Flower
            title: Translation.tr("Theme gallery")

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialTextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Search %1 themes…").arg(ThemeEngine.themes.length)
                    onTextChanged: page.filterText = text
                }
            }
            ConfigSelectionArray {
                currentValue: page.filterMode
                onSelected: newValue => page.filterMode = newValue
                options: [
                    { displayName: Translation.tr("All"), icon: "apps", value: "all" },
                    { displayName: Translation.tr("Dark"), icon: "dark_mode", value: "dark" },
                    { displayName: Translation.tr("Light"), icon: "light_mode", value: "light" },
                    { displayName: Translation.tr("Favorites"), icon: "star", value: "favorites" }
                ]
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: page.filteredThemes
                    delegate: ThemeCard {
                        required property var modelData
                        theme: modelData
                        width: (parent.width - 24) / 4
                        selected: ThemeEngine.presetActive && ThemeEngine.currentId === modelData.id
                        favorite: ThemeEngine.isFavorite(modelData.id)
                        onClicked: ThemeEngine.apply(modelData.id, "")
                        onFavoriteToggled: ThemeEngine.toggleFavorite(modelData.id)
                    }
                }
            }
            StyledText {
                visible: page.filteredThemes.length === 0
                Layout.alignment: Qt.AlignHCenter
                text: ThemeEngine.loading ? Translation.tr("Loading themes…") : Translation.tr("No themes match")
                color: Appearance.colors.colSubtext
            }
        }

        // ===== Accent =====
        ContentSection {
            visible: ThemeEngine.presetActive
            icon: "colorize"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Accent color")

            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: {
                        const accents = ThemeEngine.currentTheme?.accents ?? {};
                        return [{ name: "", color: ThemeEngine.currentTheme?.swatches?.primary ?? Appearance.colors.colPrimary }]
                            .concat(Object.keys(accents).map(k => ({ name: k, color: accents[k] })));
                    }
                    delegate: RippleButton {
                        id: accentButton
                        required property var modelData
                        readonly property bool active: ThemeEngine.currentAccent === modelData.name
                        implicitHeight: 40
                        implicitWidth: accentRow.implicitWidth + 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: active ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                        onClicked: ThemeEngine.setAccent(modelData.name)
                        contentItem: RowLayout {
                            id: accentRow
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle {
                                width: 18; height: 18
                                radius: Math.min(width / 2, Appearance.rounding.full)
                                color: accentButton.modelData.color
                                border.width: accentButton.active ? 2 : 0
                                border.color: Appearance.colors.colOnSecondaryContainer
                            }
                            StyledText {
                                text: accentButton.modelData.name === "" ? Translation.tr("Default") : accentButton.modelData.name
                                color: Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                MaterialTextField {
                    id: hexField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Custom accent, e.g. #ff79c6")
                    text: ThemeEngine.currentAccent.startsWith("#") ? ThemeEngine.currentAccent : ""
                }
                RippleButtonWithIcon {
                    materialIcon: "check"
                    mainText: Translation.tr("Use")
                    enabled: /^#?[0-9a-fA-F]{6}$/.test(hexField.text.trim())
                    onClicked: {
                        const v = hexField.text.trim();
                        ThemeEngine.setAccent(v.startsWith("#") ? v : `#${v}`);
                    }
                }
            }
        }

        // ===== Schedule =====
        ContentSection {
            icon: "schedule"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Day & night")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "brightness_auto"
                    text: Translation.tr("Switch light/dark automatically")
                    checked: Config.options.appearance.theme.followSystemTime
                    onCheckedChanged: Config.options.appearance.theme.followSystemTime = checked
                }
                RowLayout {
                    enabled: Config.options.appearance.theme.followSystemTime
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 10
                    MaterialSymbol { text: "light_mode"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                    StyledText { text: Translation.tr("Light from"); color: Appearance.colors.colOnSecondaryContainer }
                    MaterialTextField {
                        Layout.preferredWidth: 90
                        text: Config.options.appearance.theme.lightFrom
                        onEditingFinished: if (/^\d{1,2}:\d{2}$/.test(text)) Config.options.appearance.theme.lightFrom = text
                    }
                    Item { Layout.fillWidth: true }
                    MaterialSymbol { text: "dark_mode"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSecondaryContainer }
                    StyledText { text: Translation.tr("Dark from"); color: Appearance.colors.colOnSecondaryContainer }
                    MaterialTextField {
                        Layout.preferredWidth: 90
                        text: Config.options.appearance.theme.darkFrom
                        onEditingFinished: if (/^\d{1,2}:\d{2}$/.test(text)) Config.options.appearance.theme.darkFrom = text
                    }
                }
            }
        }

        // ===== Targets =====
        ContentSection {
            icon: "devices"
            shape: MaterialShape.Shape.Cookie6Sided
            title: Translation.tr("Apps to recolor")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "web_asset"
                    text: Translation.tr("GTK 3/4 apps")
                    checked: Config.options.appearance.theming.targets.gtk
                    onCheckedChanged: Config.options.appearance.theming.targets.gtk = checked
                }
                ConfigSwitch {
                    buttonIcon: "grid_view"
                    text: Translation.tr("Qt / KDE apps")
                    checked: Config.options.appearance.wallpaperTheming.enableQtApps
                    onCheckedChanged: Config.options.appearance.wallpaperTheming.enableQtApps = checked
                }
                ConfigSwitch {
                    buttonIcon: "terminal"
                    text: Translation.tr("Terminals")
                    checked: Config.options.appearance.wallpaperTheming.enableTerminal
                    onCheckedChanged: Config.options.appearance.wallpaperTheming.enableTerminal = checked
                }
                ConfigSwitch {
                    buttonIcon: "select_window_2"
                    text: Translation.tr("Hyprland window borders")
                    checked: Config.options.appearance.theming.targets.hyprland
                    onCheckedChanged: Config.options.appearance.theming.targets.hyprland = checked
                }
                ConfigSwitch {
                    buttonIcon: "lock"
                    text: Translation.tr("Hyprlock")
                    checked: Config.options.appearance.theming.targets.hyprlock
                    onCheckedChanged: Config.options.appearance.theming.targets.hyprlock = checked
                }
                ConfigSwitch {
                    buttonIcon: "search"
                    text: Translation.tr("Fuzzel")
                    checked: Config.options.appearance.theming.targets.fuzzel
                    onCheckedChanged: Config.options.appearance.theming.targets.fuzzel = checked
                }
            }
        }

        // ===== Custom =====
        ContentSection {
            icon: "add_circle"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Your own themes")
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Drop a JSON file in %1. Only \"name\", \"mode\" and a \"palette\" with bg, fg and a few colors are required; everything else is derived. Copy any built-in from defaults/themes as a starting point.").arg(ThemeEngine.userThemesDir)
            }
            RowLayout {
                spacing: 8
                RippleButtonWithIcon {
                    materialIcon: "folder_open"
                    mainText: Translation.tr("Open folder")
                    onClicked: ThemeEngine.openUserThemesFolder()
                }
                RippleButtonWithIcon {
                    materialIcon: "refresh"
                    mainText: Translation.tr("Reload themes")
                    onClicked: ThemeEngine.refresh()
                }
            }
        }
    }
}
