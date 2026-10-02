pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.dashboard
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    readonly property int weekMin: Weather.daily.length > 0 ? Math.min(...Weather.daily.map(d => d.min)) : 0
    readonly property int weekMax: Weather.daily.length > 0 ? Math.max(...Weather.daily.map(d => d.max)) : 1

    RowLayout {
        anchors.fill: parent
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3
            spacing: 10

            // ===== Now =====
            DashCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 230
                color: Appearance.colors.colPrimaryContainer
                RowLayout {
                    anchors.fill: parent
                    spacing: 16
                    MaterialSymbol {
                        text: Icons.getWeatherIcon(Weather.data.wCode)
                        iconSize: 120
                        fill: 1
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: Weather.data.city || Translation.tr("Weather")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.8
                        }
                        StyledText {
                            text: Weather.data.temp || "--"
                            font.pixelSize: 72
                            font.family: Appearance.font.family.numbers
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: Weather.data.description || Translation.tr("Fetching weather…")
                            font.pixelSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: Translation.tr("Feels like %1 · H %2 L %3").arg(Weather.data.tempFeelsLike || "--").arg(Weather.daily[0]?.max ?? "--").arg(Weather.daily[0]?.min ?? "--")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.8
                        }
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            onClicked: Weather.refresh()
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "refresh"; iconSize: 20; color: Appearance.colors.colOnPrimaryContainer }
                            StyledToolTip { text: Translation.tr("Last updated %1").arg(Weather.data.lastRefresh || "—") }
                        }
                    }
                }
            }

            // ===== Details =====
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: [
                        { icon: "humidity_percentage", label: Translation.tr("Humidity"), value: Weather.data.humidity },
                        { icon: "air", label: Translation.tr("Wind"), value: Weather.data.wind },
                        { icon: "compress", label: Translation.tr("Pressure"), value: Weather.data.press },
                        { icon: "visibility", label: Translation.tr("Visibility"), value: Weather.data.visib },
                        { icon: "rainy", label: Translation.tr("Precip."), value: Weather.data.precip },
                        { icon: "cloud", label: Translation.tr("Clouds"), value: Weather.data.cr },
                        { icon: "wb_twilight", label: Translation.tr("Sunrise"), value: Weather.data.sunrise },
                        { icon: "bedtime", label: Translation.tr("Sunset"), value: Weather.data.sunset },
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            MaterialSymbol { text: modelData.icon; iconSize: 24; color: Appearance.colors.colPrimary }
                            ColumnLayout {
                                spacing: 0
                                StyledText { text: modelData.label; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                                StyledText { text: modelData.value || "--"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                            }
                        }
                    }
                }
            }

            // ===== Hourly =====
            DashCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: Translation.tr("Next 24 hours")
                icon: "schedule"
                StyledFlickable {
                    anchors.fill: parent
                    contentWidth: hourRow.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true
                    Row {
                        id: hourRow
                        spacing: 6
                        height: parent.height
                        Repeater {
                            model: Weather.hourly
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: 58
                                height: hourRow.height
                                radius: Appearance.rounding.normal
                                color: index === 0 ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    StyledText { Layout.alignment: Qt.AlignHCenter; text: index === 0 ? Translation.tr("Now") : Qt.formatTime(modelData.time, "hh:mm"); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                                    MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: Icons.getWmoIcon(modelData.code, modelData.night); iconSize: 26; color: Appearance.colors.colOnLayer2 }
                                    StyledText { Layout.alignment: Qt.AlignHCenter; text: `${modelData.temp}°`; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer2 }
                                    StyledText { Layout.alignment: Qt.AlignHCenter; visible: modelData.precip > 0; text: `${modelData.precip}%`; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colPrimary }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ===== 7 days =====
        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 2
            title: Translation.tr("This week")
            icon: "calendar_month"
            ColumnLayout {
                anchors.fill: parent
                spacing: 4
                Repeater {
                    model: Weather.daily
                    delegate: RowLayout {
                        id: dayRow
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        StyledText {
                            Layout.preferredWidth: 46
                            text: dayRow.index === 0 ? Translation.tr("Today") : Qt.locale().dayName(dayRow.modelData.date.getDay(), Locale.ShortFormat)
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }
                        MaterialSymbol { text: Icons.getWmoIcon(dayRow.modelData.code); iconSize: 22; color: Appearance.colors.colOnLayer1 }
                        StyledText {
                            Layout.preferredWidth: 34
                            text: dayRow.modelData.precip > 0 ? `${dayRow.modelData.precip}%` : ""
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colPrimary
                        }
                        StyledText { Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight; text: `${dayRow.modelData.min}°`; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                        // Range bar across the week's min/max
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 6
                            radius: 3
                            color: Appearance.colors.colSecondaryContainer
                            Rectangle {
                                readonly property real span: Math.max(1, root.weekMax - root.weekMin)
                                x: parent.width * (dayRow.modelData.min - root.weekMin) / span
                                width: Math.max(6, parent.width * (dayRow.modelData.max - dayRow.modelData.min) / span)
                                height: parent.height
                                radius: 3
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Appearance.colors.colSecondary }
                                    GradientStop { position: 1; color: Appearance.m3colors.m3tertiary }
                                }
                            }
                        }
                        StyledText { Layout.preferredWidth: 30; text: `${dayRow.modelData.max}°`; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                    }
                }
                StyledText {
                    visible: Weather.daily.length === 0
                    Layout.alignment: Qt.AlignCenter
                    text: Translation.tr("Forecast loading…")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
