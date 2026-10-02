import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true
    bottomContentPadding: 15

    property var daemonGeneral: ({})

    function reloadDaemonSettings() {
        if (Pigeon.locked || !Pigeon.connected) return;
        Pigeon.daemonSettings(response => {
            if (response.ok) page.daemonGeneral = response.result.general ?? {};
        });
    }

    Connections {
        target: Pigeon
        function onLockedChanged() {
            page.reloadDaemonSettings();
        }
        function onConnectedChanged() {
            page.reloadDaemonSettings();
        }
    }

    Component.onCompleted: page.reloadDaemonSettings()

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "mail"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Mail")

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: {
                    if (Pigeon.connected)
                        return Translation.tr("Connected to pigeon %1 · %2").arg(Pigeon.version).arg(Pigeon.locked ? Translation.tr("locked") : Translation.tr("unlocked"));
                    if (Pigeon.daemonUnavailable)
                        return Pigeon.lastError;
                    return Translation.tr("The pigeon daemon is not answering on %1").arg(Pigeon.socketPath);
                }
            }

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "outgoing_mail"
                    text: Translation.tr("Enable mail")
                    checked: Config.options.mail.enable
                    onCheckedChanged: {
                        Config.options.mail.enable = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "play_circle"
                    text: Translation.tr("Start the daemon with the shell")
                    enabled: Config.options.mail.enable
                    checked: Config.options.mail.autostartDaemon
                    onCheckedChanged: {
                        Config.options.mail.autostartDaemon = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "notifications"
                    text: Translation.tr("Notify on new mail")
                    enabled: Config.options.mail.enable
                    checked: Config.options.mail.notifications
                    onCheckedChanged: {
                        Config.options.mail.notifications = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "mark_email_unread"
                    text: Translation.tr("Unread badge on the bar")
                    enabled: Config.options.mail.enable
                    checked: Config.options.mail.showBadge
                    onCheckedChanged: {
                        Config.options.mail.showBadge = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "html"
                    text: Translation.tr("Render HTML mail (remote images stay blocked)")
                    enabled: Config.options.mail.enable
                    checked: Config.options.mail.renderHtml
                    onCheckedChanged: {
                        Config.options.mail.renderHtml = checked;
                    }
                }
                ConfigSpinBox {
                    icon: "format_list_numbered"
                    text: Translation.tr("Messages to list")
                    value: Config.options.mail.listLimit
                    from: 10
                    to: 500
                    stepSize: 10
                    onValueChanged: {
                        Config.options.mail.listLimit = value;
                    }
                }
                ConfigTextArea {
                    id: socketField
                    Layout.fillWidth: true
                    fieldWidth: 250
                    buttonIcon: "cable"
                    text: Translation.tr("Socket path (empty uses the default)")
                    value: Config.options.mail.socketPath
                    onValueChanged: socketDebounce.restart()

                    Timer {
                        id: socketDebounce
                        interval: 600
                        onTriggered: {
                            Config.options.mail.socketPath = socketField.value;
                        }
                    }
                }
                ConfigTextArea {
                    id: commandField
                    Layout.fillWidth: true
                    fieldWidth: 250
                    buttonIcon: "terminal"
                    text: Translation.tr("Daemon command")
                    value: Config.options.mail.command
                    onValueChanged: commandDebounce.restart()

                    Timer {
                        id: commandDebounce
                        interval: 600
                        onTriggered: {
                            Config.options.mail.command = commandField.value;
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "lock"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Vault")

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Everything pigeon stores on this machine — messages, attachments and the search index — is encrypted with a key wrapped by this passphrase. It is never written anywhere.")
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 8
                visible: Pigeon.connected

                MaterialTextField {
                    id: passphraseField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: Pigeon.vaultExists
                        ? Translation.tr("Vault passphrase")
                        : Translation.tr("Choose a passphrase (8 characters or more)")
                    onAccepted: vaultButton.act()
                }

                MaterialTextField {
                    id: confirmField
                    Layout.fillWidth: true
                    visible: !Pigeon.vaultExists
                    echoMode: TextInput.Password
                    placeholderText: Translation.tr("Repeat the passphrase")
                    onAccepted: vaultButton.act()
                }

                StyledText {
                    id: vaultMessage
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    visible: text.length > 0
                    color: Appearance.m3colors.m3error
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButtonWithIcon {
                        id: vaultButton
                        Layout.preferredHeight: 40
                        buttonRadius: Appearance.rounding.normal
                        materialIcon: Pigeon.vaultExists ? "lock_open" : "enhanced_encryption"
                        mainText: Pigeon.vaultExists ? Translation.tr("Unlock") : Translation.tr("Create vault")
                        enabled: Pigeon.locked && passphraseField.text.length > 0

                        function act() {
                            if (!vaultButton.enabled) return;
                            vaultMessage.text = "";

                            if (Pigeon.vaultExists) {
                                Pigeon.unlock(passphraseField.text);
                                passphraseField.text = "";
                                return;
                            }

                            if (passphraseField.text !== confirmField.text) {
                                vaultMessage.text = Translation.tr("The two passphrases do not match.");
                                return;
                            }

                            const chosen = passphraseField.text;
                            Pigeon.createVault(chosen, response => {
                                if (!response.ok) {
                                    vaultMessage.text = response.error ?? "";
                                    return;
                                }
                                Pigeon.unlock(chosen);
                                passphraseField.text = "";
                                confirmField.text = "";
                            });
                        }

                        onClicked: vaultButton.act()
                    }

                    RippleButtonWithIcon {
                        Layout.preferredHeight: 40
                        buttonRadius: Appearance.rounding.normal
                        materialIcon: "lock"
                        mainText: Translation.tr("Lock")
                        enabled: !Pigeon.locked
                        onClicked: Pigeon.lock()
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Connections {
                    target: Pigeon
                    function onUnlockFailed(error) {
                        vaultMessage.text = error;
                    }
                    function onUnlockSucceeded() {
                        vaultMessage.text = "";
                    }
                }
            }
        }

        ContentSection {
            icon: "account_circle"
            shape: MaterialShape.Shape.Cookie6Sided
            title: Translation.tr("Accounts")

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                wrapMode: Text.Wrap
                visible: Pigeon.locked
                color: Appearance.colors.colSubtext
                text: Translation.tr("Unlock the vault to manage accounts.")
            }

            Repeater {
                model: Pigeon.locked ? [] : Pigeon.accounts

                MailAccountRow {
                    required property var modelData
                    Layout.fillWidth: true
                    account: modelData
                }
            }

            MailAccountForm {
                Layout.fillWidth: true
                visible: !Pigeon.locked
            }
        }

        ContentSection {
            icon: "sync"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Syncing")
            visible: !Pigeon.locked && Pigeon.connected

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "bolt"
                    text: Translation.tr("Push (IMAP IDLE)")
                    checked: page.daemonGeneral.idle ?? true
                    onCheckedChanged: {
                        if (checked === (page.daemonGeneral.idle ?? true)) return;
                        Pigeon.setDaemonSettings({ general: { idle: checked } }, () => page.reloadDaemonSettings());
                    }
                }
                ConfigSwitch {
                    buttonIcon: "download"
                    text: Translation.tr("Download whole messages for offline reading")
                    checked: page.daemonGeneral.downloadFullBodies ?? true
                    onCheckedChanged: {
                        if (checked === (page.daemonGeneral.downloadFullBodies ?? true)) return;
                        Pigeon.setDaemonSettings({ general: { downloadFullBodies: checked } }, () => page.reloadDaemonSettings());
                    }
                }
                ConfigSpinBox {
                    id: pollSpin
                    icon: "timer"
                    text: Translation.tr("Poll interval (s)")
                    value: page.daemonGeneral.pollIntervalSecs ?? 300
                    from: 30
                    to: 3600
                    stepSize: 30
                    onValueChanged: {
                        if (value === (page.daemonGeneral.pollIntervalSecs ?? 300)) return;
                        pollDebounce.restart();
                    }

                    Timer {
                        id: pollDebounce
                        interval: 700
                        onTriggered: {
                            Pigeon.setDaemonSettings({ general: { pollIntervalSecs: pollSpin.value } }, () => page.reloadDaemonSettings());
                        }
                    }
                }
                ConfigSpinBox {
                    id: attachSpin
                    icon: "attach_file"
                    text: Translation.tr("Attachment limit (MB)")
                    value: page.daemonGeneral.maxAttachmentMb ?? 25
                    from: 1
                    to: 200
                    stepSize: 1
                    onValueChanged: {
                        if (value === (page.daemonGeneral.maxAttachmentMb ?? 25)) return;
                        attachDebounce.restart();
                    }

                    Timer {
                        id: attachDebounce
                        interval: 700
                        onTriggered: {
                            Pigeon.setDaemonSettings({ general: { maxAttachmentMb: attachSpin.value } }, () => page.reloadDaemonSettings());
                        }
                    }
                }
                ConfigSpinBox {
                    id: cacheSpin
                    icon: "auto_delete"
                    text: Translation.tr("Keep message bodies for (days)")
                    value: page.daemonGeneral.bodyCacheDays ?? 90
                    from: 1
                    to: 3650
                    stepSize: 10
                    onValueChanged: {
                        if (value === (page.daemonGeneral.bodyCacheDays ?? 90)) return;
                        cacheDebounce.restart();
                    }

                    Timer {
                        id: cacheDebounce
                        interval: 700
                        onTriggered: {
                            Pigeon.setDaemonSettings({ general: { bodyCacheDays: cacheSpin.value } }, () => page.reloadDaemonSettings());
                        }
                    }
                }
            }
        }
    }
}
