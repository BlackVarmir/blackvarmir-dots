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

    readonly property string uptimeText: {
        const h = Math.floor(uptimeMinutes / 60);
        const m = uptimeMinutes % 60;
        return h > 0 ? `${h} год ${m} хв` : `${m} хв`;
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
            "brightnessctl -m info 2>/dev/null | cut -d, -f4; " +
            "cut -d' ' -f1 /proc/uptime; " +
            "nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -E ':(wireguard|vpn)$' | head -n1 | cut -d: -f1; " +
            "echo '--'; nmcli -t -f NAME connection show --active 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const pct = parseInt(lines[0]);
                if (!isNaN(pct)) sys.brightness = pct / 100;
                sys.uptimeMinutes = Math.floor(parseFloat(lines[1] || "0") / 60);
                sys.vpnName = (lines[2] || "").trim();
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

    // Нічне світло: процес hyprsunset живе, поки режим увімкнено
    Process {
        running: sys.nightLight
        command: ["hyprsunset", "-t", "4000"]
    }
}
