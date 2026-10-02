import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Adds a pigeon account without touching a terminal: the address is looked up
 * against the provider tables, both servers are logged into for real, and only
 * then is anything written.
 */
ColumnLayout {
    id: root
    property bool open: false
    property string message: ""
    property bool busy: false
    property var testResult: null
    property string detectedSource: ""

    readonly property bool complete: emailField.text.includes("@")
        && imapHost.text.length > 0
        && smtpHost.text.length > 0

    spacing: 8

    function reset() {
        emailField.text = "";
        nameField.text = "";
        passwordField.text = "";
        imapHost.text = "";
        imapPort.text = "993";
        smtpHost.text = "";
        smtpPort.text = "587";
        imapSecurity.currentIndex = 0;
        smtpSecurity.currentIndex = 1;
        root.message = "";
        root.testResult = null;
        root.detectedSource = "";
    }

    function detect() {
        if (!emailField.text.includes("@")) {
            root.message = Translation.tr("Enter a full email address first.");
            return;
        }
        root.busy = true;
        root.message = Translation.tr("Looking up the provider…");
        Pigeon.autoconfig(emailField.text.trim(), response => {
            root.busy = false;
            if (!response.ok) {
                root.message = response.error ?? "";
                return;
            }
            const found = response.result;
            imapHost.text = found.imap.host;
            imapPort.text = String(found.imap.port);
            imapSecurity.currentIndex = imapSecurity.indexOfSecurity(found.imap.security);
            smtpHost.text = found.smtp.host;
            smtpPort.text = String(found.smtp.port);
            smtpSecurity.currentIndex = smtpSecurity.indexOfSecurity(found.smtp.security);
            userField.text = found.user;
            root.detectedSource = found.source;
            root.message = found.oauth
                ? Translation.tr("Found settings from %1. This provider wants OAuth2 — finish signing in with `pigeon auth login` after saving.").arg(found.source)
                : Translation.tr("Found settings from %1.").arg(found.source);
        });
    }

    function spec() {
        return {
            email: emailField.text.trim(),
            displayName: nameField.text.trim(),
            password: passwordField.text,
            imap: {
                host: imapHost.text.trim(),
                port: parseInt(imapPort.text) || 993,
                security: imapSecurity.securityValue(),
                user: userField.text.trim().length > 0 ? userField.text.trim() : emailField.text.trim()
            },
            smtp: {
                host: smtpHost.text.trim(),
                port: parseInt(smtpPort.text) || 587,
                security: smtpSecurity.securityValue(),
                user: userField.text.trim().length > 0 ? userField.text.trim() : emailField.text.trim()
            }
        };
    }

    function test() {
        root.busy = true;
        root.testResult = null;
        root.message = Translation.tr("Signing in…");
        Pigeon.testAccount(root.spec(), response => {
            root.busy = false;
            if (!response.ok) {
                root.message = response.error ?? "";
                return;
            }
            root.testResult = response.result;
            root.message = response.result.ok
                ? Translation.tr("Both servers accepted these settings.")
                : Translation.tr("Something was refused — see below. You can still save and fix it later.");
        });
    }

    function save() {
        root.busy = true;
        root.message = Translation.tr("Saving…");
        Pigeon.addAccount(root.spec(), response => {
            root.busy = false;
            if (!response.ok) {
                root.message = response.error ?? "";
                return;
            }
            root.reset();
            root.open = false;
        });
    }

    RippleButtonWithIcon {
        Layout.leftMargin: 8
        Layout.preferredHeight: 40
        buttonRadius: Appearance.rounding.normal
        materialIcon: root.open ? "close" : "person_add"
        mainText: root.open ? Translation.tr("Cancel") : Translation.tr("Add account")
        onClicked: {
            root.open = !root.open;
            if (!root.open) root.reset();
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        visible: root.open
        implicitHeight: form.implicitHeight + 20
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        ColumnLayout {
            id: form
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            MaterialTextField {
                id: emailField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Email address")
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                onEditingFinished: {
                    if (imapHost.text.length === 0 && text.includes("@")) root.detect();
                }
            }

            MaterialTextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Your name (shown to recipients)")
            }

            MaterialTextField {
                id: passwordField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: Translation.tr("Password or app password")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButtonWithIcon {
                    Layout.preferredHeight: 36
                    buttonRadius: Appearance.rounding.normal
                    materialIcon: "travel_explore"
                    mainText: Translation.tr("Detect servers")
                    enabled: !root.busy
                    onClicked: root.detect()
                }
                Item {
                    Layout.fillWidth: true
                }
                StyledText {
                    visible: root.detectedSource.length > 0
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: root.detectedSource
                }
            }

            StyledText {
                Layout.topMargin: 4
                text: Translation.tr("Incoming (IMAP)")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextField {
                    id: imapHost
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("imap.example.org")
                }
                MaterialTextField {
                    id: imapPort
                    Layout.preferredWidth: 80
                    text: "993"
                    placeholderText: Translation.tr("Port")
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator {
                        bottom: 1
                        top: 65535
                    }
                }
                SecurityBox {
                    id: imapSecurity
                    onActivated: imapPort.text = String(imapSecurity.portFor(993, 143))
                }
            }

            StyledText {
                Layout.topMargin: 4
                text: Translation.tr("Outgoing (SMTP)")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextField {
                    id: smtpHost
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("smtp.example.org")
                }
                MaterialTextField {
                    id: smtpPort
                    Layout.preferredWidth: 80
                    text: "587"
                    placeholderText: Translation.tr("Port")
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator {
                        bottom: 1
                        top: 65535
                    }
                }
                SecurityBox {
                    id: smtpSecurity
                    currentIndex: 1
                    onActivated: smtpPort.text = String(smtpSecurity.portFor(465, 587))
                }
            }

            MaterialTextField {
                id: userField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Username (usually the address)")
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: root.message.length > 0
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: root.message
            }

            Repeater {
                model: root.testResult
                    ? [
                        { label: Translation.tr("IMAP"), result: root.testResult.imap },
                        { label: Translation.tr("SMTP"), result: root.testResult.smtp }
                    ]
                    : []

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: modelData.result.ok ? "check_circle" : "error"
                        iconSize: Appearance.font.pixelSize.normal
                        color: modelData.result.ok ? Appearance.colors.colSubtext : Appearance.m3colors.m3error
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        text: modelData.result.ok
                            ? `${modelData.label}: ${Translation.tr("signed in")}`
                            : `${modelData.label}: ${modelData.result.error}`
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                RippleButtonWithIcon {
                    Layout.preferredHeight: 36
                    buttonRadius: Appearance.rounding.normal
                    materialIcon: "network_check"
                    mainText: Translation.tr("Test")
                    enabled: root.complete && !root.busy
                    onClicked: root.test()
                }
                Item {
                    Layout.fillWidth: true
                }
                RippleButtonWithIcon {
                    Layout.preferredHeight: 36
                    buttonRadius: Appearance.rounding.normal
                    toggled: true
                    materialIcon: "save"
                    mainText: Translation.tr("Save account")
                    enabled: root.complete && !root.busy
                    onClicked: root.save()
                }
            }
        }
    }

    component SecurityBox: StyledComboBox {
        readonly property var values: ["tls", "starttls", "none"]
        model: [Translation.tr("TLS"), Translation.tr("STARTTLS"), Translation.tr("None")]
        Layout.fillWidth: false
        Layout.preferredWidth: 130

        function securityValue() {
            return values[Math.max(0, Math.min(currentIndex, values.length - 1))];
        }

        function indexOfSecurity(name) {
            const found = values.indexOf(name);
            return found >= 0 ? found : 0;
        }

        function portFor(tlsPort, plainPort) {
            return securityValue() === "tls" ? tlsPort : plainPort;
        }
    }
}
