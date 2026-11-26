pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// VPN через NetworkManager: список тунелів (WireGuard і плагіни VPN), підключення,
// відключення, імпорт конфігу і видалення. Тунелів може бути активно кілька одразу
// (кожен WireGuard-тунель — власний інтерфейс). Нічого не опитується по таймеру:
// refresh() викликається при відкритті панелі і після кожної дії.
Singleton {
    id: vpn

    // [{ name, kind: "wireguard" | "vpn", active, device }]
    property var tunnels: []
    readonly property var activeList: tunnels.filter(t => t.active)
    readonly property int activeCount: activeList.length

    // Назва тунелю, з яким зараз працюємо (підключення/відключення/видалення), і остання помилка
    property string pending: ""
    property string error: ""
    readonly property bool busy: op.running

    function refresh() {
        if (!list.running) list.running = true;
    }

    // Швидка дія з плитки: якщо тунель один — перемкнути його, інакше це вирішує сторінка
    function toggleSingle() {
        if (tunnels.length !== 1) return false;
        toggle(tunnels[0]);
        return true;
    }

    function toggle(t) {
        run(t.name, ["nmcli", "-w", "20", "connection", t.active ? "down" : "up", "id", t.name]);
    }

    function remove(name) {
        run(name, ["nmcli", "connection", "delete", "id", name]);
    }

    // Назва інтерфейсу WireGuard: до 15 символів із латиниці, цифр, «_» і «-»
    function safeName(s) {
        const n = String(s || "").trim().replace(/[^A-Za-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 15);
        return n;
    }

    // Імпорт із файлу .conf (шлях може починатися з ~)
    function importFile(path) {
        let p = String(path || "").trim();
        if (p === "") return;
        if (p === "~" || p.startsWith("~/")) p = (Quickshell.env("HOME") || "") + p.slice(1);
        run("", ["sh", "-c", importScript.replace("@SRC@", '"$1"'), "sh", p]);
    }

    // Імпорт із вставленого тексту: конфіг передається змінною середовища, не аргументом,
    // щоб приватний ключ не потрапив у список процесів
    function importText(name, text) {
        const n = safeName(name) || "wg-" + (tunnels.length + 1);
        if (String(text || "").trim() === "") return;
        run("", ["sh", "-c",
            'umask 077; d=$(mktemp -d) || exit 1; f="$d/$1.conf"; printf "%s\\n" "$BV_VPN_CONF" > "$f"; ' +
            importScript.replace("@SRC@", '"$f"') + '; rc=$?; rm -rf "$d"; exit $rc',
            "sh", n], { BV_VPN_CONF: String(text) });
    }

    // Імпорт: створює підключення NetworkManager і вимикає для нього автозапуск,
    // щоб тунель не піднімався сам після кожного входу
    readonly property string importScript:
        'out=$(nmcli connection import type wireguard file @SRC@ 2>&1) || { echo "$out"; exit 1; }; ' +
        'echo "$out"; ' +
        'uuid=$(printf "%s" "$out" | grep -oE "[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}" | head -n1); ' +
        '[ -n "$uuid" ] && nmcli connection modify uuid "$uuid" connection.autoconnect no; true'

    function run(name, command, env) {
        if (op.running) return;
        pending = name;
        error = "";
        op.environment = env || ({});
        op.command = ["sh", "-c", '"$@" 2>&1; echo "@@rc=$?"', "sh"].concat(command);
        op.running = true;
    }

    // Прибрати службові частини з повідомлення nmcli
    function clean(text) {
        return String(text).replace(/@@rc=\d+/, "").replace(/^Error: /m, "").trim();
    }

    function unescape(s) {
        return s.replace(/\\(.)/g, "$1");
    }

    Process {
        id: list
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    // Двокрапка в назві екранується як «\:»
                    const m = line.match(/^((?:\\.|[^:\\])*):([^:]*):(.*)$/);
                    if (!m) continue;
                    if (m[2] !== "wireguard" && m[2] !== "vpn") continue;
                    out.push({
                        name: vpn.unescape(m[1]),
                        kind: m[2],
                        active: m[3] !== "",
                        device: m[3]
                    });
                }
                out.sort((a, b) => a.active !== b.active ? (a.active ? -1 : 1) : a.name.localeCompare(b.name));
                vpn.tunnels = out;
            }
        }
    }

    Process {
        id: op
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/@@rc=(\d+)/);
                const rc = m ? parseInt(m[1]) : 1;
                vpn.error = rc === 0 ? "" : (vpn.clean(text) || "error");
                vpn.pending = "";
                vpn.refresh();
            }
        }
    }
}
