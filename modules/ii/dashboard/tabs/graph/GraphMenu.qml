pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * The "+" menu: add rows, open examples and saved graphs, save the current
 * graph, copy all expressions, clear.
 */
Rectangle {
    id: root
    signal addRequested(string kind)
    signal closeRequested()
    property string section: "" // "", "examples", "saved"

    implicitWidth: 230
    implicitHeight: Math.min(flick.contentHeight + 12, maxHeight)
    property real maxHeight: 460
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer3Base
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    clip: true
    onVisibleChanged: if (!visible) section = ""

    MouseArea { anchors.fill: parent }

    StyledFlickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 6
        contentHeight: col.implicitHeight
        ColumnLayout {
            id: col
            width: flick.width
            spacing: 0

            Item_ { symbol: "function"; label: Translation.tr("Expression"); onClicked: root.addRequested("expr") }
            Item_ { symbol: "table_chart"; label: Translation.tr("Table"); onClicked: root.addRequested("table") }
            Item_ { symbol: "notes"; label: Translation.tr("Note"); onClicked: root.addRequested("note") }
            Separator {}

            Item_ {
                symbol: "auto_awesome"
                label: Translation.tr("Examples")
                trailing: root.section === "examples" ? "expand_less" : "expand_more"
                onClicked: root.section = root.section === "examples" ? "" : "examples"
            }
            Repeater {
                model: root.section === "examples" ? Metis.examples : []
                delegate: Item_ {
                    required property var modelData
                    indent: true
                    label: modelData.name
                    onClicked: { Metis.openExample(modelData); root.closeRequested(); }
                }
            }

            Item_ {
                symbol: "folder_open"
                label: Translation.tr("Saved graphs")
                trailing: root.section === "saved" ? "expand_less" : "expand_more"
                onClicked: root.section = root.section === "saved" ? "" : "saved"
            }
            ColumnLayout {
                visible: root.section === "saved"
                Layout.fillWidth: true
                spacing: 0
                Repeater {
                    model: Object.keys(Metis.saved).sort()
                    delegate: Item_ {
                        required property string modelData
                        indent: true
                        label: modelData
                        trailing: "close"
                        onClicked: { Metis.openSaved(modelData); root.closeRequested(); }
                        onTrailingClicked: Metis.deleteSaved(modelData)
                    }
                }
                StyledText {
                    visible: Object.keys(Metis.saved).length === 0
                    Layout.leftMargin: 36
                    Layout.topMargin: 2
                    Layout.bottomMargin: 4
                    text: Translation.tr("Nothing saved yet")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
                // save current
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 30
                    Layout.rightMargin: 4
                    Layout.topMargin: 2
                    Layout.bottomMargin: 4
                    spacing: 4
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2Base
                        border.width: nameInput.activeFocus ? 1 : 0
                        border.color: Appearance.colors.colPrimary
                        TextInput {
                            id: nameInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                            onAccepted: saveButton.clicked()
                            StyledText {
                                visible: nameInput.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: Translation.tr("Save current as…")
                                font: nameInput.font
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                    RippleButton {
                        id: saveButton
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colPrimary
                        enabled: nameInput.text.trim().length > 0
                        opacity: enabled ? 1 : 0.5
                        onClicked: {
                            Metis.saveAs(nameInput.text);
                            nameInput.text = "";
                        }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "save"; iconSize: 16; color: Appearance.colors.colOnPrimary }
                    }
                }
            }
            Separator {}
            Item_ {
                symbol: "content_copy"
                label: Translation.tr("Copy all expressions")
                onClicked: { Metis.copyExpressions(); root.closeRequested(); }
            }
            Item_ {
                symbol: "delete_sweep"
                label: Translation.tr("Clear all")
                danger: true
                onClicked: { Metis.clearAll(); root.closeRequested(); }
            }
        }
    }

    component Separator: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Appearance.colors.colOutlineVariant
    }
    component Item_: RippleButton {
        id: mi
        property string symbol
        property string label
        property string trailing
        property bool indent: false
        property bool danger: false
        signal trailingClicked()
        Layout.fillWidth: true
        implicitHeight: 32
        buttonRadius: Appearance.rounding.small
        contentItem: RowLayout {
            spacing: 10
            MaterialSymbol {
                Layout.leftMargin: mi.indent ? 30 : 8
                visible: mi.symbol.length > 0
                text: mi.symbol
                iconSize: 18
                color: mi.danger ? Appearance.colors.colError : Appearance.colors.colOnLayer3
            }
            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: mi.indent && mi.symbol.length === 0 ? 30 : 0
                text: mi.label
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: mi.danger ? Appearance.colors.colError : Appearance.colors.colOnLayer3
            }
            MaterialSymbol {
                visible: mi.trailing.length > 0
                Layout.rightMargin: 6
                text: mi.trailing
                iconSize: 16
                color: Appearance.colors.colSubtext
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: mi.trailing === "close"
                    onClicked: mi.trailingClicked()
                }
            }
        }
    }
}
