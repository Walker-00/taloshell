pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

/**
 * Screen recorder: options panel, countdown overlay and the floating recording pill.
 */
Scope {
    id: root
    readonly property var cfg: Config.options.screenRecord

    // ===================== Options panel =====================
    Loader {
        active: GlobalStates.recorderOpen
        sourceComponent: PanelWindow {
            id: window
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:recorder"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors { top: true; bottom: true; left: true; right: true }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colScrim
                MouseArea { anchors.fill: parent; onClicked: GlobalStates.recorderOpen = false }
            }

            Item {
                anchors.centerIn: parent
                width: 460
                height: panelCol.implicitHeight + 40
                focus: true
                Keys.onEscapePressed: GlobalStates.recorderOpen = false
                Keys.onReturnPressed: Recorder.start()

                StyledRectangularShadow { target: panelBg }
                Rectangle {
                    id: panelBg
                    anchors.fill: parent
                    radius: Appearance.rounding.screenRounding
                    color: Appearance.colors.colLayer0
                    border.width: Appearance.sizes.borderWidth
                    border.color: Appearance.colors.colLayer0Border
                    MouseArea { anchors.fill: parent }
                }

                ColumnLayout {
                    id: panelCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                    spacing: 14

                    RowLayout {
                        spacing: 10
                        MaterialSymbol { text: "screen_record"; iconSize: 28; color: Appearance.colors.colPrimary }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Screen recorder")
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.family: Appearance.font.family.title
                            color: Appearance.colors.colOnLayer0
                        }
                        RippleButton {
                            implicitWidth: 34; implicitHeight: 34
                            buttonRadius: Appearance.rounding.full
                            onClicked: Recorder.openFolder()
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "folder_open"; iconSize: 20; color: Appearance.colors.colOnLayer0 }
                            StyledToolTip { text: root.cfg.savePath }
                        }
                    }

                    OptionRow {
                        label: Translation.tr("Capture")
                        value: root.cfg.target
                        options: [
                            { value: "screen", name: Translation.tr("Screen"), icon: "desktop_windows" },
                            { value: "region", name: Translation.tr("Region"), icon: "crop_free" },
                            { value: "window", name: Translation.tr("Window"), icon: "select_window" },
                        ]
                        onPicked: v => Config.options.screenRecord.target = v
                    }
                    OptionRow {
                        label: Translation.tr("Audio")
                        value: root.cfg.audio
                        options: [
                            { value: "none", name: Translation.tr("Off"), icon: "volume_off" },
                            { value: "mic", name: Translation.tr("Mic"), icon: "mic" },
                            { value: "system", name: Translation.tr("System"), icon: "speaker" },
                            { value: "both", name: Translation.tr("Both"), icon: "graphic_eq" },
                        ]
                        onPicked: v => Config.options.screenRecord.audio = v
                    }
                    OptionRow {
                        label: Translation.tr("Format")
                        value: root.cfg.format
                        options: [
                            { value: "mp4", name: "MP4", icon: "movie" },
                            { value: "mkv", name: "MKV", icon: "movie" },
                            { value: "webm", name: "WebM", icon: "movie" },
                            { value: "gif", name: "GIF", icon: "gif_box" },
                        ]
                        onPicked: v => Config.options.screenRecord.format = v
                    }
                    OptionRow {
                        label: Translation.tr("Frame rate")
                        value: String(root.cfg.fps)
                        options: [
                            { value: "24", name: "24", icon: "" },
                            { value: "30", name: "30", icon: "" },
                            { value: "60", name: "60", icon: "" },
                            { value: "120", name: "120", icon: "" },
                        ]
                        onPicked: v => Config.options.screenRecord.fps = parseInt(v)
                    }
                    OptionRow {
                        label: Translation.tr("Countdown")
                        value: String(root.cfg.countdown)
                        options: [
                            { value: "0", name: Translation.tr("None"), icon: "" },
                            { value: "3", name: "3s", icon: "" },
                            { value: "5", name: "5s", icon: "" },
                            { value: "10", name: "10s", icon: "" },
                        ]
                        onPicked: v => Config.options.screenRecord.countdown = parseInt(v)
                    }
                    OptionRow {
                        label: Translation.tr("Engine")
                        value: root.cfg.backend
                        options: Recorder.backends.map(b => ({ value: b.id, name: b.id === "gsr" ? "GPU" : b.name, icon: "" }))
                        onPicked: v => Config.options.screenRecord.backend = v
                    }

                    // Recent recordings
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: Recorder.history.length > 0
                        spacing: 2
                        StyledText { text: Translation.tr("Recent"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        Repeater {
                            model: Recorder.history.slice(0, 3)
                            delegate: RippleButton {
                                id: recentItem
                                required property string modelData
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.small
                                onClicked: Qt.openUrlExternally(`file://${modelData}`)
                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    spacing: 8
                                    MaterialSymbol { text: "play_circle"; iconSize: 18; color: Appearance.colors.colPrimary }
                                    StyledText { Layout.fillWidth: true; text: recentItem.modelData.split("/").pop(); elide: Text.ElideMiddle; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }
                        }
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: 52
                        buttonRadius: Appearance.rounding.large
                        colBackground: Appearance.colors.colError
                        colBackgroundHover: Appearance.colors.colErrorHover
                        onClicked: Recorder.start()
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            MaterialSymbol { text: "fiber_manual_record"; fill: 1; iconSize: 24; color: Appearance.colors.colOnError }
                            StyledText {
                                text: Translation.tr("Start recording")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnError
                            }
                        }
                    }
                }
            }
        }
    }

    component OptionRow: RowLayout {
        id: optionRow
        property string label
        property string value
        property var options: []
        signal picked(string v)
        Layout.fillWidth: true
        spacing: 10
        StyledText {
            Layout.preferredWidth: 90
            text: optionRow.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: optionRow.options
                delegate: RippleButton {
                    id: optButton
                    required property var modelData
                    required property int index
                    readonly property bool active: optionRow.value === modelData.value
                    Layout.fillWidth: true
                    implicitHeight: 36
                    buttonRadius: active ? Appearance.rounding.full : Appearance.rounding.small
                    colBackground: active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                    colBackgroundHover: active ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                    onClicked: optionRow.picked(modelData.value)
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            visible: optButton.modelData.icon.length > 0
                            text: optButton.modelData.icon
                            iconSize: 16
                            color: optButton.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            text: optButton.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: optButton.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                        }
                    }
                }
            }
        }
    }

    // ===================== Countdown =====================
    Loader {
        active: Recorder.state === "countdown"
        sourceComponent: PanelWindow {
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:recorderCountdown"
            WlrLayershell.layer: WlrLayer.Overlay
            implicitWidth: 180
            implicitHeight: 180
            mask: Region {}
            Rectangle {
                anchors.fill: parent
                radius: Math.min(width / 2, Appearance.rounding.full)
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15)
                StyledText {
                    anchors.centerIn: parent
                    text: Recorder.countdownLeft
                    font.pixelSize: 96
                    font.family: Appearance.font.family.numbers
                    font.weight: Font.Bold
                    color: Appearance.colors.colError
                }
            }
        }
    }

    // ===================== Recording pill =====================
    Loader {
        active: Recorder.recording
        sourceComponent: PanelWindow {
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:recorderPill"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors { top: !Config.options.bar.bottom; bottom: Config.options.bar.bottom }
            margins.top: Appearance.sizes.barHeight + 8
            margins.bottom: Appearance.sizes.barHeight + 8
            implicitWidth: pill.implicitWidth
            implicitHeight: pill.implicitHeight

            Rectangle {
                id: pill
                implicitWidth: pillRow.implicitWidth + 20
                implicitHeight: 44
                radius: Math.min(height / 2, Appearance.rounding.full)
                color: Appearance.colors.colErrorContainer
                border.width: Appearance.sizes.borderWidth
                border.color: Appearance.colors.colError

                RowLayout {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 10
                    Rectangle {
                        width: 12; height: 12
                        radius: 6
                        color: Appearance.colors.colError
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 700 }
                            NumberAnimation { to: 1; duration: 700 }
                        }
                    }
                    StyledText {
                        text: Recorder.elapsedText
                        font.family: Appearance.font.family.numbers
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnErrorContainer
                    }
                    RippleButton {
                        implicitWidth: 32; implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colError
                        onClicked: Recorder.stop()
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "stop"; fill: 1; iconSize: 20; color: Appearance.colors.colOnError }
                        StyledToolTip { text: Translation.tr("Stop & save") }
                    }
                    RippleButton {
                        implicitWidth: 32; implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        onClicked: Recorder.discard()
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 20; color: Appearance.colors.colOnErrorContainer }
                        StyledToolTip { text: Translation.tr("Discard") }
                    }
                }
            }
        }
    }

    CompositorGlobalShortcut {
        name: "recorderToggle"
        description: "Start/stop screen recording with the saved options"
        onPressed: Recorder.toggle()
    }
    CompositorGlobalShortcut {
        name: "recorderPanel"
        description: "Open the screen recorder options"
        onPressed: GlobalStates.recorderOpen = !GlobalStates.recorderOpen
    }
}
