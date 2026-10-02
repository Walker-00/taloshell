import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

// Speedometer gauges on the desktop (Brain_Shell-style), with network rates.
AbstractBackgroundWidget {
    id: root
    configEntryName: "gauges"
    hoverEnabled: true

    readonly property bool vertical: Config.options.background.widgets.gauges.vertical
    readonly property real gaugeSize: 110
    implicitWidth: vertical ? gaugeSize + 32 : grid.implicitWidth + 32
    implicitHeight: vertical ? grid.implicitHeight + 70 : gaugeSize + 70

    Component.onCompleted: SystemStats.acquire()
    Component.onDestruction: SystemStats.release()

    StyledDropShadow {
        target: card
        visible: Config.options.background.widgets.shadow
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding.verylarge
        color: Appearance.colors.colLayer1

        FastBlurred {
            anchors.fill: parent
            blurSource: root.wallpaperItem
            cardRadius: card.radius
            tint: Appearance.colors.colLayer1
            tintOpacity: 0.55
            trackX: root.x
            trackY: root.y
            visible: Config.options.background.widgets.blurWidgets
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            GridLayout {
                id: grid
                columns: root.vertical ? 1 : 4
                rowSpacing: 4
                columnSpacing: 4
                Gauge { size: root.gaugeSize; value: ResourceUsage.cpuUsage; label: Translation.tr("CPU"); subText: ResourceUsage.cpuTemp > 0 ? `${Math.round(ResourceUsage.cpuTemp)}°C` : "" }
                Gauge { size: root.gaugeSize; value: ResourceUsage.memoryUsedPercentage; label: Translation.tr("RAM"); color: Appearance.colors.colSecondary; subText: `${(ResourceUsage.memoryUsed / 1048576).toFixed(1)} GB` }
                Gauge {
                    size: root.gaugeSize
                    value: SystemStats.gpuAvailable ? SystemStats.gpuUsage : ResourceUsage.swapUsedPercentage
                    label: SystemStats.gpuAvailable ? Translation.tr("GPU") : Translation.tr("Swap")
                    color: Appearance.m3colors.m3tertiary
                    warnColors: false
                }
                Gauge { size: root.gaugeSize; value: ResourceUsage.diskUsedPercentage; label: Translation.tr("Disk") }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14
                StyledText { text: `↓ ${SystemStats.formatBytes(SystemStats.netRxRate, true)}`; font.pixelSize: Appearance.font.pixelSize.smaller; font.family: Appearance.font.family.monospace; color: Appearance.colors.colPrimary }
                StyledText { text: `↑ ${SystemStats.formatBytes(SystemStats.netTxRate, true)}`; font.pixelSize: Appearance.font.pixelSize.smaller; font.family: Appearance.font.family.monospace; color: Appearance.m3colors.m3tertiary }
            }
        }
    }
}
