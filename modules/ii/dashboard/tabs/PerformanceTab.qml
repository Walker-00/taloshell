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

Item {
    id: root
    Component.onCompleted: SystemStats.acquire()
    Component.onDestruction: SystemStats.release()

    function maxOf(list) {
        let m = 1;
        for (const v of list) if (v > m) m = v;
        return m;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ===== Gauges row =====
        DashCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 170
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    size: 132
                    value: ResourceUsage.cpuUsage
                    label: Translation.tr("CPU")
                    subText: SystemStats.cpuFreqGHz > 0 ? `${SystemStats.cpuFreqGHz.toFixed(2)} GHz` : ""
                }
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    size: 132
                    value: Math.min(1, ResourceUsage.cpuTemp / 100)
                    valueText: ResourceUsage.cpuTemp > 0 ? `${Math.round(ResourceUsage.cpuTemp)}°` : "--"
                    label: Translation.tr("CPU temp")
                    color: Appearance.m3colors.m3tertiary
                }
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    size: 132
                    value: ResourceUsage.memoryUsedPercentage
                    label: Translation.tr("Memory")
                    subText: `${(ResourceUsage.memoryUsed / 1048576).toFixed(1)} / ${(ResourceUsage.memoryTotal / 1048576).toFixed(0)} GB`
                    color: Appearance.colors.colSecondary
                }
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    visible: SystemStats.gpuAvailable
                    size: 132
                    value: SystemStats.gpuUsage
                    label: SystemStats.gpuVendor === "intel" ? Translation.tr("GPU clock") : Translation.tr("GPU")
                    subText: SystemStats.gpuVramTotal > 0 ? `${(SystemStats.gpuVramUsed / 1024).toFixed(1)} / ${(SystemStats.gpuVramTotal / 1024).toFixed(0)} GB`
                        : SystemStats.gpuTemp > 0 ? `${Math.round(SystemStats.gpuTemp)}°C` : ""
                    color: Appearance.m3colors.m3tertiary
                }
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    size: 132
                    value: ResourceUsage.swapUsedPercentage
                    label: Translation.tr("Swap")
                    subText: `${(ResourceUsage.swapUsed / 1048576).toFixed(1)} GB`
                    warnColors: false
                }
                Gauge {
                    Layout.alignment: Qt.AlignCenter
                    size: 132
                    value: ResourceUsage.diskUsedPercentage
                    label: Translation.tr("Disk /")
                    subText: `${(ResourceUsage.diskFree / 1048576).toFixed(0)} GB free`
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 3
                spacing: 10

                // ===== CPU history + cores =====
                DashCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: SystemStats.cpuModel || Translation.tr("Processor")
                    icon: "memory"
                    headerTrailing: StyledText {
                        text: Translation.tr("Load %1 %2 %3").arg(SystemStats.loadAvg1.toFixed(2)).arg(SystemStats.loadAvg5.toFixed(2)).arg(SystemStats.loadAvg15.toFixed(2))
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: Appearance.colors.colSubtext
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8
                        Graph {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            values: ResourceUsage.cpuUsageHistory
                            points: ResourceUsage.historyLength
                            alignment: Graph.Alignment.Right
                            color: Appearance.colors.colPrimary
                            fillOpacity: 0.25
                        }
                        // Per-core bars
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.preferredHeight: 34
                            Layout.maximumHeight: 34
                            spacing: 3
                            Repeater {
                                model: SystemStats.coreUsage
                                delegate: Rectangle {
                                    required property real modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    radius: Appearance.rounding.unsharpenmore
                                    color: Appearance.colors.colSecondaryContainer
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                        height: parent.height * modelData
                                        radius: parent.radius
                                        color: modelData > 0.85 ? Appearance.colors.colError : Appearance.colors.colPrimary
                                        Behavior on height {
                                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== Network =====
                DashCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    title: Translation.tr("Network") + (SystemStats.netInterface ? ` · ${SystemStats.netInterface}` : "")
                    icon: "lan"
                    headerTrailing: RowLayout {
                        spacing: 10
                        StyledText { text: `↓ ${SystemStats.formatBytes(SystemStats.netRxRate, true)}`; font.pixelSize: Appearance.font.pixelSize.smaller; font.family: Appearance.font.family.monospace; color: Appearance.colors.colPrimary }
                        StyledText { text: `↑ ${SystemStats.formatBytes(SystemStats.netTxRate, true)}`; font.pixelSize: Appearance.font.pixelSize.smaller; font.family: Appearance.font.family.monospace; color: Appearance.m3colors.m3tertiary }
                    }
                    Item {
                        anchors.fill: parent
                        Graph {
                            anchors.fill: parent
                            values: SystemStats.netRxHistory.map(v => v / root.maxOf(SystemStats.netRxHistory.concat(SystemStats.netTxHistory)))
                            points: SystemStats.historyLength
                            alignment: Graph.Alignment.Right
                            color: Appearance.colors.colPrimary
                            fillOpacity: 0.2
                        }
                        Graph {
                            anchors.fill: parent
                            values: SystemStats.netTxHistory.map(v => v / root.maxOf(SystemStats.netRxHistory.concat(SystemStats.netTxHistory)))
                            points: SystemStats.historyLength
                            alignment: Graph.Alignment.Right
                            color: Appearance.m3colors.m3tertiary
                            fillOpacity: 0.12
                        }
                        StyledText {
                            anchors { right: parent.right; bottom: parent.bottom }
                            text: Translation.tr("Total ↓ %1  ↑ %2").arg(SystemStats.formatBytes(SystemStats.netRxTotal)).arg(SystemStats.formatBytes(SystemStats.netTxTotal))
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            // ===== Processes =====
            DashCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 2
                title: Translation.tr("Top processes")
                icon: "list_alt"
                headerTrailing: RowLayout {
                    spacing: 2
                    Repeater {
                        model: [{ id: "cpu", label: "CPU" }, { id: "mem", label: "MEM" }]
                        delegate: RippleButton {
                            required property var modelData
                            implicitHeight: 24
                            implicitWidth: 44
                            buttonRadius: Appearance.rounding.full
                            toggled: SystemStats.processSort === modelData.id
                            onClicked: SystemStats.processSort = modelData.id
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 2
                    Repeater {
                        model: SystemStats.topProcesses
                        delegate: RippleButton {
                            id: procRow
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.small
                            altAction: () => SystemStats.killProcess(modelData.pid)
                            contentItem: RowLayout {
                                spacing: 8
                                StyledText {
                                    Layout.leftMargin: 6
                                    Layout.fillWidth: true
                                    text: procRow.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    Layout.preferredWidth: 52
                                    horizontalAlignment: Text.AlignRight
                                    text: `${procRow.modelData.cpu.toFixed(1)}%`
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.monospace
                                    color: SystemStats.processSort === "cpu" ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                }
                                StyledText {
                                    Layout.preferredWidth: 52
                                    Layout.rightMargin: 6
                                    horizontalAlignment: Text.AlignRight
                                    text: `${procRow.modelData.mem.toFixed(1)}%`
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.monospace
                                    color: SystemStats.processSort === "mem" ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                }
                            }
                            StyledToolTip { text: Translation.tr("PID %1 · right-click to end").arg(procRow.modelData.pid) }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    RippleButtonWithIcon {
                        Layout.alignment: Qt.AlignRight
                        materialIcon: "open_in_new"
                        mainText: Translation.tr("Task manager")
                        onClicked: {
                            GlobalStates.dashboardOpen = false;
                            Quickshell.execDetached(["bash", "-c", Config.options.apps.taskManager]);
                        }
                    }
                }
            }
        }
    }
}
