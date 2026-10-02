pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root
    property var item: null
    readonly property var p: item?.preview ?? ({ kind: "default" })

    radius: Appearance.rounding.large
    color: Appearance.colors.colLayer1
    clip: true

    StyledFlickable {
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: col.implicitHeight
        clip: true

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 10

            // ---- Visual header per kind ----
            Loader {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                sourceComponent: {
                    switch (root.p.kind) {
                        case "app": return appHeader;
                        case "image": return imageHeader;
                        case "clipImage": return clipImageHeader;
                        case "theme": return themeHeader;
                        case "look": return lookHeader;
                        case "calc": return calcHeader;
                        case "emoji": return emojiHeader;
                        default: return iconHeader;
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.p.kind !== "calc" && root.p.kind !== "emoji"
                text: root.item?.title ?? ""
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.p.kind === "app" ? (root.p.description || root.p.generic || "") : (root.item?.subtitle ?? "")
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            // Categories
            Flow {
                Layout.fillWidth: true
                visible: (root.p.categories ?? []).length > 0
                spacing: 4
                Repeater {
                    model: (root.p.categories ?? []).slice(0, 6)
                    delegate: Rectangle {
                        required property string modelData
                        implicitHeight: 22
                        implicitWidth: catText.implicitWidth + 14
                        radius: Math.min(height / 2, Appearance.rounding.full)
                        color: Appearance.colors.colSecondaryContainer
                        StyledText { id: catText; anchors.centerIn: parent; text: modelData; font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colOnSecondaryContainer }
                    }
                }
            }

            // Body text / command
            Rectangle {
                Layout.fillWidth: true
                visible: bodyText.text.length > 0
                implicitHeight: bodyText.implicitHeight + 16
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                StyledText {
                    id: bodyText
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    text: root.p.kind === "app" ? (root.p.command ?? "")
                        : root.p.kind === "window" ? `${root.p.cls}\n${Translation.tr("Workspace")} ${root.p.workspace} · ${root.p.size}${root.p.floating ? " · " + Translation.tr("floating") : ""}`
                        : root.p.kind === "file" ? root.p.path
                        : (root.p.body ?? "")
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 14
                    elide: Text.ElideRight
                    font.family: root.p.mono || root.p.kind === "app" || root.p.kind === "file" ? Appearance.font.family.monospace : Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                }
            }

            // Actions
            ColumnLayout {
                Layout.fillWidth: true
                visible: (root.item?.actions ?? []).length > 0
                spacing: 2
                StyledText {
                    text: Translation.tr("Actions")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
                Repeater {
                    model: root.item?.actions ?? []
                    delegate: RippleButton {
                        id: actionButton
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 34
                        buttonRadius: Appearance.rounding.small
                        onClicked: {
                            if (!modelData.keepOpen) TalosLauncher.close();
                            modelData.run();
                        }
                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            MaterialSymbol { text: actionButton.modelData.icon ?? "bolt"; iconSize: 18; color: Appearance.colors.colPrimary }
                            StyledText { Layout.fillWidth: true; text: actionButton.modelData.name; elide: Text.ElideRight; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                            StyledText {
                                visible: actionButton.index < 9
                                text: actionButton.index === 0 ? "Ctrl ↵" : `Alt ${actionButton.index + 1}`
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.monospace
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- headers
    Component {
        id: iconHeader
        Item {
            implicitHeight: 84
            LauncherIcon { anchors.centerIn: parent; item: root.item; size: 72 }
        }
    }
    Component {
        id: appHeader
        Item {
            implicitHeight: 108
            IconImage {
                anchors.centerIn: parent
                implicitSize: 96
                source: Quickshell.iconPath(root.p.icon ?? "", "application-x-executable")
            }
        }
    }
    Component {
        id: imageHeader
        Rectangle {
            implicitHeight: 160
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            clip: true
            Image {
                anchors.fill: parent
                source: `file://${root.p.path}`
                sourceSize: Qt.size(560, 320)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
    }
    Component {
        id: clipImageHeader
        Item {
            implicitHeight: 170
            CliphistImage {
                anchors.centerIn: parent
                entry: root.p.entry
                maxWidth: parent.width
                maxHeight: 170
            }
        }
    }
    Component {
        id: themeHeader
        Item {
            implicitHeight: themeCard.implicitHeight
            ThemeCard {
                id: themeCard
                width: parent.width
                theme: root.p.theme
                selected: ThemeEngine.presetActive && ThemeEngine.currentId === root.p.theme?.id
                favorite: ThemeEngine.isFavorite(root.p.theme?.id)
                onClicked: TalosLauncher.activate(root.item)
                onFavoriteToggled: ThemeEngine.toggleFavorite(root.p.theme.id)
            }
        }
    }
    Component {
        id: lookHeader
        Item {
            implicitHeight: lookCard.implicitHeight
            LookCard {
                id: lookCard
                width: parent.width
                look: root.p.look
                selected: LookEngine.currentId === root.p.look?.id
                onClicked: TalosLauncher.activate(root.item)
            }
        }
    }
    Component {
        id: calcHeader
        ColumnLayout {
            spacing: 4
            StyledText {
                Layout.fillWidth: true
                text: root.p.expression ?? ""
                wrapMode: Text.WrapAnywhere
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                text: root.p.result ?? ""
                wrapMode: Text.WrapAnywhere
                font.family: Appearance.font.family.numbers
                font.pixelSize: 34
                font.weight: Font.DemiBold
                color: Appearance.colors.colPrimary
            }
        }
    }
    Component {
        id: emojiHeader
        ColumnLayout {
            spacing: 4
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.p.glyph ?? ""
                font.pixelSize: 96
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.p.name ?? ""
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
        }
    }
}
