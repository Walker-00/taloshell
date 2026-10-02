import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

/**
 * Compact reply/compose sheet. Sending hands the draft to the daemon, which
 * queues it in the outbox — so pressing send works offline and the message goes
 * out when the server is reachable again. The status line does not go quiet
 * until the daemon reports the actual SMTP outcome, not just that it queued.
 */
Rectangle {
    id: root
    property var replyTo: null
    property string status: ""
    property bool busy: false
    property var attachments: []
    property string pendingSendId: ""

    signal finished

    implicitHeight: layout.implicitHeight + 20
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2

    function reset() {
        toField.text = root.replyTo?.sender_email ?? "";
        subjectField.text = root.replyTo
            ? (/^re:/i.test(root.replyTo.subject ?? "") ? root.replyTo.subject : `Re: ${root.replyTo.subject ?? ""}`)
            : "";
        bodyField.text = "";
        root.attachments = [];
        root.pendingSendId = "";
        root.status = "";
    }

    function focusFirstEmpty() {
        if (toField.text.length === 0) toField.forceActiveFocus();
        else bodyField.forceActiveFocus();
    }

    onReplyToChanged: root.reset()

    function removeAttachment(index) {
        const next = root.attachments.slice();
        next.splice(index, 1);
        root.attachments = next;
    }

    Connections {
        target: Pigeon

        function onSent(id) {
            if (id.length === 0 || id !== root.pendingSendId) return;
            root.busy = false;
            root.pendingSendId = "";
            root.status = "";
            bodyField.text = "";
            root.attachments = [];
            root.finished();
        }

        function onSendFailed(id, message) {
            if (id.length === 0 || id !== root.pendingSendId) return;
            root.busy = false;
            root.pendingSendId = "";
            root.status = message.length > 0 ? message : Translation.tr("Could not send the message.");
        }
    }

    function send() {
        if (toField.text.trim().length === 0) {
            root.status = Translation.tr("Add a recipient first.");
            return;
        }

        root.busy = true;
        root.status = Translation.tr("Sending…");

        Pigeon.send({
            account: root.replyTo?.account ?? Pigeon.currentAccount,
            to: toField.text,
            subject: subjectField.text,
            body: bodyField.text,
            inReplyTo: root.replyTo?.message_id ?? null,
            attachments: root.attachments.map(a => a.path)
        }, response => {
            if (!response.ok) {
                root.busy = false;
                root.status = response.error ?? "";
                return;
            }
            // "queued" only means the daemon accepted the draft, not that it
            // reached the server — keep the busy state until onSent/onSendFailed.
            root.pendingSendId = response.result?.id ?? "";
            if (root.pendingSendId.length === 0) {
                // No id came back (should not happen); fall back to the old
                // queued-is-good-enough behaviour rather than hanging forever.
                root.busy = false;
                root.status = "";
                bodyField.text = "";
                root.attachments = [];
                root.finished();
            }
        });
    }

    Process {
        id: pickerProc
        command: ["zenity", "--file-selection", "--multiple", "--separator=\n", "--title=Attach files"]
        onRunningChanged: GlobalStates.dashboardSuspended = pickerProc.running
        stdout: StdioCollector {
            id: pickerOutput
            onStreamFinished: {
                const paths = pickerOutput.text.split("\n").map(p => p.trim()).filter(p => p.length > 0);
                if (paths.length === 0) return;
                const added = paths.map(p => ({ path: p, name: p.split("/").pop() }));
                root.attachments = root.attachments.concat(added);
            }
        }
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 6

        MaterialTextField {
            id: toField
            Layout.fillWidth: true
            placeholderText: Translation.tr("To")
        }

        MaterialTextField {
            id: subjectField
            Layout.fillWidth: true
            placeholderText: Translation.tr("Subject")
        }

        MaterialTextArea {
            id: bodyField
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            placeholderText: Translation.tr("Write your reply")
            wrapMode: TextEdit.Wrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: root.attachments.length > 0

            Repeater {
                model: root.attachments

                Rectangle {
                    id: chip
                    required property var modelData
                    required property int index

                    implicitWidth: chipRow.implicitWidth + 16
                    implicitHeight: chipRow.implicitHeight + 10
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer3

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "attach_file"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: chip.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                        }

                        MaterialSymbol {
                            text: "close"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext

                            TapHandler {
                                onTapped: root.removeAttachment(chip.index)
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.status.length > 0
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: root.status
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            RippleButtonWithIcon {
                height: 34
                buttonRadius: Appearance.rounding.normal
                materialIcon: "close"
                mainText: Translation.tr("Discard")
                onClicked: root.finished()
            }
            RippleButtonWithIcon {
                height: 34
                buttonRadius: Appearance.rounding.normal
                materialIcon: "attach_file"
                mainText: Translation.tr("Attach")
                enabled: !root.busy
                onClicked: pickerProc.running = true
            }
            RippleButtonWithIcon {
                height: 34
                buttonRadius: Appearance.rounding.normal
                materialIcon: "save"
                mainText: Translation.tr("Draft")
                enabled: !root.busy
                onClicked: {
                    Pigeon.saveDraft({
                        account: root.replyTo?.account ?? Pigeon.currentAccount,
                        to: toField.text,
                        subject: subjectField.text,
                        body: bodyField.text,
                        attachments: root.attachments.map(a => a.path)
                    }, () => root.finished());
                }
            }
            RippleButtonWithIcon {
                height: 34
                buttonRadius: Appearance.rounding.normal
                toggled: true
                materialIcon: "send"
                mainText: Translation.tr("Send")
                enabled: !root.busy
                onClicked: root.send()
            }
        }
    }
}
