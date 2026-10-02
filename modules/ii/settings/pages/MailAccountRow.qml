import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * One configured pigeon account: its sync state, a password change and removal.
 */
Rectangle {
    id: root
    required property var account
    property bool expanded: false
    property string message: ""

    Layout.leftMargin: 8
    Layout.rightMargin: 8
    implicitHeight: layout.implicitHeight + 20
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialSymbol {
                text: root.account.enabled ? "account_circle" : "no_accounts"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnLayer2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.normal
                    text: root.account.display_name
                    color: Appearance.colors.colOnLayer2
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: `${root.account.email} · ${root.account.imap_host}`
                }
            }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.account.status === "watching" || root.account.status === "idle"
                    ? Appearance.colors.colSubtext
                    : Appearance.m3colors.m3error
                text: Pigeon.statuses[root.account.name] ?? root.account.status
            }

            CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.expanded = !root.expanded

                MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    text: root.expanded ? "expand_less" : "expand_more"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.expanded

            MaterialTextField {
                id: passwordField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: Translation.tr("New password for %1").arg(root.account.email)
                onAccepted: savePassword.click()
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: root.message.length > 0
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: root.message
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButtonWithIcon {
                    id: savePassword
                    Layout.preferredHeight: 36
                    buttonRadius: Appearance.rounding.normal
                    materialIcon: "key"
                    mainText: Translation.tr("Save password")
                    enabled: passwordField.text.length > 0

                    function click() {
                        if (!savePassword.enabled) return;
                        const secret = passwordField.text;
                        // One password normally covers both, and a separate SMTP
                        // credential is rare enough to be worth the extra call.
                        Pigeon.setPassword(root.account.name, "imap", secret, response => {
                            root.message = response.ok
                                ? Translation.tr("Stored in the %1.").arg(response.result.storedIn === "vault" ? Translation.tr("encrypted vault") : Translation.tr("system keyring"))
                                : (response.error ?? "");
                        });
                        Pigeon.setPassword(root.account.name, "smtp", secret);
                        passwordField.text = "";
                    }

                    onClicked: savePassword.click()
                }

                RippleButtonWithIcon {
                    Layout.preferredHeight: 36
                    buttonRadius: Appearance.rounding.normal
                    materialIcon: "sync"
                    mainText: Translation.tr("Sync now")
                    onClicked: Pigeon.sync(root.account.name)
                }

                Item {
                    Layout.fillWidth: true
                }

                RippleButtonWithIcon {
                    Layout.preferredHeight: 36
                    buttonRadius: Appearance.rounding.normal
                    colBackground: Appearance.colors.colLayer3
                    materialIcon: root.account.enabled ? "pause" : "play_arrow"
                    mainText: root.account.enabled ? Translation.tr("Disable") : Translation.tr("Enable")
                    onClicked: Pigeon.updateAccount(root.account.name, { enabled: !root.account.enabled })
                }

                RippleButtonWithIcon {
                    Layout.preferredHeight: 36
                    buttonRadius: Appearance.rounding.normal
                    materialIcon: confirmRemove.running ? "delete_forever" : "delete"
                    mainText: confirmRemove.running ? Translation.tr("Tap again") : Translation.tr("Remove")
                    onClicked: {
                        // Removing an account deletes its stored password, so it
                        // takes a second, deliberate press rather than a dialog.
                        if (!confirmRemove.running) {
                            confirmRemove.restart();
                            return;
                        }
                        confirmRemove.stop();
                        Pigeon.removeAccount(root.account.name, response => {
                            if (!response.ok) root.message = response.error ?? "";
                        });
                    }

                    Timer {
                        id: confirmRemove
                        interval: 4000
                    }
                }
            }
        }
    }
}
