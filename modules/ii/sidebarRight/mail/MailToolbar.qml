import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Account picker, search box and the sync/compose actions.
 */
RowLayout {
    id: root
    property bool reading: false
    readonly property string searchText: searchField.text

    signal backRequested
    signal composeRequested

    spacing: 6

    CircleUtilButton {
        visible: root.reading
        onClicked: root.backRequested()

        MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            text: "arrow_back"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }
    }

    StyledComboBox {
        Layout.fillWidth: false
        Layout.preferredWidth: 110
        implicitHeight: 32
        visible: !root.reading && Pigeon.accounts.length > 1
        model: Pigeon.accounts.map(a => a.display_name)
        currentIndex: Math.max(0, Pigeon.accounts.findIndex(a => a.name === Pigeon.currentAccount))
        onActivated: index => {
            const account = Pigeon.accounts[index];
            if (!account) return;
            const inbox = Pigeon.folders.find(f => f.account === account.name && f.role === "inbox")
                ?? Pigeon.folders.find(f => f.account === account.name);
            if (inbox) Pigeon.openFolder(account.name, inbox.name);
            else Pigeon.currentAccount = account.name;
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: !root.reading
        implicitHeight: 32
        radius: Appearance.rounding.full
        color: Appearance.colors.colLayer2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 6

            MaterialSymbol {
                text: "search"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }

            StyledTextInput {
                id: searchField
                Layout.fillWidth: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text.length === 0 && !searchField.activeFocus
                    text: Translation.tr("Filter")
                    color: Appearance.colors.colSubtext
                }
            }

            CircleUtilButton {
                visible: searchField.text.length > 0
                onClicked: searchField.clear()

                MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    text: "close"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }
            }
        }
    }

    StyledText {
        visible: !root.reading && Pigeon.unread > 0
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        text: Translation.tr("%1 unread").arg(Pigeon.unread)
    }

    CircleUtilButton {
        visible: !root.reading
        onClicked: root.composeRequested()

        MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            text: "edit"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }
    }

    CircleUtilButton {
        visible: !root.reading
        onClicked: Pigeon.sync(Pigeon.currentAccount)

        MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            text: Pigeon.syncStatus === "syncing" || Pigeon.syncStatus === "connecting" ? "sync" : "refresh"
            iconSize: Appearance.font.pixelSize.larger
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
}
