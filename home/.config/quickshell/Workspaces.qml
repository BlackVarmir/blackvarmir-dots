pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Динамічні робочі столи, як у macOS і GNOME: зайняті, активні та один порожній
// наприкінці (стає новим, коли в нього перейти). Порожні столи, які покинули,
// Hyprland прибирає сам — для цього вони не мають бути «постійними».
Singleton {
    readonly property int max: 10

    // Номери столів, які мають виглядати «живими»
    readonly property var live: {
        const set = { 1: true };
        const tops = Hyprland.toplevels.values;
        for (let i = 0; i < tops.length; i++) {
            const id = tops[i].workspace?.id ?? 0;
            if (id > 0 && id <= max) set[id] = true;
        }
        const mons = Hyprland.monitors.values;
        for (let i = 0; i < mons.length; i++) {
            const id = mons[i].activeWorkspace?.id ?? 0;
            if (id > 0 && id <= max) set[id] = true;
        }
        return Object.keys(set).map(Number).sort((a, b) => a - b);
    }

    // Номер порожнього столу наприкінці; 0, якщо ліміт вичерпано
    readonly property int trailing: {
        const last = live[live.length - 1];
        return last < max ? last + 1 : 0;
    }

    // Усе, що показуємо в панелі й огляді
    readonly property var ids: trailing > 0 ? live.concat([trailing]) : live

    // Стіл за номером (або null, якщо його ще нема)
    function find(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id) return list[i];
        return null;
    }

    function go(id) {
        const ws = find(id);
        if (ws) ws.activate();
        else Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    // Назва стола: перші шість мають свої, далі «Стіл N»
    function name(id) {
        return id >= 1 && id <= 6 ? Tr.t("ws." + id) : Tr.t("ws.n", id);
    }
}
