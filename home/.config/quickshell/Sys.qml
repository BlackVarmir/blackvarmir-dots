pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Системні дрібниці для центру керування, яких немає серед сервісів Quickshell:
// яскравість, нічне світло, аптайм (VPN — у Vpn.qml).
// Нічого не опитується по таймеру: refresh() викликається лише при відкритті панелі.
Singleton {
    id: sys

    property real brightness: 1
    property int uptimeMinutes: 0
    property bool nightLight: false
    property string realName: ""
    // Збільшується після зміни аватара, щоб картинка перечиталась з диска
    property int avatarRev: 0
    readonly property string avatarPath: (Quickshell.env("HOME") || "") + "/.face.icon"

    readonly property string uptimeText: {
        const h = Math.floor(uptimeMinutes / 60);
        const m = uptimeMinutes % 60;
        return h > 0 ? Tr.t("time.hm", h, m) : Tr.t("time.m", m);
    }

    function refresh() {
        probe.running = true;
    }

    function setBrightness(v) {
        brightness = v;
        Quickshell.execDetached(["brightnessctl", "-n2", "set", Math.round(v * 100) + "%"]);
    }

    // Одним запуском: яскравість, аптайм, ім'я користувача
    Process {
        id: probe
        command: ["sh", "-c",
            // Кожна команда друкує рівно один рядок (echo "$(…)"), навіть якщо нічого не знайшла
            "echo \"$(brightnessctl -m info 2>/dev/null | cut -d, -f4)\"; " +
            "echo \"$(cut -d' ' -f1 /proc/uptime)\"; " +
            "echo \"$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const pct = parseInt(lines[0]);
                if (!isNaN(pct)) sys.brightness = pct / 100;
                sys.uptimeMinutes = Math.floor(parseFloat(lines[1] || "0") / 60);
                sys.realName = (lines[2] || "").trim();
            }
        }
    }

    // Нічне світло: hyprsunset працює постійно (розклад — у налаштуваннях),
    // плитка в центрі керування вмикає/вимикає його вручну до наступної зміни за розкладом.
    onNightLightChanged: Quickshell.execDetached(nightLight
        ? ["hyprctl", "hyprsunset", "temperature", String(Settings.data.nightTemp)]
        : ["hyprctl", "hyprsunset", "identity"])
}
