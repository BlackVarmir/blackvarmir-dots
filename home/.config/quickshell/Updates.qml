pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Оновлення: перевірка раз на 3 години. checkupdates тримає окрему копію бази pacman,
// тож систему не чіпає і root не потрібен; AUR — paru -Qua.
// Новини Arch, що вийшли після останнього повного оновлення, показуються зверху —
// там пишуть, коли оновлення потребує ручних дій.
Singleton {
    id: up

    property var repo: []        // [{ name, from, to }]
    property var aur: []
    readonly property int count: repo.length + aur.length
    property real downloadBytes: 0
    property real checkedAt: 0
    property bool checking: false
    property real lastUpgrade: 0        // мс, з /var/log/pacman.log
    property var news: []               // [{ title, link, date }] — новіші за lastUpgrade
    property bool running: false        // термінал з оновленням відкритий

    readonly property string helper: "paru"

    function check() {
        if (checking || running) return;
        checking = true;
        probe.running = true;
        newsProbe.running = true;
    }

    Timer { interval: 3 * 3600 * 1000; repeat: true; running: true; onTriggered: up.check() }
    Timer { interval: 90 * 1000; running: true; onTriggered: up.check() }   // після старту, коли мережа вже є

    function parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            const m = line.trim().match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/);
            if (m) out.push({ name: m[1], from: m[2], to: m[3] });
        }
        return out;
    }

    Process {
        id: probe
        command: ["bash", "-c",
            'repo=$(checkupdates 2>/dev/null); echo "$repo"; echo "--AUR--"; ' +
            'command -v paru >/dev/null && paru -Qua 2>/dev/null; echo "--SIZE--"; ' +
            // Розмір завантаження: та сама тимчасова база, що в checkupdates
            'db="${CHECKUPDATES_DB:-${TMPDIR:-/tmp}/checkup-db-${UID}-}"; [ -d "$db" ] || db="${TMPDIR:-/tmp}/checkup-db-$UID"; ' +
            '[ -n "$repo" ] && pacman -Sup --dbpath "$db" --print-format "%s" 2>/dev/null | awk "{s+=\\$1} END {print s+0}"; echo "--LAST--"; ' +
            'grep -a "starting full system upgrade" /var/log/pacman.log 2>/dev/null | tail -1 | cut -c2-25']
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.split("--AUR--\n");
                const b = (a[1] ?? "").split("--SIZE--\n");
                const c = (b[1] ?? "").split("--LAST--\n");
                up.repo = up.parse(a[0]);
                up.aur = up.parse(b[0]);
                up.downloadBytes = parseFloat(c[0]) || 0;
                const last = Date.parse((c[1] ?? "").trim().replace(/([+-]\d\d)(\d\d)$/, "$1:$2"));
                up.lastUpgrade = isNaN(last) ? 0 : last;
                up.checkedAt = Date.now();
                up.checking = false;
                up.maybeNotify();
                up.filterNews();
            }
        }
        onExited: code => { if (code !== 0) up.checking = false; }
    }

    // Новини Arch (RSS)
    property var allNews: []
    Process {
        id: newsProbe
        command: ["curl", "-fsS", "--max-time", "15", "https://archlinux.org/feeds/news/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const items = [];
                const re = /<item>([\s\S]*?)<\/item>/g;
                let m;
                while ((m = re.exec(text)) !== null && items.length < 5) {
                    const pick = tag => (m[1].match(new RegExp("<" + tag + ">([\\s\\S]*?)</" + tag + ">")) ?? ["", ""])[1]
                        .replace(/<!\[CDATA\[|\]\]>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").trim();
                    items.push({ title: pick("title"), link: pick("link"), date: Date.parse(pick("pubDate")) });
                }
                up.allNews = items;
                up.filterNews();
            }
        }
    }
    function filterNews() {
        const read = Settings.data.newsRead || 0;
        news = allNews.filter(n => !isNaN(n.date) && n.date > Math.max(lastUpgrade, read));
    }
    function markNewsRead() {
        Settings.set("newsRead", Date.now());
        filterNews();
    }

    // Одне тихе сповіщення на день: понад 50 оновлень або тиждень без оновлення
    function maybeNotify() {
        const stale = lastUpgrade > 0 && Date.now() - lastUpgrade > 7 * 86400 * 1000;
        if (count === 0 || (count < 50 && !stale)) return;
        const today = Qt.formatDate(new Date(), "yyyyMMdd");
        if (Settings.data.updatesNotified === today) return;
        Settings.set("updatesNotified", today);
        Quickshell.execDetached(["notify-send", "-a", "BlackVarmir", "-u", "low", "-i", "system-software-update",
            Tr.t("upd.notifyTitle", Tr.plural(count, "plural.updates")),
            stale ? Tr.t("upd.notifyStale") : Tr.t("upd.notifyMany")]);
    }

    // Оновити: плаваючий термінал; знімок перед оновленням зробить snap-pac
    function upgrade() {
        Panels.closeAll();
        running = true;
        upgrader.running = true;
    }
    Process {
        id: upgrader
        command: ["kitty", "--class", "kitty-float", "--title", Tr.t("upd.terminalTitle"), "-e", "bash", "-c",
            'if command -v paru >/dev/null; then paru -Syu; else sudo pacman -Syu; fi; echo; read -r -p "$1" _', "upgrade", Tr.t("about.pressEnter")]
        onExited: {
            up.running = false;
            up.check();
        }
    }

    function sizeText() {
        const mb = downloadBytes / 1e6;
        return mb >= 1000 ? (mb / 1000).toLocaleString(Tr.locale, "f", 1) + " " + Tr.t("unit.gb") : Math.round(mb) + " " + Tr.t("unit.mb");
    }
}
