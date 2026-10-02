pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.dashboard
import qs.modules.ii.sidebarRight.calendar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects

Item {
    id: root
    Component.onCompleted: SystemStats.acquire()
    Component.onDestruction: SystemStats.release()

    GridLayout {
        anchors.fill: parent
        columns: 3
        rowSpacing: 10
        columnSpacing: 10

        // ===== Clock & profile =====
        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Appearance.colors.colPrimaryContainer

            ColumnLayout {
                anchors.fill: parent
                spacing: 4
                RowLayout {
                    spacing: 10
                    Rectangle {
                        id: avatar
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Math.min(width / 2, Appearance.rounding.full)
                        color: Appearance.colors.colPrimary
                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: Config.options.profile.avatarPath !== "" ? "file://" + Config.options.profile.avatarPicture
                                : `file://${Quickshell.env("HOME")}/.face`
                            sourceSize: Qt.size(88, 88)
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle { width: avatar.width; height: avatar.height; radius: avatar.radius }
                            }
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: avatarImage.status !== Image.Ready
                            text: "person"
                            iconSize: 26
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                    ColumnLayout {
                        spacing: -2
                        StyledText {
                            text: Config.options.profile.displayName || SystemInfo.username
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: `${SystemInfo.distroName} · ${SystemInfo.hostname}`
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.75
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                StyledText {
                    text: DateTime.time
                    font.pixelSize: 64
                    font.family: Appearance.font.family.numbers
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                }
                StyledText {
                    text: DateTime.longDate
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnPrimaryContainer
                }
                RowLayout {
                    spacing: 12
                    opacity: 0.8
                    RowLayout {
                        spacing: 4
                        MaterialSymbol { text: "schedule"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnPrimaryContainer }
                        StyledText { text: Translation.tr("Up %1").arg(SystemStats.formatUptime(SystemStats.uptimeSeconds)); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimaryContainer }
                    }
                    RowLayout {
                        visible: Battery.available
                        spacing: 4
                        MaterialSymbol { text: Battery.isCharging ? "battery_charging_full" : "battery_full"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnPrimaryContainer }
                        StyledText { text: `${Math.round(Battery.percentage * 100)}%`; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimaryContainer }
                    }
                }
            }
        }

        // ===== Weather =====
        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: Weather.data.city || Translation.tr("Weather")
            icon: "location_on"

            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                RowLayout {
                    spacing: 10
                    MaterialSymbol {
                        text: Icons.getWeatherIcon(Weather.data.wCode)
                        iconSize: 56
                        fill: 1
                        color: Appearance.colors.colPrimary
                    }
                    ColumnLayout {
                        spacing: -4
                        StyledText {
                            text: Weather.data.temp || "--"
                            font.pixelSize: 40
                            font.family: Appearance.font.family.numbers
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: Weather.data.description || Translation.tr("Loading…")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
                StyledText {
                    text: Translation.tr("Feels like %1 · Humidity %2").arg(Weather.data.tempFeelsLike || "--").arg(Weather.data.humidity || "--")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: Weather.hourly.slice(1, 6)
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 74
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colLayer2
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                StyledText { Layout.alignment: Qt.AlignHCenter; text: Qt.formatTime(modelData.time, "hh"); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                                MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: Icons.getWmoIcon(modelData.code, modelData.night); iconSize: 20; color: Appearance.colors.colOnLayer2 }
                                StyledText { Layout.alignment: Qt.AlignHCenter; text: `${modelData.temp}°`; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer2 }
                            }
                        }
                    }
                }
            }
        }

        // ===== Calendar =====
        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            padding: 4
            CalendarWidget {
                anchors.centerIn: parent
                width: parent.width
            }
        }

        // ===== Media =====
        DashCard {
            id: mediaCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            readonly property MprisPlayer player: MprisController.activePlayer
            padding: 0

            Image {
                id: blurredArt
                anchors.fill: parent
                source: mediaCard.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                visible: false
                asynchronous: true
            }
            FastBlur {
                anchors.fill: parent
                source: blurredArt
                radius: 48
                visible: blurredArt.status === Image.Ready
                opacity: 0.55
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.4) }
                    GradientStop { position: 1; color: Appearance.colors.colLayer1 }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                RowLayout {
                    spacing: 12
                    Rectangle {
                        implicitWidth: 72
                        implicitHeight: 72
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer2
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: mediaCard.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !(mediaCard.player?.trackArtUrl)
                            text: "music_note"
                            iconSize: 32
                            color: Appearance.colors.colSubtext
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: mediaCard.player?.trackTitle || Translation.tr("Nothing playing")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: mediaCard.player?.trackArtist || (mediaCard.player?.identity ?? "")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            elide: Text.ElideRight
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                StyledProgressBar {
                    Layout.fillWidth: true
                    value: (mediaCard.player?.length ?? 0) > 0 ? (mediaCard.player.position / mediaCard.player.length) : 0
                    Timer {
                        running: mediaCard.player?.isPlaying ?? false
                        interval: 1000
                        repeat: true
                        onTriggered: mediaCard.player.positionChanged()
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Repeater {
                        model: [
                            { icon: "skip_previous", action: () => MprisController.previous(), big: false },
                            { icon: MprisController.isPlaying ? "pause" : "play_arrow", action: () => MprisController.togglePlaying(), big: true },
                            { icon: "skip_next", action: () => MprisController.next(), big: false },
                        ]
                        delegate: RippleButton {
                            required property var modelData
                            implicitWidth: modelData.big ? 56 : 42
                            implicitHeight: 42
                            buttonRadius: modelData.big ? Appearance.rounding.normal : Appearance.rounding.full
                            colBackground: modelData.big ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                            colBackgroundHover: modelData.big ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                            onClicked: modelData.action()
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData.icon
                                fill: 1
                                iconSize: 24
                                color: modelData.big ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }
            }
        }

        // ===== Gauges =====
        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: Translation.tr("System")
            icon: "monitoring"
            headerTrailing: StyledText {
                text: SystemStats.cpuFreqGHz > 0 ? `${SystemStats.cpuFreqGHz.toFixed(1)} GHz` : ""
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
            GridLayout {
                anchors.fill: parent
                columns: 2
                rowSpacing: 0
                columnSpacing: 0
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    size: 104
                    value: ResourceUsage.cpuUsage
                    label: Translation.tr("CPU")
                    subText: ResourceUsage.cpuTemp > 0 ? `${Math.round(ResourceUsage.cpuTemp)}°C` : ""
                }
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    size: 104
                    value: ResourceUsage.memoryUsedPercentage
                    label: Translation.tr("RAM")
                    subText: `${(ResourceUsage.memoryUsed / 1048576).toFixed(1)} GB`
                    color: Appearance.colors.colSecondary
                }
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    size: 104
                    value: SystemStats.gpuAvailable ? SystemStats.gpuUsage : ResourceUsage.swapUsedPercentage
                    label: SystemStats.gpuAvailable ? Translation.tr("GPU") : Translation.tr("Swap")
                    subText: SystemStats.gpuTemp > 0 ? `${Math.round(SystemStats.gpuTemp)}°C` : ""
                    color: Appearance.m3colors.m3tertiary
                    warnColors: false
                }
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    size: 104
                    value: ResourceUsage.diskUsedPercentage
                    label: Translation.tr("Disk")
                    subText: `${(ResourceUsage.diskFree / 1048576).toFixed(0)} GB free`
                }
            }
        }

        // ===== Tasks =====
        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            title: Translation.tr("Up next")
            icon: "task_alt"
            headerTrailing: StyledText {
                text: Kanban.overdueCount > 0 ? Translation.tr("%1 overdue").arg(Kanban.overdueCount) : Translation.tr("%1 open").arg(Kanban.openCount)
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Kanban.overdueCount > 0 ? Appearance.colors.colError : Appearance.colors.colSubtext
            }
            ColumnLayout {
                anchors.fill: parent
                spacing: 4
                Repeater {
                    model: Kanban.tasks.filter(t => t.column !== Kanban.doneColumn)
                        .sort((a, b) => (Kanban.isOverdue(b) - Kanban.isOverdue(a)) || (b.priority - a.priority) || ((a.due || "9999") < (b.due || "9999") ? -1 : 1))
                        .slice(0, 5)
                    delegate: RippleButton {
                        id: taskRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 34
                        buttonRadius: Appearance.rounding.small
                        onClicked: Kanban.moveTask(modelData.id, Kanban.doneColumn)
                        contentItem: RowLayout {
                            spacing: 8
                            MaterialSymbol {
                                Layout.leftMargin: 4
                                text: "radio_button_unchecked"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Kanban.priorityColor(taskRow.modelData.priority)
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: taskRow.modelData.title
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                Layout.rightMargin: 4
                                visible: taskRow.modelData.due !== ""
                                text: Kanban.formatDue(taskRow.modelData)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Kanban.isOverdue(taskRow.modelData) ? Appearance.colors.colError : Appearance.colors.colSubtext
                            }
                        }
                        StyledToolTip { text: Translation.tr("Click to mark done") }
                    }
                }
                StyledText {
                    visible: Kanban.openCount === 0
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    text: Translation.tr("All clear ✨")
                    color: Appearance.colors.colSubtext
                }
                Item { Layout.fillHeight: true }
                ToolbarTextField {
                    id: quickAdd
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    implicitHeight: 40
                    placeholderText: Translation.tr("Add a task…  (!3 @tomorrow #tag)")
                    onAccepted: {
                        Kanban.quickAdd(text);
                        text = "";
                    }
                }
            }
        }
    }
}
