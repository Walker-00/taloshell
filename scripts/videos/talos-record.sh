#!/usr/bin/env bash
# taloshell screen recorder backend.
# Runs the recorder in the foreground; send SIGTERM/SIGINT to finish (the file is saved),
# or touch "$OUT.discard" first to throw it away.
#
# talos-record.sh --out FILE [--backend wf|gsr|wlsr] [--geometry "X,Y WxH"] [--output MONITOR]
#                 [--audio none|mic|system|both] [--fps N] [--codec h264|hevc|av1|vp9] [--cursor 0|1]
#                 [--format mp4|mkv|webm|gif]
set -u

backend="wf" out="" geometry="" output="" audio="none" fps="60" codec="h264" cursor="1" format="mp4"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --backend) backend="$2"; shift 2 ;;
        --out) out="$2"; shift 2 ;;
        --geometry) geometry="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --audio) audio="$2"; shift 2 ;;
        --fps) fps="$2"; shift 2 ;;
        --codec) codec="$2"; shift 2 ;;
        --cursor) cursor="$2"; shift 2 ;;
        --format) format="$2"; shift 2 ;;
        *) shift ;;
    esac
done
[[ -z "$out" ]] && { echo "missing --out" >&2; exit 1; }
mkdir -p "$(dirname "$out")"

# GIFs are recorded as mp4 first and converted at the end
record_file="$out"
[[ "$format" == "gif" ]] && record_file="${out%.*}.tmp.mp4"

default_sink() { pactl get-default-sink 2>/dev/null; }
default_source() { pactl get-default-source 2>/dev/null; }

mix_modules=()
setup_mix() {
    # Null sink that receives both system audio and the mic
    local sink_mod mon_mod mic_mod
    sink_mod=$(pactl load-module module-null-sink sink_name=TaloshellMix sink_properties=device.description=TaloshellMix) || return 1
    mix_modules+=("$sink_mod")
    mon_mod=$(pactl load-module module-loopback source="$(default_sink).monitor" sink=TaloshellMix latency_msec=20) && mix_modules+=("$mon_mod")
    mic_mod=$(pactl load-module module-loopback source="$(default_source)" sink=TaloshellMix latency_msec=20) && mix_modules+=("$mic_mod")
}
teardown_mix() {
    for m in "${mix_modules[@]}"; do pactl unload-module "$m" 2>/dev/null; done
    mix_modules=()
}

audio_device=""
case "$audio" in
    mic) audio_device="$(default_source)" ;;
    system) audio_device="$(default_sink).monitor" ;;
    both) setup_mix && audio_device="TaloshellMix.monitor" ;;
esac

cmd=()
case "$backend" in
    gsr)
        target="screen"
        [[ -n "$output" ]] && target="$output"
        cmd=(gpu-screen-recorder -f "$fps" -k "$codec" -o "$record_file" -cursor "$([[ $cursor == 1 ]] && echo yes || echo no)")
        if [[ -n "$geometry" ]]; then
            # "X,Y WxH" -> WxH+X+Y
            read -r xy wh <<< "$geometry"
            cmd+=(-w region -region "${wh}+${xy/,/+}")
        else
            cmd+=(-w "$target")
        fi
        case "$audio" in
            mic) cmd+=(-a default_input) ;;
            system) cmd+=(-a default_output) ;;
            both) cmd+=(-a "default_output|default_input") ;;
        esac
        ;;
    wlsr)
        cmd=(wl-screenrec -f "$record_file" --max-fps "$fps")
        [[ -n "$geometry" ]] && cmd+=(-g "$geometry")
        [[ -z "$geometry" && -n "$output" ]] && cmd+=(-o "$output")
        [[ -n "$audio_device" ]] && cmd+=(--audio --audio-device "$audio_device")
        ;;
    *)
        codec_arg="libx264"
        case "$codec" in
            hevc) codec_arg="libx265" ;;
            av1) codec_arg="libsvtav1" ;;
            vp9) codec_arg="libvpx-vp9" ;;
        esac
        cmd=(wf-recorder -y -f "$record_file" -r "$fps" -c "$codec_arg")
        [[ -n "$geometry" ]] && cmd+=(-g "$geometry")
        [[ -z "$geometry" && -n "$output" ]] && cmd+=(-o "$output")
        [[ -n "$audio_device" ]] && cmd+=("--audio=$audio_device")
        ;;
esac

echo "[talos-record] ${cmd[*]}" >&2
"${cmd[@]}" &
rec_pid=$!

finish() {
    kill -INT "$rec_pid" 2>/dev/null
    wait "$rec_pid" 2>/dev/null
    teardown_mix
    if [[ -e "$out.discard" ]]; then
        rm -f "$out.discard" "$record_file" "$out"
        echo "discarded"
        exit 0
    fi
    if [[ "$format" == "gif" && -f "$record_file" ]]; then
        ffmpeg -loglevel error -y -i "$record_file" -vf "fps=15,scale='min(960,iw)':-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" "$out" && rm -f "$record_file"
    fi
    echo "saved $out"
    exit 0
}
trap finish INT TERM

wait "$rec_pid"
# Recorder died on its own (error or output unplugged)
teardown_mix
[[ -f "$record_file" ]] && echo "saved $out" || { echo "failed" ; exit 1; }
