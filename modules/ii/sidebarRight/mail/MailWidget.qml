pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Mail tab for the right sidebar, backed by the pigeon daemon.
 *
 * Shows whichever of four states applies: mail switched off, no daemon, a locked
 * vault, or the mailbox itself. Reading a message swaps the list for a reader in
 * place, so the widget never grows past its tab.
 */
Item {
    id: root

    property var openedMessage: null
    property bool composing: false
    readonly property string search: toolbar.searchText

    readonly property var visibleMessages: {
        if (root.search.trim().length === 0) return Pigeon.messages;
        const needle = root.search.trim().toLowerCase();
        return Pigeon.messages.filter(m =>
            (m.subject ?? "").toLowerCase().includes(needle)
            || (m.sender ?? "").toLowerCase().includes(needle)
            || (m.sender_email ?? "").toLowerCase().includes(needle)
            || (m.preview ?? "").toLowerCase().includes(needle));
    }

    function close() {
        root.openedMessage = null;
        root.composing = false;
    }

    Connections {
        target: Pigeon
        function onLockedChanged() {
            root.openedMessage = null;
        }
    }

    // ---- mail off, or no daemon ----

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 40
        spacing: 10
        visible: !Config.options.mail.enable || !Pigeon.connected

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: Config.options.mail.enable ? "cloud_off" : "mail_off"
            iconSize: 55
            color: Appearance.colors.colSubtext
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: {
                if (!Config.options.mail.enable) return Translation.tr("Mail is switched off");
                if (Pigeon.daemonUnavailable) return Pigeon.lastError;
                return Translation.tr("Waiting for the pigeon daemon on\n%1").arg(Pigeon.socketPath);
            }
        }

        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 36
            buttonRadius: Appearance.rounding.normal
            materialIcon: "settings"
            mainText: Translation.tr("Open mail settings")
            onClicked: {
                GlobalStates.settingsPage = "Mail";
                GlobalStates.settingsOpen = true;
            }
        }
    }

    // ---- locked vault ----

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 40
        spacing: 10
        visible: Config.options.mail.enable && Pigeon.connected && Pigeon.locked

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "lock"
            iconSize: 55
            color: Appearance.colors.colSubtext
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            text: Pigeon.vaultExists
                ? Translation.tr("Your mail is encrypted on this machine.")
                : Translation.tr("No vault yet — set one up in mail settings.")
        }

        MaterialTextField {
            id: passphraseField
            Layout.fillWidth: true
            visible: Pigeon.vaultExists
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
            visible: text.length > 0
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.m3colors.m3error
            text: lockState.error
        }

        QtObject {
            id: lockState
            property string error: ""
        }

        Connections {
            target: Pigeon
            function onUnlockFailed(error) {
                lockState.error = error;
            }
            function onUnlockSucceeded() {
                lockState.error = "";
            }
        }
    }

    // ---- the mailbox ----

    ColumnLayout {
        anchors.fill: parent
        spacing: 6
        visible: Config.options.mail.enable && Pigeon.connected && !Pigeon.locked

        MailToolbar {
            id: toolbar
            Layout.fillWidth: true
            reading: root.openedMessage !== null || root.composing
            onBackRequested: root.close()
            onComposeRequested: {
                root.openedMessage = null;
                root.composing = true;
                composer.replyTo = null;
                composer.reset();
                composer.focusFirstEmpty();
            }
        }

        MailCompose {
            id: composer
            Layout.fillWidth: true
            visible: root.composing
            onFinished: root.composing = false
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.composing
        }

        MailFolderStrip {
            Layout.fillWidth: true
            visible: !root.composing && root.openedMessage === null && Pigeon.accounts.length > 0
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 20
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: Pigeon.accounts.length === 0
            color: Appearance.colors.colSubtext
            text: Translation.tr("No mail account yet. Add one in mail settings.")
        }

        MailMessageList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.composing && root.openedMessage === null && Pigeon.accounts.length > 0
            messages: root.visibleMessages
            onMessageOpened: message => root.openedMessage = message
        }

        MailReader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.composing && root.openedMessage !== null
            message: root.openedMessage
            onClosed: root.close()
        }
    }
}
