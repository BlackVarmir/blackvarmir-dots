import QtQuick
import Quickshell.Io

// Виконати дію з правами root через pkexec і помічник blackvarmir-settings-helper.
// Система попросить пароль (вікно hyprpolkitagent). finished(ok) — чи вдалося.
Process {
    id: action

    signal finished(bool ok)

    function run(args) {
        if (running) return;
        command = ["pkexec", "/usr/local/bin/blackvarmir-settings-helper"].concat(args);
        running = true;
    }

    onExited: (code, status) => action.finished(code === 0)
}
