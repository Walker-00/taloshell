import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    forceWidth: true
    bottomContentPadding: 35
    property bool isMinimal: Config.options.settings.style === "minimal"

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "yay -Syu --combinedupgrade=false"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    readonly property string configToolsPath: FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/taloshell/config-tools.sh"))

    Process {
        id: configToolProc
        property bool reloadAfter: false
        onExited: if (reloadAfter) Quickshell.reload(true)
    }
    function runConfigTool(action, reloadAfter = false) {
        configToolProc.reloadAfter = reloadAfter;
        configToolProc.command = ["bash", configToolsPath, action];
        configToolProc.running = true;
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 156 
        Layout.topMargin: !isMinimal ? 35 : 4
        Layout.leftMargin: !isMinimal ? 16 : 0
        Layout.rightMargin: !isMinimal ? 16 : 0

        radius: 24
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            spacing: 24

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 110
                implicitHeight: 110
                radius: 20
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)

                IconImage {
                    anchors.centerIn: parent
                    implicitWidth: 72
                    implicitHeight: 72
                    source: Quickshell.iconPath(SystemInfo.logo)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: SystemInfo.distroName
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.ExtraBold
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Kernel " + (SystemInfo.kernelVersion || "Loading...")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }

                Row {
                    id: colorRow
                    spacing: -6

                    Repeater {
                        model: [
                            Appearance.m3colors.m3primary,
                            Appearance.m3colors.m3secondary,
                            Appearance.m3colors.m3tertiary,
                            Appearance.m3colors.m3error,
                            Appearance.m3colors.m3primaryContainer,
                            Appearance.m3colors.m3secondaryContainer,
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: 28
                            height: 28
                            radius: Math.min(width / 2, Appearance.rounding.full)
                            color: modelData
                            z: index
                            border.width: 2
                            border.color: Appearance.colors.colLayer1
                        }
                    }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                spacing: 8
                RippleButton {
                    buttonText: Translation.tr("Import from illogical-impulse")
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    Layout.preferredHeight: 44
                    downAction: () => runConfigTool("import-ii")
                    contentItem: StyledText {
                        text: parent.buttonText
                        horizontalAlignment: Text.AlignHCenter
                        leftPadding: 10
                        rightPadding: 10
                    }
                    StyledToolTip { text: Translation.tr("Merges your ii / end4-pC settings, to-dos, notes and presets into taloshell (a backup is kept)") }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: !isMinimal ? 0 : -8
        spacing: 8

        RowLayout { //This is not in the grid because I was planning to do something else.
            Layout.fillWidth: true
            spacing: 8

            AboutCard {
                icon: "planner_review"
                iconShape: MaterialShape.Shape.Pentagon
                label: "CPU"
                value: SystemInfo.cpu || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "monitor"
                iconShape: MaterialShape.Shape.ClamShell
                label: "GPU"
                value: SystemInfo.gpu || "N/A"
                Layout.fillWidth: true
            }
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: 8
            columnSpacing: 8

            AboutCard {
                icon: "memory"
                label: "Memory"
                value: SystemInfo.memory || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "storage"
                iconShape: MaterialShape.Shape.Cookie6Sided
                label: "Disk"
                value: SystemInfo.disk || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                visible: !isMinimal
                icon: "terminal"
                label: "Shell"
                iconShape: MaterialShape.Shape.Gem
                value: SystemInfo.shell || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "package_2"
                label: "Packages"
                iconShape: MaterialShape.Shape.Sunny
                value: SystemInfo.packages || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "update"
                label: "Updates"
                iconShape: MaterialShape.Shape.Cookie9Sided
                value: Updates.checking ? "Checking..." : (Updates.count === 0 ? "Up to date" : `${Updates.count}`)
                Layout.fillWidth: true
                clickAction: () => {
                    runSystemUpdate()
                }
            }

            AboutCard {
                visible: !isMinimal
                icon: "timelapse"
                label: "Uptime"
                iconShape: MaterialShape.Shape.Cookie12Sided
                value: DateTime.uptime || "Loading..."
                Layout.fillWidth: true
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: talosCol.implicitHeight + 32
            radius: 24
            color: Appearance.colors.colLayer1
            ColumnLayout {
                id: talosCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 8
                RowLayout {
                    spacing: 10
                    MaterialShapeWrappedMaterialSymbol {
                        text: "auto_awesome"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnPrimaryContainer
                        colSymbol: Appearance.colors.colPrimaryContainer
                        wrappedShape: MaterialShape.Shape.Cookie9Sided
                        padding: 6
                    }
                    ColumnLayout {
                        spacing: 0
                        StyledText { text: "taloshell"; font.pixelSize: Appearance.font.pixelSize.huge; font.weight: Font.Bold; color: Appearance.colors.colOnLayer1 }
                        StyledText { text: Translation.tr("The best bits of the Quickshell community, merged and extended"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                    }
                    Item { Layout.fillWidth: true }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [
                            { icon: "backup", label: Translation.tr("Back up settings"), action: () => runConfigTool("backup") },
                            { icon: "folder_open", label: Translation.tr("Config folder"), action: () => Qt.openUrlExternally(`file://${FileUtils.trimFileProtocol(Directories.shellConfig)}`) },
                            { icon: "restart_alt", label: Translation.tr("Reset to defaults"), action: () => runConfigTool("reset", true) },
                            { icon: "refresh", label: Translation.tr("Reload shell"), action: () => Quickshell.reload(true) },
                        ]
                        delegate: RippleButtonWithIcon {
                            required property var modelData
                            materialIcon: modelData.icon
                            mainText: modelData.label
                            onClicked: modelData.action()
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    textFormat: Text.MarkdownText
                    onLinkActivated: link => Qt.openUrlExternally(link)
                    text: Translation.tr("**Built on** [illogical-impulse](https://github.com/end-4/dots-hyprland) by end-4 and its fork [end4-pC](https://github.com/pctrade/end4-pC) by pctrade. **Ideas and parts from** [caelestia](https://github.com/caelestia-dots/shell) (dashboard), [Brain_Shell](https://github.com/Brainitech/Brain_Shell) (kanban, recorder, gauges) and [octashell](https://github.com/octagonemusic/octashell) (bezels). Themes by their respective authors (Catppuccin, Rosé Pine, Nord, Gruvbox, Tokyo Night, Kanagawa, Everforest, Dracula, Flexoki…). Made with [Quickshell](https://quickshell.outfoxxed.me).")
                }
            }
        }
    }
}
