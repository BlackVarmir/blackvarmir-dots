pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Знімки системи (snapper, конфігурація root). Перегляд і створення — без пароля
// (install.sh дає користувачу ALLOW_USERS), відновлення і налаштування — через pkexec.
Singleton {
    id: snaps

    property bool available: false
    property bool loaded: false
    property var list: []               // [{ number, type, date, title, detail, auto, pinned }]
    property var postOf: ({})           // номер «до» → номер парного «після» (snap-pac)
    property int keep: 10
    property bool daily: false
    property bool beforeUpdates: true
    property string freeSpace: ""
    property real usedBytes: -1         // скільки займають усі знімки (потрібні квоти btrfs)
    property string error: ""

    // Завантажились зі знімка (grub-btrfs / limine): номер, інакше 0
    property int bootedFrom: 0
    // Номер знімка, для якого відкрити діалог відновлення (з банера або Spotlight)
    property int restoreRequest: 0

    function refresh() {
        if (!lister.running) lister.running = true;
        if (!configProbe.running) configProbe.running = true;
    }

    Component.onCompleted: { refresh(); cmdline.reload(); }

    FileView {
        id: cmdline
        path: "/proc/cmdline"
        onLoaded: {
            const m = text().match(/snapshots\/(\d+)\/snapshot/);
            snaps.bootedFrom = m ? parseInt(m[1]) : 0;
        }
    }

    // Що показати в списку. Нові знімки мають userdata від blackvarmir-snapshot-info
    // (kind, pkgs, list, first) або від «Налаштувань» (kind=manual, title); старі — лише
    // опис snap-pac (команду pacman).
    function describe(s) {
        const u = s.userdata ?? {};
        const n = parseInt(u.pkgs) || 0;
        const list = (u.list || "").split(";").map(x => x.trim()).filter(x => x).join(", ");
        const more = n > 3 ? " …" : "";
        if (u.kind === "update") return { kind: "update", pkgs: n, title: Tr.t("snap.beforeUpdate") + " · " + Tr.plural(n, "plural.packages"), detail: list + more };
        if (u.kind === "install" || u.kind === "remove") {
            const base = Tr.t(u.kind === "install" ? "snap.beforeInstall" : "snap.beforeRemove");
            return { kind: u.kind, pkgs: n, first: u.first || "",
                title: base + " · " + (n === 1 ? (u.first || list) : Tr.plural(n, "plural.packages")),
                detail: n === 1 ? Tr.plural(1, "plural.packages") : list + more };
        }
        if (u.kind === "manual" || u.kind === "restore")
            return { kind: u.kind, title: (u.title || "").replace(/;/g, ","), detail: u.kind === "manual"
                ? Tr.t("snap.createdManually") + (u.important === "yes" && !s.cleanup ? " · " + Tr.t("snap.pinned") : "") : "" };
        // Без наших даних — розбираємо команду pacman
        const d = (s.description || "").trim();
        if (/^(pacman|paru|yay)\b/.test(d)) {
            if (/\s-S[a-z]*u|\s-Syu|\s-Su/.test(d) || /^(paru|yay)$/.test(d)) return { kind: "update", title: Tr.t("snap.beforeUpdate"), detail: d };
            if (/\s-R/.test(d)) return { kind: "remove", title: Tr.t("snap.beforeRemove"), detail: d };
            return { kind: "install", title: Tr.t("snap.beforeInstall"), detail: d };
        }
        if (s.cleanup === "timeline") return { kind: "daily", title: Tr.t("snap.daily"), detail: "" };
        if (s.cleanup === "boot") return { kind: "boot", title: Tr.t("snap.boot"), detail: "" };
        return { kind: "manual", title: d.replace(/^#\d+ · [\d-]+ [\d:]+ · /, "") || Tr.t("snap.manual"), detail: Tr.t("snap.createdManually") };
    }

    Process {
        id: lister
        command: ["bash", "-c",
            '[ "$(findmnt -no FSTYPE /)" = btrfs ] || [ -d /.snapshots ] || { echo NOBTRFS; exit 0; }; ' +
            'echo "FREE $(df -h --output=avail / | tail -1 | tr -d " ")"; ' +
            'snapper --jsonout -c root list --columns number,type,pre-number,date,description,cleanup,userdata,used-space 2>/dev/null ' +
            '|| snapper --jsonout -c root list --columns number,type,pre-number,date,description,cleanup,userdata']
        stdout: StdioCollector {
            onStreamFinished: {
                snaps.loaded = true;
                if (text.startsWith("NOBTRFS")) { snaps.available = false; return; }
                const nl = text.indexOf("\n");
                snaps.freeSpace = text.slice(0, nl).replace("FREE ", "");
                try {
                    const all = JSON.parse(text.slice(nl + 1)).root ?? [];
                    const out = [];
                    const posts = {};
                    for (const s of all) if (s.type === "post" && s["pre-number"]) posts[s["pre-number"]] = s.number;
                    snaps.postOf = posts;
                    let used = 0, hasUsed = false;
                    for (const s of all) {
                        const u = parseFloat(s["used-space"]);
                        if (s.number !== 0 && !isNaN(u)) { used += u; hasUsed = true; }
                    }
                    snaps.usedBytes = hasUsed ? used : -1;
                    for (const s of all) {
                        if (s.number === 0 || s.type === "post") continue;
                        const d = snaps.describe(s);
                        out.push({
                            number: s.number,
                            type: s.type,
                            date: new Date(String(s.date).replace(" ", "T")),
                            title: d.title,
                            detail: d.detail,
                            kind: d.kind,
                            pkgs: d.pkgs ?? 0,
                            first: d.first ?? "",
                            auto: s.cleanup === "number" || s.cleanup === "timeline" || s.cleanup === "boot",
                            pinned: (s.userdata?.important === "yes") && s.cleanup === ""
                        });
                    }
                    out.sort((a, b) => b.number - a.number);
                    snaps.list = out;
                    snaps.available = true;
                    snaps.error = "";
                } catch (e) {
                    snaps.available = false;
                    snaps.error = text.slice(nl + 1).trim();
                }
            }
        }
    }

    Process {
        id: configProbe
        command: ["bash", "-c",
            'snapper --jsonout -c root get-config 2>/dev/null; echo; ' +
            'grep -Eiq "^\\s*snapshot\\s*=\\s*false" /etc/snap-pac.ini 2>/dev/null && echo SNAPPAC=off || echo SNAPPAC=on']
        stdout: StdioCollector {
            onStreamFinished: {
                const i = text.lastIndexOf("SNAPPAC=");
                snaps.beforeUpdates = text.slice(i).trim() !== "SNAPPAC=off";
                try {
                    const c = JSON.parse(text.slice(0, i).trim());
                    snaps.keep = parseInt(c.NUMBER_LIMIT) || 10;
                    snaps.daily = c.TIMELINE_CREATE === "yes";
                } catch (e) {}
            }
        }
    }

    // Створити (закріплений: cleanup порожній, тож snapper його не видалить сам)
    // Опис для меню завантаження: «#43 · 2026-11-25 14:02 · назва» (див. blackvarmir-grub-titles)
    function create(title) {
        const t = (title || Tr.t("snap.manual")).replace(/[,=]/g, ";").replace(/["$\\]/g, "");
        creator.command = ["bash", "-c",
            'n=$(snapper -c root create -t single -c "" --print-number --userdata "important=yes,kind=manual,title=$1" -d "$1") && ' +
            'snapper -c root modify -d "#$n · $(date "+%Y-%m-%d %H:%M") · $1" "$n"', "snap", t];
        creator.running = true;
    }
    Process { id: creator; onExited: snaps.refresh() }

    function remove(number) {
        // Для знімка «до» видаляємо і парний «після»
        const args = ["snapper", "-c", "root", "delete", String(number)];
        if (postOf[number]) args.push(String(postOf[number]));
        remover.command = args;
        remover.running = true;
    }
    Process { id: remover; onExited: snaps.refresh() }

    // Root: відновлення, налаштування
    signal restoreFinished(bool ok)
    RootAction {
        id: restorer
        onFinished: ok => {
            snaps.restoreFinished(ok);
            if (ok) Quickshell.execDetached(["systemctl", "reboot"]);
        }
    }
    function restore(number) { restorer.run(["snapshot-restore", String(number)]); }

    RootAction { id: configurer; onFinished: snaps.refresh() }
    function setKeep(n) { keep = n; configurer.run(["snapshot-keep", String(n)]); }
    function setDaily(on) { daily = on; configurer.run(["snapshot-daily", on ? "on" : "off"]); }
    function sizeText(bytes) {
        const gb = bytes / 1e9;
        return gb >= 1 ? gb.toLocaleString(Tr.locale, "f", 1) + " " + Tr.t("unit.gb") : Math.round(bytes / 1e6) + " " + Tr.t("unit.mb");
    }

    function setBeforeUpdates(on) { beforeUpdates = on; configurer.run(["snapshot-updates", on ? "on" : "off"]); }
}
