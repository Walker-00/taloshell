pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.dashboard
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects

Item {
    id: root
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool hasArt: (player?.trackArtUrl ?? "").length > 0

    function formatTime(seconds) {
        if (!seconds || seconds < 0) return "0:00";
        const s = Math.floor(seconds);
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // ===== Cover =====
        DashCard {
            Layout.fillHeight: true
            Layout.preferredWidth: 380
            padding: 0

            Image {
                id: bgArt
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                visible: false
                asynchronous: true
            }
            FastBlur {
                anchors.fill: parent
                source: bgArt
                radius: 64
                opacity: 0.6
                visible: bgArt.status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.35)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Rectangle {
                        id: cover
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        radius: Appearance.rounding.verylarge
                        color: Appearance.colors.colLayer2
                        scale: root.player?.isPlaying ? 1 : 0.92
                        Behavior on scale {
                            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                        }
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle { width: cover.width; height: cover.height; radius: cover.radius }
                        }
                        Image {
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !root.hasArt
                            text: "album"
                            iconSize: 96
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // Visualizer
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 36
                    spacing: 3
                    Repeater {
                        model: 32
                        delegate: Rectangle {
                            required property int index
                            readonly property real v: {
                                const pts = GlobalStates.visualizerPoints;
                                if (!pts || pts.length === 0) return 0;
                                return Math.min(1, (pts[Math.floor(index * pts.length / 32)] ?? 0) / 1000);
                            }
                            anchors.bottom: parent.bottom
                            width: 6
                            height: Math.max(4, 36 * v)
                            radius: Math.min(width / 2, Appearance.rounding.full)
                            color: Appearance.colors.colPrimary
                            opacity: 0.5 + v * 0.5
                            Behavior on height { NumberAnimation { duration: 80 } }
                        }
                    }
                }
            }
        }

        // ===== Details, controls, lyrics =====
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            DashCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 250

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    // Player switcher
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: MprisController.players.length > 1
                        Repeater {
                            model: MprisController.players
                            delegate: RippleButton {
                                id: playerChip
                                required property MprisPlayer modelData
                                readonly property bool active: MprisController.activePlayer === modelData
                                implicitHeight: 28
                                implicitWidth: chipText.implicitWidth + 24
                                buttonRadius: Appearance.rounding.full
                                colBackground: active ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                                onClicked: MprisController.trackedPlayer = modelData
                                contentItem: StyledText {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: playerChip.modelData.identity
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer2
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.player?.trackTitle || Translation.tr("Nothing playing")
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.family: Appearance.font.family.title
                        font.variableAxes: Appearance.font.variableAxes.title
                        elide: Text.ElideRight
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: [root.player?.trackArtist, root.player?.trackAlbum].filter(s => s && s.length > 0).join(" — ") || (root.player?.identity ?? Translation.tr("Start something in a player with MPRIS support"))
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                        color: Appearance.colors.colSubtext
                    }
                    Item { Layout.fillHeight: true }

                    StyledSlider {
                        Layout.fillWidth: true
                        configuration: StyledSlider.Configuration.S
                        usePercentTooltip: false
                        enabled: root.player?.canSeek ?? false
                        from: 0
                        to: Math.max(1, root.player?.length ?? 1)
                        value: root.player?.position ?? 0
                        onMoved: if (root.player) root.player.position = value
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: root.formatTime(root.player?.position); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        Item { Layout.fillWidth: true }
                        StyledText { text: root.formatTime(root.player?.length); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10
                        Repeater {
                            model: [
                                { icon: "shuffle", action: () => MprisController.setShuffle(!MprisController.hasShuffle), toggled: MprisController.hasShuffle, enabled: MprisController.shuffleSupported, kind: "small" },
                                { icon: "skip_previous", action: () => MprisController.previous(), toggled: false, enabled: MprisController.canGoPrevious, kind: "mid" },
                                { icon: MprisController.isPlaying ? "pause" : "play_arrow", action: () => MprisController.togglePlaying(), toggled: true, enabled: MprisController.canTogglePlaying, kind: "big" },
                                { icon: "skip_next", action: () => MprisController.next(), toggled: false, enabled: MprisController.canGoNext, kind: "mid" },
                                { icon: MprisController.loopState === MprisLoopState.Track ? "repeat_one" : "repeat", action: () => MprisController.setLoopState(MprisController.loopState === MprisLoopState.None ? MprisLoopState.Playlist : MprisController.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None), toggled: MprisController.loopState !== MprisLoopState.None, enabled: MprisController.loopSupported, kind: "small" },
                            ]
                            delegate: RippleButton {
                                required property var modelData
                                enabled: modelData.enabled
                                implicitWidth: modelData.kind === "big" ? 72 : modelData.kind === "mid" ? 52 : 40
                                implicitHeight: modelData.kind === "big" ? 56 : modelData.kind === "mid" ? 48 : 40
                                buttonRadius: modelData.kind === "big" ? Appearance.rounding.large : Appearance.rounding.full
                                colBackground: modelData.kind === "big" ? Appearance.colors.colPrimary
                                    : modelData.toggled ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                                colBackgroundHover: modelData.kind === "big" ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                                onClicked: modelData.action()
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    fill: 1
                                    iconSize: modelData.kind === "big" ? 30 : 22
                                    color: modelData.kind === "big" ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                                    opacity: parent.enabled ? 1 : 0.4
                                }
                            }
                        }
                    }
                }
            }

            DashCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: Translation.tr("Lyrics")
                icon: "lyrics"
                headerTrailing: RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    onClicked: LyricsService.restartLyrics()
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "refresh"; iconSize: 18; color: Appearance.colors.colSubtext }
                }
                Lyrics {
                    anchors.fill: parent
                    textColor: Appearance.colors.colOnLayer1
                    activeColor: Appearance.colors.colPrimary
                    dimColor: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.6)
                    textAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
