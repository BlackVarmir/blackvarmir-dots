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

    // Опис від snap-pac — це команда pacman; перетворюємо на зрозуміле
    function describe(s) {
        const d = (s.description || "").trim();
        if (/^(pacman|paru|yay)\b/.test(d) || s.cleanup === "number" && s.type === "pre") {
            if (/\s-S[a-z]*u|\s-Syu|\s-Su/.test(d) || /^(paru|yay)$/.test(d)) return { title: Tr.t("snap.beforeUpdate"), detail: d };
            if (/\s-R/.test(d)) return { title: Tr.t("snap.beforeRemove"), detail: d };
            return { title: Tr.t("snap.beforeInstall"), detail: d };
        }
        if (s.type === "single" && s.cleanup === "timeline") return { title: Tr.t("snap.daily"), detail: "" };
        if (s.type === "single" && s.cleanup === "boot") return { title: Tr.t("snap.boot"), detail: "" };
        return { title: d || Tr.t("snap.manual"), detail: "" };
    }

    Process {
        id: lister
        command: ["bash", "-c",
            '[ "$(findmnt -no FSTYPE /)" = btrfs ] || [ -d /.snapshots ] || { echo NOBTRFS; exit 0; }; ' +
            'echo "FREE $(df -h --output=avail / | tail -1 | tr -d " ")"; ' +
            'snapper --jsonout -c root list --columns number,type,pre-number,date,description,cleanup,userdata']
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
                    for (const s of all) {
                        if (s.number === 0 || s.type === "post") continue;
                        const d = snaps.describe(s);
                        out.push({
                            number: s.number,
                            type: s.type,
                            date: new Date(String(s.date).replace(" ", "T")),
                            title: d.title,
                            detail: d.detail,
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
    function create(description) {
        creator.command = ["snapper", "-c", "root", "create", "-t", "single", "-c", "",
            "--userdata", "important=yes", "-d", description || Tr.t("snap.manual")];
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
    function setBeforeUpdates(on) { beforeUpdates = on; configurer.run(["snapshot-updates", on ? "on" : "off"]); }
}
