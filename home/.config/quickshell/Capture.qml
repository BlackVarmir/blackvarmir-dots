pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Знімки і запис екрана.
//   qs ipc call capture open     — Print: панель (область / вікно / екран, знімок / запис)
//   qs ipc call capture screen   — Shift + Print: одразу весь екран з фокусом
// Під час запису Print (або клік по острівцю на панелі) зупиняє запис.
// Знімки: grim → ~/Pictures/Screenshots і в буфер. Відео: wf-recorder (H.264, MP4) → ~/Videos/Recordings.
Singleton {
    id: cap

    property string mode: "region"     // region · window · screen
    property string action: "shot"     // shot · record
    property int delay: 0              // 0 · 3 · 10 с
    readonly property string audio: Settings.data.recordAudio   // none · system · mic

    property bool recording: false
    property real recordStart: 0
    property string recordInfo: ""
    property int countdown: 0

    // Останній результат — для мініатюри в куті
    property string lastFile: ""
    property bool lastIsVideo: false
    property int toastRev: 0

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string shotDir: home + "/Pictures/Screenshots"
    readonly property string videoDir: home + "/Videos/Recordings"

    function open() {
        if (recording) { stop(); return; }
        Panels.closeAll();
        Panels.captureOpen = true;
    }

    function stamp() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss"); }

    // target: { geometry: "x,y wxh" } у глобальних логічних координатах, або { output: "eDP-1" }
    property var pending: null
    function take(target) {
        Panels.captureOpen = false;
        pending = target;
        if (delay > 0) {
            countdown = delay;
            countdownTimer.start();
        } else {
            // Дати оверлею зникнути, щоб він не потрапив у кадр
            settle.start();
        }
    }

    function targetArgs(t) {
        return t.geometry ? ["-g", t.geometry] : t.output ? ["-o", t.output] : [];
    }

    function run() {
        const t = pending;
        pending = null;
        if (!t) return;
        if (action === "record") startRecording(t);
        else shoot(t);
    }

    function shoot(t) {
        const file = `${shotDir}/${stamp()}.png`;
        shot.file = file;
        shot.command = ["bash", "-c",
            'mkdir -p "$1" && grim "${@:3}" "$2" && wl-copy --type image/png < "$2"',
            "capture", shotDir, file].concat(targetArgs(t));
        shot.running = true;
    }

    function screenNow() {
        if (recording) { stop(); return; }
        Panels.closeAll();
        const out = Hyprland.focusedMonitor?.name ?? "";
        pending = out ? { output: out } : {};
        action = "shot";
        settle.start();
    }

    function startRecording(t) {
        const file = `${videoDir}/${stamp()}.mp4`;
        recorder.file = file;
        recordInfo = (t.geometry ? Tr.t("cap.region") : Tr.t("cap.screen"))
            + (audio === "mic" ? " · " + Tr.t("cap.audioMic") : audio === "system" ? " · " + Tr.t("cap.audioSystem") : "");
        recorder.command = ["bash", "-c",
            'dir="$1"; file="$2"; audio="$3"; shift 3; a=(); ' +
            'case "$audio" in system) a=(--audio="$(pactl get-default-sink).monitor");; mic) a=(--audio);; esac; ' +
            'mkdir -p "$dir" && exec wf-recorder "$@" "${a[@]}" -c libx264 -p preset=veryfast -x yuv420p -f "$file"',
            "capture", videoDir, file, audio].concat(targetArgs(t));
        recorder.running = true;
        recording = true;
        recordStart = Date.now();
    }

    function stop() {
        if (recorder.running) recorder.signal(2);   // SIGINT: wf-recorder дописує файл і виходить
    }

    function showToast(file, video) {
        lastFile = file;
        lastIsVideo = video;
        toastRev += 1;
    }

    Timer { id: settle; interval: 220; onTriggered: cap.run() }
    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            cap.countdown -= 1;
            if (cap.countdown <= 0) { countdownTimer.stop(); settle.start(); }
        }
    }

    Process {
        id: shot
        property string file: ""
        onExited: code => { if (code === 0) cap.showToast(file, false); }
    }

    Process {
        id: recorder
        property string file: ""
        onExited: {
            cap.recording = false;
            cap.showToast(file, true);
        }
    }

    IpcHandler {
        target: "capture"
        function open(): void { cap.open(); }
        function screen(): void { cap.screenNow(); }
        function stop(): void { cap.stop(); }
    }
}
