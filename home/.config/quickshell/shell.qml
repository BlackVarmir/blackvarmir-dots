//@ pragma UseQApplication
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
    Notifications {}
}
