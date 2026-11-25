pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Системні дрібниці для центру керування, яких немає серед сервісів Quickshell:
// яскравість, нічне світло, VPN, аптайм.
// Нічого не опитується по таймеру: refresh() викликається лише при відкритті панелі.
Singleton {
    id: sys

    property real brightness: 1
    property int uptimeMinutes: 0
    property string vpnName: ""
    property bool vpnActive: false
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

    function toggleVpn() {
        if (vpnName === "") return;
        Quickshell.execDetached(["nmcli", "connection", vpnActive ? "down" : "up", vpnName]);
        vpnActive = !vpnActive;
        recheck.restart();
    }

    // Одним запуском: яскравість, аптайм, перший VPN/WireGuard і активні з'єднання
    Process {
        id: probe
        command: ["sh", "-c",
            // Кожна команда друкує рівно один рядок (echo "$(…)"), навіть якщо нічого не знайшла
            "echo \"$(brightnessctl -m info 2>/dev/null | cut -d, -f4)\"; " +
            "echo \"$(cut -d' ' -f1 /proc/uptime)\"; " +
            "echo \"$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -E ':(wireguard|vpn)$' | head -n1 | cut -d: -f1)\"; " +
            "echo \"$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1)\"; " +
            "echo '--'; nmcli -t -f NAME connection show --active 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const pct = parseInt(lines[0]);
                if (!isNaN(pct)) sys.brightness = pct / 100;
                sys.uptimeMinutes = Math.floor(parseFloat(lines[1] || "0") / 60);
                sys.vpnName = (lines[2] || "").trim();
                sys.realName = (lines[3] || "").trim();
                const sep = lines.indexOf("--");
                const active = sep >= 0 ? lines.slice(sep + 1) : [];
                sys.vpnActive = sys.vpnName !== "" && active.indexOf(sys.vpnName) !== -1;
            }
        }
    }

    // Перевірити стан VPN через 2 с після перемикання
    Timer {
        id: recheck
        interval: 2000
        onTriggered: sys.refresh()
    }

    // Нічне світло: hyprsunset працює постійно (розклад — у налаштуваннях),
    // плитка в центрі керування вмикає/вимикає його вручну до наступної зміни за розкладом.
    onNightLightChanged: Quickshell.execDetached(nightLight
        ? ["hyprctl", "hyprsunset", "temperature", String(Settings.data.nightTemp)]
        : ["hyprctl", "hyprsunset", "identity"])
}
