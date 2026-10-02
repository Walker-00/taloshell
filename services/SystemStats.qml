pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Extra system statistics for the dashboard, gauges and desktop widgets:
 * GPU load/temp/VRAM, network throughput, per-core CPU, CPU frequency,
 * load average, uptime and top processes.
 *
 * Polling is reference counted so nothing runs while no UI shows it:
 *   Component.onCompleted: SystemStats.acquire()
 *   Component.onDestruction: SystemStats.release()
 */
Singleton {
    id: root

    property int consumers: 0
    readonly property bool active: consumers > 0
    property int interval: 1500
    readonly property int historyLength: 60

    function acquire() { root.consumers++; }
    function release() { root.consumers = Math.max(0, root.consumers - 1); }

    // ---------- Network ----------
    property string netInterface: ""
    property real netRxRate: 0 // bytes/s
    property real netTxRate: 0
    property real netRxTotal: 0 // bytes since boot
    property real netTxTotal: 0
    property list<real> netRxHistory: []
    property list<real> netTxHistory: []
    property real _prevRx: -1
    property real _prevTx: -1
    property double _prevNetTime: 0

    // ---------- CPU ----------
    property list<real> coreUsage: [] // 0..1 per core
    property var _prevCores: []
    property real cpuFreqGHz: 0
    property string cpuModel: ""
    property real loadAvg1: 0
    property real loadAvg5: 0
    property real loadAvg15: 0
    property real uptimeSeconds: 0

    // ---------- GPU ----------
    property string gpuVendor: "" // amd, nvidia, intel, ""
    property string gpuName: ""
    property string gpuCardPath: ""
    property real gpuUsage: 0 // 0..1 (intel: frequency ratio)
    property real gpuTemp: 0
    property real gpuVramUsed: 0 // MiB
    property real gpuVramTotal: 0
    property list<real> gpuHistory: []
    readonly property bool gpuAvailable: gpuVendor !== ""

    // ---------- Processes ----------
    property list<var> topProcesses: [] // {pid, name, cpu, mem}
    property string processSort: "cpu" // cpu | mem

    function formatBytes(bytes, perSecond = false) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        let v = bytes;
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
        return `${v.toFixed(v >= 100 || i === 0 ? 0 : 1)} ${units[i]}${perSecond ? "/s" : ""}`;
    }

    function formatUptime(seconds) {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor(seconds % 86400 / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        if (d > 0) return `${d}d ${h}h`;
        if (h > 0) return `${h}h ${m}m`;
        return `${m}m`;
    }

    function pushHistory(list, value) {
        const next = [...list, value];
        if (next.length > root.historyLength) next.shift();
        return next;
    }

    function killProcess(pid) {
        Quickshell.execDetached(["kill", String(pid)]);
    }

    Timer {
        running: root.active
        interval: root.interval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netFile.reload();
            statFile.reload();
            loadFile.reload();
            uptimeFile.reload();
            freqProc.running = true;
            if (root.gpuVendor !== "") gpuProc.running = true;
            procProc.running = true;
        }
    }

    // Network
    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0, bestIface = "", bestTraffic = -1;
            for (const line of text().split("\n").slice(2)) {
                const m = line.trim().match(/^([^:]+):\s*(.*)$/);
                if (!m) continue;
                const iface = m[1];
                if (iface === "lo" || iface.startsWith("veth") || iface.startsWith("docker") || iface.startsWith("br-")) continue;
                const f = m[2].trim().split(/\s+/).map(Number);
                rx += f[0]; tx += f[8];
                if (f[0] + f[8] > bestTraffic) { bestTraffic = f[0] + f[8]; bestIface = iface; }
            }
            const now = Date.now();
            if (root._prevRx >= 0) {
                const dt = Math.max(0.001, (now - root._prevNetTime) / 1000);
                root.netRxRate = Math.max(0, (rx - root._prevRx) / dt);
                root.netTxRate = Math.max(0, (tx - root._prevTx) / dt);
                root.netRxHistory = root.pushHistory(root.netRxHistory, root.netRxRate);
                root.netTxHistory = root.pushHistory(root.netTxHistory, root.netTxRate);
            }
            root._prevRx = rx; root._prevTx = tx; root._prevNetTime = now;
            root.netRxTotal = rx; root.netTxTotal = tx;
            root.netInterface = bestIface;
        }
    }

    // Per-core CPU
    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const cores = [];
            for (const line of text().split("\n")) {
                if (!/^cpu\d+ /.test(line)) continue;
                const f = line.trim().split(/\s+/).slice(1).map(Number);
                const idle = f[3] + (f[4] ?? 0);
                const total = f.reduce((a, b) => a + b, 0);
                cores.push({ idle, total });
            }
            const usage = cores.map((c, i) => {
                const p = root._prevCores[i];
                if (!p) return 0;
                const dt = c.total - p.total;
                return dt > 0 ? Math.max(0, Math.min(1, 1 - (c.idle - p.idle) / dt)) : 0;
            });
            root._prevCores = cores;
            root.coreUsage = usage;
        }
    }

    FileView {
        id: loadFile
        path: "/proc/loadavg"
        onLoaded: {
            const f = text().trim().split(/\s+/);
            root.loadAvg1 = parseFloat(f[0]); root.loadAvg5 = parseFloat(f[1]); root.loadAvg15 = parseFloat(f[2]);
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptimeSeconds = parseFloat(text().split(" ")[0])
    }

    Process {
        id: freqProc
        command: ["bash", "-c", "awk -F: '/cpu MHz/ {s+=$2; n++} END {if (n) printf \"%.0f\", s/n}' /proc/cpuinfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const mhz = parseFloat(text);
                if (!isNaN(mhz)) root.cpuFreqGHz = mhz / 1000;
            }
        }
    }

    // GPU detection (once)
    Process {
        running: true
        command: ["bash", "-c", `
            if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
                echo "nvidia"; nvidia-smi --query-gpu=name --format=csv,noheader | head -1; echo ""; exit 0
            fi
            for c in /sys/class/drm/card[0-9]; do
                [ -f "$c/device/gpu_busy_percent" ] && { echo "amd"; cat "$c/device/product_name" 2>/dev/null || echo "AMD GPU"; echo "$c"; exit 0; }
            done
            for c in /sys/class/drm/card[0-9]; do
                [ -f "$c/gt_cur_freq_mhz" ] && { echo "intel"; lspci 2>/dev/null | grep -iE 'vga|3d' | grep -i intel | head -1 | sed 's/.*: //; s/Intel Corporation //'; echo "$c"; exit 0; }
            done
            echo ""
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.gpuVendor = (lines[0] ?? "").trim();
                root.gpuName = (lines[1] ?? "").trim();
                root.gpuCardPath = (lines[2] ?? "").trim();
            }
        }
    }

    Process {
        id: gpuProc
        command: ["bash", "-c", root.gpuVendor === "nvidia"
            ? "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits | head -1"
            : root.gpuVendor === "amd"
            ? `c='${root.gpuCardPath}/device'; echo "$(cat $c/gpu_busy_percent), $(cat $c/hwmon/hwmon*/temp1_input 2>/dev/null | head -1 | awk '{print $1/1000}'), $(( $(cat $c/mem_info_vram_used 2>/dev/null || echo 0) / 1048576 )), $(( $(cat $c/mem_info_vram_total 2>/dev/null || echo 0) / 1048576 ))"`
            : `c='${root.gpuCardPath}'; cur=$(cat $c/gt_act_freq_mhz 2>/dev/null || cat $c/gt_cur_freq_mhz); max=$(cat $c/gt_max_freq_mhz); echo "$(( cur * 100 / (max > 0 ? max : 1) )), 0, 0, 0"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",").map(s => parseFloat(s.trim()));
                if (f.length < 4 || isNaN(f[0])) return;
                root.gpuUsage = Math.max(0, Math.min(1, f[0] / 100));
                root.gpuTemp = isNaN(f[1]) ? 0 : f[1];
                root.gpuVramUsed = isNaN(f[2]) ? 0 : f[2];
                root.gpuVramTotal = isNaN(f[3]) ? 0 : f[3];
                root.gpuHistory = root.pushHistory(root.gpuHistory, root.gpuUsage);
            }
        }
    }

    Process {
        id: procProc
        command: ["bash", "-c", `ps -eo pid=,comm=,%cpu=,%mem= --sort=-%${root.processSort === "mem" ? "mem" : "cpu"} | head -8`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.topProcesses = text.trim().split("\n").filter(l => l.trim().length > 0).map(l => {
                    const f = l.trim().split(/\s+/);
                    return { pid: parseInt(f[0]), name: f.slice(1, f.length - 2).join(" "), cpu: parseFloat(f[f.length - 2]), mem: parseFloat(f[f.length - 1]) };
                });
            }
        }
    }

    Process {
        running: true
        command: ["bash", "-c", "grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //; s/(R)//g; s/(TM)//g; s/ CPU//; s/ @.*//'"]
        stdout: StdioCollector { onStreamFinished: root.cpuModel = text.trim() }
    }
}
