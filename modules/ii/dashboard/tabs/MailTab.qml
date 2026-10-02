pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.dashboard
import qs.modules.ii.sidebarRight.mail
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * Mail on the dashboard: folders, list and reader side by side.
 *
 * The sidebar tab shows the same data one pane at a time; here there is room to
 * read a message without losing the list.
 */
Item {
    id: root
    property var openedMessage: null
    property string search: ""
    property bool composing: false

    readonly property var visibleMessages: {
        const needle = root.search.trim().toLowerCase();
        if (needle.length === 0) return Pigeon.messages;
        return Pigeon.messages.filter(m =>
            (m.subject ?? "").toLowerCase().includes(needle)
            || (m.sender ?? "").toLowerCase().includes(needle)
            || (m.sender_email ?? "").toLowerCase().includes(needle)
            || (m.preview ?? "").toLowerCase().includes(needle));
    }

    readonly property bool ready: Config.options.mail.enable && Pigeon.connected && !Pigeon.locked

    Connections {
        target: Pigeon

        function onLockedChanged() {
            root.openedMessage = null;
        }

        function onMessageListChanged() {
            // A message that has been moved or expunged must not stay in the
            // reader, or its actions would apply to something that is gone.
            if (!root.openedMessage) return;
            const still = Pigeon.messages.some(m =>
                m.uid === root.openedMessage.uid && m.folder === root.openedMessage.folder);
            if (!still) root.openedMessage = null;
        }
    }

    // ---- not ready yet ----

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 460)
        spacing: 12
        visible: !root.ready

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (!Config.options.mail.enable) return "mail_off";
                if (!Pigeon.connected) return "cloud_off";
                return "lock";
            }
            iconSize: 64
            color: Appearance.colors.colSubtext
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer0
            text: {
                if (!Config.options.mail.enable) return Translation.tr("Mail is switched off");
                if (Pigeon.daemonUnavailable) return Pigeon.lastError;
                if (!Pigeon.connected) return Translation.tr("Waiting for the pigeon daemon");
                if (!Pigeon.vaultExists) return Translation.tr("No mail vault yet");
                return Translation.tr("Your mail is locked");
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            visible: Pigeon.connected && Pigeon.locked && Pigeon.vaultExists
            text: Translation.tr("Everything pigeon keeps on this machine is encrypted. Enter the passphrase to open it.")
        }

        MaterialTextField {
            id: passphraseField
            Layout.fillWidth: true
            visible: Pigeon.connected && Pigeon.locked && Pigeon.vaultExists
            echoMode: TextInput.Password
            placeholderText: Translation.tr("Vault passphrase")
            onAccepted: {
                if (text.length === 0) return;
                Pigeon.unlock(text);
                text = "";
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: unlockState.error.length > 0
            color: Appearance.m3colors.m3error
            text: unlockState.error
        }

        QtObject {
            id: unlockState
            property string error: ""
        }

        Connections {
            target: Pigeon

            function onUnlockFailed(error) {
                unlockState.error = error;
            }

            function onUnlockSucceeded() {
                unlockState.error = "";
            }
        }

        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 40
            buttonRadius: Appearance.rounding.normal
            materialIcon: "settings"
            mainText: Translation.tr("Mail settings")
            onClicked: {
                GlobalStates.settingsPage = "Mail";
                GlobalStates.settingsOpen = true;
            }
        }
    }

    // ---- the mailbox ----

    RowLayout {
        anchors.fill: parent
        spacing: 10
        visible: root.ready

        DashCard {
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            title: Translation.tr("Folders")
            icon: "folder"

            headerTrailing: RippleButton {
                implicitHeight: 26
                implicitWidth: 26
                buttonRadius: Appearance.rounding.full
                onClicked: Pigeon.sync(Pigeon.currentAccount)

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1

                    RotationAnimator on rotation {
                        running: Pigeon.syncStatus === "syncing" || Pigeon.syncStatus === "connecting"
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1400
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                StyledComboBox {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    visible: Pigeon.accounts.length > 1
                    model: Pigeon.accounts.map(a => a.display_name)
                    currentIndex: Math.max(0, Pigeon.accounts.findIndex(a => a.name === Pigeon.currentAccount))
                    onActivated: index => {
                        const account = Pigeon.accounts[index];
                        if (!account) return;
                        const inbox = Pigeon.folders.find(f => f.account === account.name && f.role === "inbox")
                            ?? Pigeon.folders.find(f => f.account === account.name);
                        if (inbox) Pigeon.openFolder(account.name, inbox.name);
                    }
                }

                StyledListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2
                    animateAppearance: false
                    clip: true

                    model: Pigeon.folders.filter(f => f.account === Pigeon.currentAccount && f.selectable)

                    delegate: RippleButton {
                        id: folderRow
                        required property var modelData
                        readonly property bool current: modelData.name === Pigeon.currentFolder

                        width: ListView.view.width
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.small
                        toggled: current
                        onClicked: Pigeon.openFolder(modelData.account, modelData.name)

                        contentItem: RowLayout {
                            spacing: 8

                            MaterialSymbol {
                                Layout.leftMargin: 8
                                text: folderRow.modelData.icon
                                iconSize: Appearance.font.pixelSize.normal
                                color: folderRow.current ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: folderRow.modelData.display
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: folderRow.current ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                Layout.rightMargin: 8
                                visible: folderRow.modelData.unread > 0
                                text: folderRow.modelData.unread
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: folderRow.current ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3primary
                            }
                        }
                    }
                }
            }
        }

        DashCard {
            Layout.preferredWidth: 330
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    ToolbarTextField {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        implicitHeight: 36
                        placeholderText: Translation.tr("Filter mail…")
                        onTextChanged: root.search = text
                    }

                    RippleButtonWithIcon {
                        Layout.preferredHeight: 36
                        buttonRadius: Appearance.rounding.normal
                        toggled: root.composing
                        materialIcon: "edit"
                        mainText: Translation.tr("New")
                        onClicked: {
                            root.openedMessage = null;
                            root.composing = true;
                            composer.replyTo = null;
                            composer.reset();
                            composer.focusFirstEmpty();
                        }
                    }
                }

                MailMessageList {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    messages: root.visibleMessages
                    onMessageOpened: message => {
                        root.composing = false;
                        root.openedMessage = message;
                    }
                }
            }
        }

        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MailCompose {
                id: composer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: root.composing
                onFinished: root.composing = false
            }

            MailReader {
                anchors.fill: parent
                visible: !root.composing && root.openedMessage !== null
                message: root.openedMessage
                onClosed: root.openedMessage = null
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 8
                visible: !root.composing && root.openedMessage === null

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "drafts"
                    iconSize: 48
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Appearance.colors.colSubtext
                    text: Translation.tr("Pick a message to read it")
                }
            }
        }
    }
}
