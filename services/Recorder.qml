pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

/**
 * Screen recorder (inspired by Brain_Shell's recorder popup).
 * state: "idle" | "selecting" | "countdown" | "recording"
 * IPC: qs -c taloshell ipc call recorder <toggle|start|stop|discard|panel>
 */
Singleton {
    id: root

    readonly property var cfg: Config.options.screenRecord
    readonly property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/videos/talos-record.sh`)

    property string state: "idle"
    readonly property bool recording: state === "recording"
    readonly property bool busy: state !== "idle"
    property int elapsed: 0
    property int countdownLeft: 0
    property string currentFile: ""
    property string geometry: ""
    property string lastFile: ""
    property list<string> history: [] // most recent first

    readonly property string elapsedText: {
        const m = Math.floor(root.elapsed / 60), s = root.elapsed % 60;
        return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    }
    readonly property var backends: [
        { id: "wf", name: "wf-recorder", binary: "wf-recorder" },
        { id: "gsr", name: "GPU Screen Recorder", binary: "gpu-screen-recorder" },
        { id: "wlsr", name: "wl-screenrec", binary: "wl-screenrec" },
    ]

    function fileName() {
        const ext = root.cfg.format;
        return `${root.cfg.savePath}/Recording_${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm.ss")}.${ext}`;
    }

    // Entry point: select target (if needed) -> countdown -> record
    function start() {
        if (root.busy) return;
        GlobalStates.recorderOpen = false;
        root.geometry = "";
        if (root.cfg.target === "region") {
            root.state = "selecting";
            selectProc.command = ["slurp", "-d"];
            selectProc.running = true;
        } else if (root.cfg.target === "window") {
            root.state = "selecting";
            selectProc.command = ["bash", "-c", `hyprctl clients -j | jq -r --argjson ws "$(hyprctl activeworkspace -j | jq .id)" '.[] | select(.workspace.id == $ws) | "\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"' | slurp -r`];
            selectProc.running = true;
        } else {
            root.beginCountdown();
        }
    }

    function beginCountdown() {
        if (root.cfg.countdown > 0) {
            root.countdownLeft = root.cfg.countdown;
            root.state = "countdown";
            countdownTimer.restart();
        } else {
            root.launch();
        }
    }

    function launch() {
        root.currentFile = root.fileName();
        const args = ["bash", root.scriptPath, "--out", root.currentFile, "--backend", root.cfg.backend,
            "--audio", root.cfg.audio, "--fps", String(root.cfg.fps), "--codec", root.cfg.codec,
            "--format", root.cfg.format, "--cursor", root.cfg.showCursor ? "1" : "0"];
        if (root.geometry.length > 0) args.push("--geometry", root.geometry);
        else {
            const mon = HyprlandData.monitors.find(m => m.focused);
            if (mon) args.push("--output", mon.name);
        }
        recordProc.command = args;
        root.elapsed = 0;
        root.state = "recording";
        recordProc.running = true;
    }

    function stop() {
        if (root.state === "countdown" || root.state === "selecting") {
            countdownTimer.stop();
            selectProc.running = false;
            root.state = "idle";
            return;
        }
        if (root.recording) recordProc.signal(15);
    }

    function discard() {
        if (!root.recording) { root.stop(); return; }
        Quickshell.execDetached(["touch", `${root.currentFile}.discard`]);
        discardDelay.restart();
    }

    function toggle() {
        if (root.busy) root.stop();
        else root.start();
    }

    function openFolder() { Qt.openUrlExternally(`file://${root.cfg.savePath}`); }

    Timer {
        id: discardDelay
        interval: 150
        onTriggered: recordProc.signal(15)
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdownLeft--;
            if (root.countdownLeft <= 0) {
                stop();
                root.launch();
            }
        }
    }

    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.elapsed++
    }

    Process {
        id: selectProc
        stdout: StdioCollector {
            onStreamFinished: {
                const g = text.trim();
                if (root.state !== "selecting") return;
                if (g.length === 0) { root.state = "idle"; return; } // cancelled
                root.geometry = g;
                root.beginCountdown();
            }
        }
    }

    Process {
        id: recordProc
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("saved ")) {
                    const path = line.slice(6);
                    root.lastFile = path;
                    root.history = [path, ...root.history.filter(h => h !== path)].slice(0, 10);
                    Quickshell.execDetached(["bash", "-c",
                        `a=$(notify-send -a Recorder -i media-record "${Translation.tr("Recording saved")}" "$(basename '${path}')" -A open="${Translation.tr("Open")}" -A folder="${Translation.tr("Show in folder")}" -A copy="${Translation.tr("Copy path")}");
                         case "$a" in open) xdg-open '${path}';; folder) xdg-open "$(dirname '${path}')";; copy) wl-copy '${path}';; esac`]);
                } else if (line === "discarded") {
                    Quickshell.execDetached(["notify-send", "-a", "Recorder", Translation.tr("Recording discarded")]);
                } else if (line === "failed") {
                    Quickshell.execDetached(["notify-send", "-a", "Recorder", "-u", "critical", Translation.tr("Recording failed"), Translation.tr("Check that %1 is installed").arg(root.backends.find(b => b.id === root.cfg.backend)?.binary ?? "the recorder")]);
                }
            }
        }
        onExited: root.state = "idle"
    }

    IpcHandler {
        target: "recorder"
        function toggle(): void { root.toggle(); }
        function start(): void { root.start(); }
        function stop(): void { root.stop(); }
        function discard(): void { root.discard(); }
        function panel(): void { GlobalStates.recorderOpen = !GlobalStates.recorderOpen; }
    }
}
