pragma Singleton

import QtQuick
import Quickshell

// Токени Varmir Design System для всієї оболонки.
// Змінюєш колір тут — він змінюється всюди.
Singleton {
    // Поверхні
    readonly property color canvas: "#0a0a0b"
    readonly property color panel: "#111113"
    readonly property color inset: "#18181b"
    readonly property color glass: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.62)
    readonly property color glassStrong: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.80)
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.08)
    readonly property color hairlineStrong: Qt.rgba(1, 1, 1, 0.14)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.06)

    // Текст
    readonly property color text: "#fafafa"
    readonly property color textMuted: "#a1a1aa"
    readonly property color textSubtle: "#71717a"
    readonly property color textOnAccent: "#04130d"

    // Акценти
    readonly property color emerald: "#10b981"
    readonly property color emeraldLight: "#34d399"
    readonly property color cyan: "#22d3ee"
    readonly property color accentSoft: Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14)
    readonly property color accentBorder: Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.40)

    // Стани
    readonly property color success: "#22c55e"
    readonly property color warning: "#f59e0b"
    readonly property color error: "#ef4444"

    // Шрифти
    readonly property string font: "Geist"
    readonly property string mono: "GeistMono Nerd Font"

    // Розміри
    readonly property int barHeight: 40
    readonly property int barMargin: 10
    readonly property int edge: 14
    readonly property int radiusChip: 8
    readonly property int radiusIsland: 12
    readonly property int radiusTile: 14
    readonly property int radiusOverlay: 20

    // Закріплені в доці застосунки за замовчуванням (id .desktop-файлів без розширення).
    // Використовуються лише при першому запуску; далі список живе в
    // ~/.local/state/blackvarmir/dock.json і змінюється з меню дока.
    // Яких немає в системі — просто не показуються.
    readonly property var pinnedApps: [
        "kitty",
        "org.gnome.Nautilus",
        "firefox",
        "code",
        "org.telegram.desktop",
        "spotify"
    ]

    // Рух: крива Varmir (0.16, 1, 0.3, 1), короткі тривалості
    readonly property var ease: [0.16, 1, 0.3, 1, 1, 1]
    readonly property int fast: 120
    readonly property int base: 150
    readonly property int slow: 250
}
