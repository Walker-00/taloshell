pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * The message list. Actions live on the row and appear on hover so a mistaken
 * tap cannot archive something the user only meant to read.
 */
Item {
    id: root
    required property var messages

    signal messageOpened(var message)

    StyledListView {
        id: listView
        anchors.fill: parent
        spacing: 4
        animateAppearance: false
        clip: true

        // A ScriptModel leaves the delegates of removed rows alive on screen,
        // so an emptier folder still shows the last one's messages underneath.
        model: root.messages

        delegate: Rectangle {
            id: row
            required property var modelData

            width: ListView.view.width
            implicitHeight: rowLayout.implicitHeight + 14
            radius: Appearance.rounding.small
            color: hover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            // The row actions sit above the MouseArea and take the hover off it
            // as the cursor reaches them, which hid them again and made them
            // flicker. A HoverHandler keeps reporting the row underneath.
            HoverHandler {
                id: hover
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: event => {
                    if (event.button === Qt.MiddleButton) {
                        Pigeon.archive(row.modelData);
                        return;
                    }
                    root.messageOpened(row.modelData);
                }
            }

            RowLayout {
                id: rowLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: Appearance.m3colors.m3primary
                    opacity: row.modelData.seen ? 0 : 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: row.modelData.seen ? Font.Normal : Font.DemiBold
                            color: Appearance.colors.colOnLayer2
                            text: row.modelData.sender
                        }

                        MaterialSymbol {
                            visible: row.modelData.has_attachments
                            text: "attach_file"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        MaterialSymbol {
                            visible: row.modelData.crypto !== "none"
                            text: row.modelData.crypto.startsWith("encrypted") ? "lock" : "verified"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: row.modelData.crypto === "signed-invalid" || row.modelData.crypto === "decrypt-failed"
                                ? Appearance.m3colors.m3error
                                : Appearance.colors.colSubtext
                        }

                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            text: NotificationUtils.getFriendlyNotifTimeString(row.modelData.timestamp * 1000)
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: row.modelData.seen ? Font.Normal : Font.DemiBold
                        color: Appearance.colors.colOnLayer2
                        text: row.modelData.subject
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: row.modelData.preview.length > 0
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        text: row.modelData.preview
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    opacity: hover.hovered || row.modelData.flagged ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    CircleUtilButton {
                        onClicked: Pigeon.toggleFlag(row.modelData)

                        MaterialSymbol {
                            horizontalAlignment: Text.AlignHCenter
                            fill: row.modelData.flagged ? 1 : 0
                            text: "star"
                            iconSize: Appearance.font.pixelSize.normal
                            color: row.modelData.flagged ? Appearance.m3colors.m3primary : Appearance.colors.colOnLayer2
                        }
                    }

                    CircleUtilButton {
                        visible: hover.hovered
                        onClicked: Pigeon.setSeen(row.modelData, !row.modelData.seen)

                        MaterialSymbol {
                            horizontalAlignment: Text.AlignHCenter
                            text: row.modelData.seen ? "mark_email_unread" : "mark_email_read"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    CircleUtilButton {
                        visible: hover.hovered
                        onClicked: Pigeon.archive(row.modelData)

                        MaterialSymbol {
                            horizontalAlignment: Text.AlignHCenter
                            text: "archive"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    CircleUtilButton {
                        visible: hover.hovered
                        onClicked: Pigeon.trash(row.modelData)

                        MaterialSymbol {
                            horizontalAlignment: Text.AlignHCenter
                            text: "delete"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 40
        spacing: 6
        visible: root.messages.length === 0 && !Pigeon.loading

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "mark_email_read"
            iconSize: 45
            color: Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Translation.tr("Nothing here")
        }
    }

    StyledIndeterminateProgressBar {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: parent.width * 0.6
        visible: Pigeon.loading && root.messages.length === 0
    }
}
