pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Розкладки клавіатури: код xkb, назва для людей, коротка позначка і назва,
// яку Hyprland надсилає в події activelayout.
Singleton {
    readonly property var catalog: [
        { value: "us", label: "English (US)", short: "EN", xkb: "English (US)" },
        { value: "gb", label: "English (UK)", short: "GB", xkb: "English (UK)" },
        { value: "ua", label: "Українська", short: "UK", xkb: "Ukrainian" },
        { value: "ru", label: "Русский", short: "RU", xkb: "Russian" },
        { value: "pl", label: "Polski", short: "PL", xkb: "Polish" },
        { value: "de", label: "Deutsch", short: "DE", xkb: "German" },
        { value: "fr", label: "Français", short: "FR", xkb: "French" },
        { value: "cz", label: "Čeština", short: "CZ", xkb: "Czech" }
    ]

    // Поточна розкладка (код xkb). Оновлюється з подій Hyprland.
    property string current: Settings.data.kbLayouts[0] ?? "us"
    property string previous: current
    property real switchedAt: 0
    property real quietUntil: 0
    signal switched()
    signal reverted()

    // Alt + Shift + Tab: Shift, натиснутий при затиснутому Alt, уже перемкнув мову,
    // перш ніж Hyprland побачив Tab. Перемикач вікон кличе це, щоб повернути мову назад.
    function undoRecentSwitch() {
        if (Date.now() - switchedAt > 1500) return;
        if (Settings.data.kbToggle !== "alt_shift") return;
        const idx = Array.from(Settings.data.kbLayouts).indexOf(previous);
        if (idx < 0) return;
        quietUntil = Date.now() + 600;
        switchedAt = 0;
        reverted();
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(idx)]);
    }

    function find(code) {
        return catalog.find(c => c.value === code) ?? { value: code, label: code, short: code.toUpperCase(), xkb: code };
    }

    // «English (US)» / «Ukrainian» / «Ukrainian (phonetic)» → код
    function fromXkb(name) {
        const exact = catalog.find(c => c.xkb === name);
        if (exact) return exact.value;
        const loose = catalog.find(c => name.startsWith(c.xkb.split(" (")[0]));
        return loose ? loose.value : name.slice(0, 2).toLowerCase();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // activelayout>>назва_клавіатури,Назва розкладки
            if (event.name !== "activelayout") return;
            const code = fromXkb(event.data.split(",").pop());
            if (code === current) return;
            previous = current;
            current = code;
            if (Date.now() < quietUntil) return;
            switchedAt = Date.now();
            switched();
        }
    }
}
