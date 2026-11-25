pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Налаштування користувача: ~/.config/blackvarmir/settings.json
// З них генеруються файли поза репозиторієм (git pull їх не зачіпає):
//   ~/.config/blackvarmir/hyprland-user.lua   — підхоплює hyprland.lua в кінці
//   ~/.config/blackvarmir/hypridle.conf       — запускається замість стандартного
//   ~/.config/blackvarmir/hyprsunset.conf     — розклад нічного світла
//   ~/.config/blackvarmir/wallpaper           — шлях до шпалер
// Зміни застосовуються одразу: Hyprland через `hyprctl eval`, решта — перезапуском служби.
Singleton {
    id: settings

    readonly property string dir: (Quickshell.env("HOME") || "") + "/.config/blackvarmir"
    readonly property alias data: adapter
    readonly property bool loaded: file.loaded

    // Короткі імена для читання з інших файлів
    readonly property string shellLang: adapter.shellLang
    readonly property bool clock24: adapter.clock24

    // Записати значення і перегенерувати те, від чого воно залежить
    function set(key, value) {
        adapter[key] = value;
        if (["kbLayouts", "kbToggle", "repeatDelay", "repeatRate", "blur", "anim", "gaps", "rounding", "gradientBorder", "monitors"].indexOf(key) !== -1)
            writeHyprland();
        else if (["dimAfter", "lockAfter", "sleepAfter"].indexOf(key) !== -1)
            writeHypridle();
        else if (["nightSchedule", "nightFrom", "nightTo", "nightTemp"].indexOf(key) !== -1)
            writeHyprsunset();
        else if (key === "wallpaper")
            applyWallpaper();
    }

    // ───────────── Hyprland ─────────────
    readonly property var toggles: ({
        alt_shift: "grp:alt_shift_toggle",
        ctrl_shift: "grp:ctrl_shift_toggle",
        caps: "grp:caps_toggle"
    })
    // Базові швидкості анімацій (див. hypr/modules/animations.lua)
    readonly property var animLeaves: [
        ["global", 3, "varmir"], ["border", 3, "varmir"], ["windows", 2.5, "varmir"],
        ["windowsIn", 2.5, "varmir", "popin 92%"], ["windowsOut", 1.5, "linear", "popin 92%"],
        ["windowsMove", 2.5, "varmir"], ["fade", 1.5, "varmir"],
        ["layersIn", 1.5, "varmir", "fade"], ["layersOut", 1.2, "linear", "fade"],
        ["workspaces", 3, "varmir", "slide"], ["specialWorkspace", 2.5, "varmir", "slidevert"]
    ]

    function luaString(s) {
        return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    function hyprlandLua() {
        const d = adapter;
        const lines = [
            "-- Згенеровано застосунком «Налаштування» BlackVarmir.",
            "-- Не редагуй вручну: файл перезаписується при кожній зміні налаштувань.",
            ""
        ];
        const toggle = toggles[d.kbToggle] || toggles.alt_shift;
        lines.push(`hl.config({ input = { kb_layout = ${luaString(Array.from(d.kbLayouts).join(","))}, kb_options = ${luaString(toggle)}, repeat_delay = ${Math.round(d.repeatDelay)}, repeat_rate = ${Math.round(d.repeatRate)} } })`);

        const border = d.gradientBorder
            ? '{ colors = { "rgba(10b981ff)", "rgba(22d3eeff)" }, angle = 45 }'
            : '"rgba(10b981ff)"';
        lines.push(`hl.config({ general = { gaps_in = ${Math.round(d.gaps / 2)}, gaps_out = ${Math.round(d.gaps)}, col = { active_border = ${border} } } })`);

        const blur = d.blur === "off" ? "enabled = false"
            : d.blur === "strong" ? "enabled = true, size = 10, passes = 3"
            : "enabled = true, size = 6, passes = 2";
        lines.push(`hl.config({ decoration = { rounding = ${Math.round(d.rounding)}, blur = { ${blur} } } })`);

        if (d.anim === "off") {
            lines.push("hl.config({ animations = { enabled = false } })");
        } else {
            lines.push("hl.config({ animations = { enabled = true } })");
            const k = d.anim === "smooth" ? 1.6 : 1;
            for (let i = 0; i < animLeaves.length; i++) {
                const a = animLeaves[i];
                const style = a[3] ? `, style = ${luaString(a[3])}` : "";
                lines.push(`hl.animation({ leaf = ${luaString(a[0])}, enabled = true, speed = ${(a[1] * k).toFixed(2)}, bezier = ${luaString(a[2])}${style} })`);
            }
        }

        const mons = d.monitors || {};
        for (const name in mons) {
            const m = mons[name];
            lines.push(`hl.monitor({ output = ${luaString(name)}, mode = ${luaString(m.mode)}, position = ${luaString(m.position)}, scale = ${Number(m.scale)} })`);
        }
        return lines.join("\n") + "\n";
    }

    function writeHyprland() {
        hyprUser.setText(hyprlandLua());
        Quickshell.execDetached(["hyprctl", "eval", `dofile("${dir}/hyprland-user.lua")`]);
    }

    // Застосувати лише монітор (для перевірки «Залишити / Повернути»), без запису у файл
    function previewMonitor(name, m) {
        Quickshell.execDetached(["hyprctl", "eval",
            `hl.monitor({ output = ${luaString(name)}, mode = ${luaString(m.mode)}, position = ${luaString(m.position)}, scale = ${Number(m.scale)} })`]);
    }

    // ───────────── Бездіяльність (hypridle) ─────────────
    function hypridleConf() {
        const d = adapter;
        const out = [
            "# Згенеровано застосунком «Налаштування» BlackVarmir.",
            "general {",
            "    lock_cmd = qs ipc call lock lock || pidof hyprlock || hyprlock",
            "    inhibit_sleep = 3",
            "    before_sleep_cmd = loginctl lock-session",
            "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'",
            "}"
        ];
        if (d.dimAfter > 0)
            out.push("", "listener {", `    timeout = ${d.dimAfter}`, "    on-timeout = brightnessctl -s set 10%", "    on-resume = brightnessctl -r", "}");
        if (d.lockAfter > 0) {
            out.push("", "listener {", `    timeout = ${d.lockAfter}`, "    on-timeout = loginctl lock-session", "}");
            out.push("", "listener {", `    timeout = ${d.lockAfter + 30}`,
                "    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'",
                "    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'", "}");
        }
        if (d.sleepAfter > 0)
            out.push("", "listener {", `    timeout = ${d.sleepAfter}`, "    on-timeout = systemctl suspend", "}");
        return out.join("\n") + "\n";
    }

    function writeHypridle() {
        idleFile.setText(hypridleConf());
        Quickshell.execDetached(["sh", "-c", `pkill -x hypridle; sleep 0.3; exec hypridle -c "${dir}/hypridle.conf"`]);
    }

    // ───────────── Нічне світло (hyprsunset) ─────────────
    function hyprsunsetConf() {
        const d = adapter;
        if (!d.nightSchedule)
            return "# Згенеровано «Налаштуваннями» BlackVarmir: розклад вимкнено.\nprofile {\n    time = 0:00\n    identity = true\n}\n";
        return "# Згенеровано «Налаштуваннями» BlackVarmir.\n"
            + `profile {\n    time = ${d.nightTo}\n    identity = true\n}\n\n`
            + `profile {\n    time = ${d.nightFrom}\n    temperature = ${Math.round(d.nightTemp)}\n}\n`;
    }

    function writeHyprsunset() {
        sunsetFile.setText(hyprsunsetConf());
        Quickshell.execDetached(["sh", "-c", `pkill -x hyprsunset; sleep 0.3; exec hyprsunset -c "${dir}/hyprsunset.conf"`]);
    }

    // ───────────── Шпалери ─────────────
    function applyWallpaper() {
        if (!adapter.wallpaper) return;
        wallFile.setText(adapter.wallpaper + "\n");
        Quickshell.execDetached(["awww", "img", adapter.wallpaper, "--transition-type", "fade"]);
    }

    // Перший запуск: створити файли з поточними значеннями
    function writeAll() {
        hyprUser.setText(hyprlandLua());
        idleFile.setText(hypridleConf());
        sunsetFile.setText(hyprsunsetConf());
    }

    FileView {
        id: file
        path: settings.dir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: if (idleFile.loaded && idleFile.text() !== settings.hypridleConf()) settings.writeHypridle()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                writeAdapter();
                settings.writeAll();
            }
        }

        JsonAdapter {
            id: adapter

            // Мова і регіон
            property string shellLang: "system" // system | uk | en
            property bool clock24: true

            // Клавіатура
            property list<string> kbLayouts: ["us", "ua"]
            property string kbToggle: "alt_shift"
            property int repeatDelay: 300
            property int repeatRate: 40

            // Екран: { "eDP-1": { mode, position, scale } }
            property var monitors: ({})
            property bool nightSchedule: false
            property string nightFrom: "21:00"
            property string nightTo: "7:00"
            property int nightTemp: 4000

            // Вигляд
            property string wallpaper: ""
            property string blur: "light"   // off | light | strong
            property string anim: "fast"    // fast | smooth | off
            property int gaps: 14
            property int rounding: 12
            property bool gradientBorder: true

            // Живлення (секунди, 0 — ніколи)
            property int dimAfter: 150
            property int lockAfter: 300
            property int sleepAfter: 1200
            property string lid: "suspend"
        }
    }

    FileView { id: hyprUser; path: settings.dir + "/hyprland-user.lua" }
    // Після оновлення оболонки формат hypridle.conf міг змінитися (наприклад, новий екран
    // блокування) — перегенеровуємо, якщо файл відрізняється від того, що дали б налаштування
    FileView {
        id: idleFile
        path: settings.dir + "/hypridle.conf"
        onLoaded: if (file.loaded && text() !== settings.hypridleConf()) settings.writeHypridle()
    }
    FileView { id: sunsetFile; path: settings.dir + "/hyprsunset.conf" }
    FileView { id: wallFile; path: settings.dir + "/wallpaper" }
}
