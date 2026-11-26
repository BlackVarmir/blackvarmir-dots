//@ pragma UseQApplication
//@ pragma StateDir $BASE/blackvarmir
//@ pragma IconTheme Papirus-Dark
import QtQuick
import Quickshell

// BlackVarmir Shell: точка входу Quickshell (~/.config/quickshell/shell.qml).
// Запуск: qs   ·   перезапуск після змін не потрібен — Quickshell перезавантажує файли сам.
ShellRoot {
    // Панель на кожному моніторі
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Spotlight {}
    Overview {}
    ControlCenter {}
    Notifications {}
    SettingsWindow {}
    Osd {}
    AltTab {}
    Lock {}

    // Етап 6: знімки й запис, буфер обміну, календар і погода
    Variants {
        model: Quickshell.screens
        CaptureOverlay {}
    }
    CaptureToast {}
    Clipboard {}
    CalendarPopup {}

    // Етап 7: оновлення і знімки системи
    UpdatesPopup {}
    SnapshotBanner {}

    // Етап 8: установник (живий сеанс: BV_INSTALLER=1, або qs ipc call installer open)
    Installer {}
}
