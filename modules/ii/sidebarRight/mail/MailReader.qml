pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * Reads one message. Bodies arrive already rendered by the daemon — plain text
 * with quote depths marked, or HTML that has had its remote content stripped —
 * so nothing here can cause the message to phone home.
 */
Item {
    id: root
    property var message: null
    property var loaded: null
    property bool busy: false
    property bool showQuoted: false
    property string error: ""
    property bool composing: false

    signal closed

    readonly property var attachments: root.message?.attachments?.filter(a => !a.inline) ?? []

    onMessageChanged: {
        root.loaded = null;
        root.error = "";
        root.showQuoted = false;
        root.composing = false;
        if (!root.message) return;

        root.busy = true;
        const wanted = root.message;
        Pigeon.loadMessage(wanted, Config.options.mail.renderHtml, response => {
            // The user may have gone back or opened something else while this
            // body was still downloading.
            if (root.message !== wanted) return;
            root.busy = false;
            if (!response.ok) {
                root.error = response.error ?? "";
                return;
            }
            root.loaded = response.result;
            if (Config.options.mail.markReadOnOpen && !wanted.seen) markReadTimer.restart();
        });
    }

    Timer {
        id: markReadTimer
        interval: Config.options.mail.markReadDelay
        onTriggered: {
            if (root.message && !root.message.seen) Pigeon.setSeen(root.message, true);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.message !== null

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
                text: root.message?.subject ?? ""
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: root.message
                    ? `${root.message.sender} <${root.message.sender_email}> · ${NotificationUtils.getFriendlyNotifTimeString(root.message.timestamp * 1000)}`
                    : ""
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.loaded?.remoteBlocked > 0 || root.loaded?.trackersStripped > 0
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: Translation.tr("Blocked %1 remote image(s) and %2 tracker(s)")
                    .arg(root.loaded?.remoteBlocked ?? 0)
                    .arg(root.loaded?.trackersStripped ?? 0)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.message !== null

            ReaderAction {
                symbol: "reply"
                tip: Translation.tr("Reply")
                onTriggered: root.composing = !root.composing
            }
            ReaderAction {
                symbol: "star"
                filled: root.message?.flagged ?? false
                tip: Translation.tr("Flag")
                onTriggered: Pigeon.toggleFlag(root.message)
            }
            ReaderAction {
                symbol: "mark_email_unread"
                tip: Translation.tr("Mark unread")
                onTriggered: {
                    markReadTimer.stop();
                    Pigeon.setSeen(root.message, false);
                    root.closed();
                }
            }
            ReaderAction {
                symbol: "archive"
                tip: Translation.tr("Archive")
                onTriggered: {
                    Pigeon.archive(root.message);
                    root.closed();
                }
            }
            ReaderAction {
                symbol: "delete"
                tip: Translation.tr("Move to trash")
                onTriggered: {
                    Pigeon.trash(root.message);
                    root.closed();
                }
            }
            Item {
                Layout.fillWidth: true
            }
            ReaderAction {
                symbol: root.showQuoted ? "unfold_less" : "unfold_more"
                tip: root.showQuoted ? Translation.tr("Hide quoted text") : Translation.tr("Show quoted text")
                visible: (root.loaded?.lines ?? []).some(l => l.kind.startsWith("quote"))
                onTriggered: root.showQuoted = !root.showQuoted
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 5
            visible: root.attachments.length > 0

            Repeater {
                model: root.attachments

                RippleButton {
                    required property var modelData
                    implicitHeight: 26
                    implicitWidth: attachmentRow.implicitWidth + 18
                    buttonRadius: Appearance.rounding.full
                    onClicked: Pigeon.openAttachment(root.message, modelData.part_id)

                    contentItem: RowLayout {
                        id: attachmentRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "attach_file"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                            text: `${modelData.name} · ${Math.max(1, Math.round(modelData.size / 1024))} kB`
                        }
                    }
                }
            }
        }

        MailCompose {
            Layout.fillWidth: true
            visible: root.composing
            replyTo: root.message
            onFinished: root.composing = false
        }

        StyledFlickable {
            id: bodyFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.composing
            contentWidth: width
            contentHeight: bodyColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: bodyColumn
                width: bodyFlick.width
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    visible: root.error.length > 0
                    wrapMode: Text.Wrap
                    color: Appearance.m3colors.m3error
                    text: root.error
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.busy
                    color: Appearance.colors.colSubtext
                    text: Translation.tr("Downloading…")
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Config.options.mail.renderHtml && (root.loaded?.html ?? "").length > 0
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    color: Appearance.colors.colOnLayer1
                    text: root.loaded?.html ?? ""
                    onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
                }

                Repeater {
                    model: Config.options.mail.renderHtml && (root.loaded?.html ?? "").length > 0
                        ? []
                        : (root.loaded?.lines ?? []).filter(l => root.showQuoted || !l.kind.startsWith("quote"))

                    StyledText {
                        required property var modelData
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.family: modelData.kind === "signature" ? Appearance.font.family.main : Appearance.font.family.reading
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: modelData.kind.startsWith("quote")
                            ? Appearance.colors.colSubtext
                            : modelData.kind === "signature"
                                ? Appearance.colors.colSubtext
                                : Appearance.colors.colOnLayer1
                        // A blank line still has to take up a line, or paragraph
                        // breaks collapse and the message becomes a wall.
                        text: modelData.text.length > 0 ? modelData.text : " "
                    }
                }
            }
        }
    }

    component ReaderAction: RippleButton {
        id: action
        property string symbol
        property string tip
        property bool filled: false

        signal triggered

        implicitHeight: 30
        implicitWidth: 30
        buttonRadius: Appearance.rounding.full
        onClicked: action.triggered()

        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: action.symbol
            fill: action.filled ? 1 : 0
            iconSize: Appearance.font.pixelSize.larger
            color: action.filled ? Appearance.m3colors.m3primary : Appearance.colors.colOnLayer1
        }

        StyledToolTip {
            text: action.tip
        }
    }
}
