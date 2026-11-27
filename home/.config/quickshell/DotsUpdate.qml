pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Оновлення самого BlackVarmir (конфіги, оболонка, скрипти) з гілки main на GitHub.
// Усю роботу робить system/bin/blackvarmir-update: перевірка (git fetch), застосування
// зі знімком snapper і відкат. Перевірка раз на 3 години і через 2 хвилини після старту.
// Якщо увімкнено автоматичні оновлення, безпечні зміни застосовуються самі; усе, що
// потребує root (install.sh, пакети, нові теки конфігів), робиться лише з дозволу користувача.
Singleton {
    id: du

    readonly property string repo: (Quickshell.env("HOME") || "") + "/blackvarmir-dots"
    readonly property string script: repo + "/system/bin/blackvarmir-update"

    property var info: ({
        current: "", latest: "", branch: "", behind: 0, ahead: 0, dirty: false,
        needsInstall: false, canRollback: false, result: "", error: "", commits: []
    })
    property real checkedAt: 0
    property bool terminalOpen: false
    readonly property bool busy: run.running || terminalOpen
    readonly property bool auto: Settings.data.autoUpdate
    // Версія старіша за main і її можна оновити
    readonly property bool available: info.behind > 0 && (info.error === "" || info.error === "dirty")
    // Остання спроба автооновлення: щоб не повторювати її на ту саму версію
    property string autoTried: ""

    function check() {
        call(["check"]);
    }

    // Кнопка «Оновити»: якщо потрібен root — у терміналі, інакше тихо
    function update() {
        if (info.needsInstall) openInstall();
        else call(["apply", info.dirty ? "--force" : "--auto"]);
    }

    function rollback() {
        call(["rollback"]);
    }

    function call(args) {
        if (run.running || terminalOpen) return;
        run.command = ["bash", script].concat(args);
        run.running = true;
    }

    // Автооновлення: лише гілка main без власних змін і без потреби в root
    function maybeAuto() {
        if (!auto) return;
        const i = info;
        if (i.behind > 0 && i.ahead === 0 && i.branch === "main" && !i.dirty && !i.needsInstall
                && i.error === "" && autoTried !== i.latest) {
            autoTried = i.latest;
            call(["apply", "--auto"]);
        }
    }

    function openInstall() {
        Panels.closeAll();
        terminalOpen = true;
        installer.running = true;
    }

    Timer { interval: 3 * 3600 * 1000; repeat: true; running: true; onTriggered: du.check() }
    Timer { interval: 120 * 1000; running: true; onTriggered: du.check() }

    Process {
        id: run
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                let o = null;
                try { o = JSON.parse(lines[lines.length - 1]); } catch (e) { o = null; }
                if (!o) {
                    du.info = Object.assign({}, du.info, { error: "parse" });
                    return;
                }
                du.info = o;
                du.checkedAt = Date.now();
                du.maybeAuto();
            }
        }
    }

    // Оновлення з install.sh (потрібен sudo) — плаваючий термінал, як у оновлення пакетів
    Process {
        id: installer
        command: ["kitty", "--class", "kitty-float", "--title", Tr.t("dots.terminalTitle"), "-e", "bash", "-c",
            'out=$(bash "$1" apply --force); case "$out" in *\'"error":""\'*) cd "$2" && ./install.sh;; *) echo "$out";; esac; ' +
            'echo; read -r -p "$3" _', "bv-update", du.script, du.repo, Tr.t("about.pressEnter")]
        onExited: {
            du.terminalOpen = false;
            du.check();
        }
    }
}
