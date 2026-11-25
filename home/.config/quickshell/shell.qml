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
}
