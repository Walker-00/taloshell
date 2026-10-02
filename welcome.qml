//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false
    visible: true
    onClosing: {
        Quickshell.execDetached(["notify-send", Translation.tr("Welcome app"), Translation.tr("Enjoy! You can reopen the welcome app any time with <tt>Super+Shift+Alt+/</tt>. To open the settings app, hit <tt>Super+I</tt>. Tip: Super+D opens the dashboard if you load taloshell's keybinds"), "-a", "Shell"]);
        Qt.quit();
    }
    title: Translation.tr("taloshell Welcome")

    Component.onCompleted: {
        ThemeEngine.refresh()
        LookEngine.refresh()
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0 // Welcome app always only sets one var at a time so delay isn't needed
    }

    minimumWidth: 600
    minimumHeight: 400
    width: 900
    height: 650
    color: Appearance.m3colors.m3background

    Process {
        id: konachanWallProc
        property string status: ""
        command: ["bash", "-c", Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")]
        stdout: SplitParser {
            onRead: data => {
                console.log(`Konachan wall proc output: ${data}`);
                konachanWallProc.status = data.trim();
            }
        }
    }

    Process {
        id: translationProc
        property string locale: ""
        command: [Directories.aiTranslationScriptPath, translationProc.locale]
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Item {
            // Titlebar
            visible: Config.options?.windows.showTitlebar
            Layout.fillWidth: true
            implicitHeight: Math.max(welcomeText.implicitHeight, windowControlsRow.implicitHeight)
            StyledText {
                id: welcomeText
                anchors {
                    left: Config.options.windows.centerTitle ? undefined : parent.left
                    horizontalCenter: Config.options.windows.centerTitle ? parent.horizontalCenter : undefined
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                color: Appearance.colors.colOnLayer0
                text: Translation.tr("Hi there! First things first...")
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }
            RowLayout { // Window controls row
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: Translation.tr("Show next time")
                }
                StyledSwitch {
                    id: showNextTimeSwitch
                    checked: root.showNextTime
                    scale: 0.6
                    Layout.alignment: Qt.AlignVCenter
                    onCheckedChanged: {
                        if (checked) {
                            Quickshell.execDetached(["rm", root.firstRunFilePath]);
                        } else {
                            Quickshell.execDetached(["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(root.firstRunFileContent)}' > '${StringUtils.shellSingleQuoteEscape(root.firstRunFilePath)}'`]);
                        }
                    }
                }
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }

                    StyledToolTip {
                        text: Translation.tr("Tip: Close a window with Super+Q")
                    }
                }
            }
        }

        Rectangle {
            // Content container
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding - root.contentPadding
            implicitHeight: contentColumn.implicitHeight
            implicitWidth: contentColumn.implicitWidth
            Layout.fillWidth: true
            Layout.fillHeight: true

            ContentPage {
                id: contentColumn
                anchors.fill: parent

                ContentSection {
                    Layout.fillWidth: true
                    icon: "auto_awesome"
                    title: Translation.tr("Make it yours")

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Appearance.colors.colSubtext
                        text: Translation.tr("Welcome to taloshell! Pick a color theme and a look to start. Everything can be changed later in Settings (Super+I), and the launcher's # and & modes switch themes and looks in a second.")
                    }
                    RippleButtonWithIcon {
                        materialIcon: "move_up"
                        mainText: Translation.tr("Coming from illogical-impulse / end4-pC? Import your settings")
                        onClicked: Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/taloshell/config-tools.sh"), "import-ii"])
                    }
                    StyledText {
                        text: Translation.tr("Color theme")
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer1
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        RippleButton {
                            width: 184
                            height: 150
                            buttonRadius: Appearance.rounding.normal
                            colBackground: !ThemeEngine.presetActive ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                            onClicked: ThemeEngine.useWallpaperColors()
                            contentItem: ColumnLayout {
                                anchors.centerIn: parent
                                MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "wallpaper"; iconSize: 48; color: Appearance.colors.colPrimary }
                                StyledText { Layout.alignment: Qt.AlignHCenter; text: Translation.tr("From wallpaper"); color: Appearance.colors.colOnLayer2 }
                                StyledText { Layout.alignment: Qt.AlignHCenter; text: "Material You"; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                            }
                        }
                        Repeater {
                            model: ThemeEngine.themes.filter(t => ["catppuccin-mocha", "rosepine", "tokyonight-night", "gruvbox-dark", "nord", "kanagawa-wave", "everforest-dark", "catppuccin-latte"].includes(t.id))
                            delegate: ThemeCard {
                                required property var modelData
                                theme: modelData
                                width: 184
                                selected: ThemeEngine.presetActive && ThemeEngine.currentId === modelData.id
                                favorite: ThemeEngine.isFavorite(modelData.id)
                                onClicked: ThemeEngine.apply(modelData.id)
                                onFavoriteToggled: ThemeEngine.toggleFavorite(modelData.id)
                            }
                        }
                    }
                    StyledText {
                        text: Translation.tr("Look")
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer1
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: LookEngine.looks.filter(l => l.builtin).slice(0, 8)
                            delegate: LookCard {
                                required property var modelData
                                look: modelData
                                width: 184
                                selected: LookEngine.currentId === modelData.id
                                onClicked: LookEngine.apply(modelData.id)
                            }
                        }
                    }
                }

                ContentSection {
                    Layout.fillWidth: true
                    icon: "language"
                    title: Translation.tr("Language")

                    ContentSubsection {
                        title: Translation.tr("Select language")
                        ConfigSelectionArray {
                            id: languageSelector
                            currentValue: Config.options.language.ui
                            onSelected: newValue => {
                                Config.options.language.ui = newValue;
                            }
                            options: [
                                {
                                    displayName: Translation.tr("Auto (System)"),
                                    value: "auto"
                                },
                                ...Translation.allAvailableLanguages.map(lang => {
                                    return {
                                        displayName: lang,
                                        value: lang
                                    };
                                })]
                        }
                    }

                    NoticeBox {
                        Layout.fillWidth: true
                        text: Translation.tr("Language not listed or incomplete translations?\nYou can choose to generate translations for it with Gemini.\n1. Open the left sidebar with Super+A, set model to Gemini (if it isn't already)\n2. Type /key, hit Enter and follow the instructions\n3. Type /key YOUR_API_KEY\n4. Type the locale of your language below and press Generate")
                    }

                    ContentSubsection {
                        title: Translation.tr("Generate translation with Gemini")
                        
                        ConfigRow {
                            MaterialTextArea {
                                id: localeInput
                                Layout.fillWidth: true
                                placeholderText: Translation.tr("Locale code, e.g. fr_FR, de_DE, zh_CN...")
                                text: Config.options.language.ui === "auto" ? Qt.locale().name : Config.options.language.ui
                            }
                            RippleButtonWithIcon {
                                id: generateTranslationBtn
                                Layout.fillHeight: true
                                nerdIcon: ""
                                enabled: !translationProc.running || (translationProc.locale !== localeInput.text.trim())
                                mainText: enabled ? Translation.tr("Generate\nTypically takes 2 minutes") : Translation.tr("Generating...\nDon't close this window!")
                                onClicked: {
                                    translationProc.locale = localeInput.text.trim();
                                    translationProc.running = false;
                                    translationProc.running = true;
                                }
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "screenshot_monitor"
                    title: Translation.tr("Bar")

                    ConfigRow {
                        ContentSubsection {
                            title: Translation.tr("Bar position")
                            ConfigSelectionArray {
                                currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                                onSelected: newValue => {
                                    Config.options.bar.bottom = (newValue & 1) !== 0;
                                    Config.options.bar.vertical = (newValue & 2) !== 0;
                                }
                                options: [
                                    {
                                        displayName: Translation.tr("Top"),
                                        icon: "arrow_upward",
                                        value: 0 // bottom: false, vertical: false
                                    },
                                    {
                                        displayName: Translation.tr("Left"),
                                        icon: "arrow_back",
                                        value: 2 // bottom: false, vertical: true
                                    },
                                    {
                                        displayName: Translation.tr("Bottom"),
                                        icon: "arrow_downward",
                                        value: 1 // bottom: true, vertical: false
                                    },
                                    {
                                        displayName: Translation.tr("Right"),
                                        icon: "arrow_forward",
                                        value: 3 // bottom: true, vertical: true
                                    }
                                ]
                            }
                        }
                        ContentSubsection {
                            title: Translation.tr("Bar style")

                            ConfigSelectionArray {
                                currentValue: Config.options.bar.cornerStyle
                                onSelected: newValue => {
                                    Config.options.bar.cornerStyle = newValue; // Update local copy
                                }
                                options: [
                                    {
                                        displayName: Translation.tr("Hug"),
                                        icon: "line_curve",
                                        value: 0
                                    },
                                    {
                                        displayName: Translation.tr("Float"),
                                        icon: "page_header",
                                        value: 1
                                    },
                                    {
                                        displayName: Translation.tr("Rect"),
                                        icon: "toolbar",
                                        value: 2
                                    }
                                ]
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "format_paint"
                    title: Translation.tr("Style & wallpaper")

                    ButtonGroup {
                        Layout.alignment: Qt.AlignHCenter
                        LightDarkPreferenceButton {
                            dark: false
                        }
                        LightDarkPreferenceButton {
                            dark: true
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        RippleButtonWithIcon {
                            id: rndWallBtn
                            visible: Config.options.policies.weeb === 1
                            Layout.alignment: Qt.AlignHCenter
                            buttonRadius: Appearance.rounding.small
                            materialIcon: "ifl"
                            mainText: konachanWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: Konachan")
                            onClicked: {
                                console.log(konachanWallProc.command.join(" "));
                                konachanWallProc.running = true;
                            }
                            StyledToolTip {
                                text: Translation.tr("Random SFW Anime wallpaper from Konachan\nImage is saved to ~/Pictures/Wallpapers")
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "wallpaper"
                            StyledToolTip {
                                text: Translation.tr("Pick wallpaper image on your system")
                            }
                            onClicked: {
                                Quickshell.execDetached([`${Directories.wallpaperSwitchScriptPath}`]);
                            }
                            mainContentComponent: Component {
                                RowLayout {
                                    spacing: 10
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        text: Translation.tr("Choose file")
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    RowLayout {
                                        spacing: 3
                                        KeyboardKey {
                                            key: "Ctrl"
                                        }
                                        KeyboardKey {
                                            key: "󰖳"
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "+"
                                        }
                                        KeyboardKey {
                                            key: "T"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    NoticeBox {
                        Layout.fillWidth: true
                        text: Translation.tr("Change any time later with /dark, /light, /wallpaper in the launcher\nIf the shell's colors aren't changing:\n    1. Open the right sidebar with Super+N\n    2. Click \"Reload Hyprland & Quickshell\" in the top-right corner")
                    }
                }

                ContentSection {
                    icon: "rule"
                    title: Translation.tr("Policies")

                    ConfigRow {
                        Layout.fillWidth: true

                        ContentSubsection {
                            title: "Weeb"

                            ConfigSelectionArray {
                                currentValue: Config.options.policies.weeb
                                onSelected: newValue => {
                                    Config.options.policies.weeb = newValue;
                                }
                                options: [
                                    {
                                        displayName: Translation.tr("No"),
                                        icon: "close",
                                        value: 0
                                    },
                                    {
                                        displayName: Translation.tr("Yes"),
                                        icon: "check",
                                        value: 1
                                    },
                                    {
                                        displayName: Translation.tr("Closet"),
                                        icon: "ev_shadow",
                                        value: 2
                                    }
                                ]
                            }
                        }

                        ContentSubsection {
                            title: "AI"

                            ConfigSelectionArray {
                                currentValue: Config.options.policies.ai
                                onSelected: newValue => {
                                    Config.options.policies.ai = newValue;
                                }
                                options: [
                                    {
                                        displayName: Translation.tr("No"),
                                        icon: "close",
                                        value: 0
                                    },
                                    {
                                        displayName: Translation.tr("Yes"),
                                        icon: "check",
                                        value: 1
                                    },
                                    {
                                        displayName: Translation.tr("Local only"),
                                        icon: "sync_saved_locally",
                                        value: 2
                                    }
                                ]
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "info"
                    title: Translation.tr("Info")

                    Flow {
                        Layout.fillWidth: true
                        spacing: 5

                        RippleButtonWithIcon {
                            materialIcon: "keyboard_alt"
                            onClicked: {
                                Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "cheatsheet", "toggle"]);
                            }
                            mainContentComponent: Component {
                                RowLayout {
                                    spacing: 10
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        text: Translation.tr("Keybinds")
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    RowLayout {
                                        spacing: 3
                                        KeyboardKey {
                                            key: "󰖳"
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "+"
                                        }
                                        KeyboardKey {
                                            key: "/"
                                        }
                                    }
                                }
                            }
                        }

                        RippleButtonWithIcon {
                            materialIcon: "help"
                            mainText: Translation.tr("Usage")
                            onClicked: {
                                Qt.openUrlExternally("https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/02usage/");
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "construction"
                            mainText: Translation.tr("Configuration")
                            onClicked: {
                                Qt.openUrlExternally("https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/03config/");
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "monitoring"
                    title: Translation.tr("Useless buttons")

                    Flow {
                        Layout.fillWidth: true
                        spacing: 5

                        RippleButtonWithIcon {
                            nerdIcon: "󰊤"
                            mainText: Translation.tr("GitHub")
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/end-4/dots-hyprland");
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "favorite"
                            mainText: "Funny number"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/sponsors/end-4");
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
