import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Record button that turns into a live timer while recording.
// Click: start/stop · Right click: options (or discard while recording)
RippleButton {
    id: root
    property bool vertical: Config.options.bar.vertical

    implicitWidth: vertical ? 22 : content.implicitWidth + 12
    implicitHeight: vertical ? content.implicitHeight + 8 : 22
    buttonRadius: Appearance.rounding.full
    colBackground: Recorder.busy ? Appearance.colors.colErrorContainer : "transparent"
    colBackgroundHover: Recorder.busy ? Appearance.colors.colErrorContainerHover : Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active

    onPressed: Recorder.toggle()
    altAction: () => { if (Recorder.recording) Recorder.discard(); else GlobalStates.recorderOpen = true; }

    GridLayout {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        rowSpacing: 0
        columnSpacing: 4
        MaterialSymbol {
            Layout.alignment: Qt.AlignCenter
            text: Recorder.recording ? "stop_circle" : Recorder.busy ? "timer" : "screen_record"
            fill: Recorder.busy ? 1 : 0
            iconSize: 17
            color: Recorder.busy ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer0
        }
        StyledText {
            Layout.alignment: Qt.AlignCenter
            visible: Recorder.busy && !root.vertical
            text: Recorder.state === "countdown" ? Recorder.countdownLeft : Recorder.elapsedText
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.family: Appearance.font.family.numbers
            color: Appearance.colors.colOnErrorContainer
        }
    }
    StyledToolTip {
        text: Recorder.recording ? Translation.tr("Recording %1 · click to stop · right-click to discard").arg(Recorder.elapsedText)
            : Translation.tr("Record screen · right-click for options")
    }
}
