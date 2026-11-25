import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// Спливаючі індикатори: гучність, мікрофон, яскравість екрана і клавіатури, розкладка.
// Реагують на зміну самого значення, тож спрацьовують і від клавіш, і від центру керування,
// і від клавіш Fn, які ноутбук обробляє сам.
Scope {
    id: osd

    property string kind: ""        // volume · mic · screen · kbd · layout
    property bool shown: false
    property bool ready: false      // перші 2 с після запуску мовчимо: значення лише зчитуються

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // Яскравість: sysfs не надсилає подій, тож читаємо раз на 300 мс (два крихітні файли)
    property string backlight: ""
    property string kbdLight: ""
    property int screenMax: 1
    property int screenNow: 0
    property int kbdMax: 0
    property int kbdNow: 0

    function show(k) {
        if (!ready) return;
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    Timer { interval: 2000; running: true; onTriggered: osd.ready = true }
    Timer { id: hideTimer; interval: 1500; onTriggered: osd.shown = false }

    PwObjectTracker { objects: [osd.sink, osd.source] }

    Connections {
        target: osd.sink?.audio ?? null
        ignoreUnknownSignals: true
        function onVolumeChanged() { osd.show("volume"); }
        function onMutedChanged() { osd.show("volume"); }
    }
    Connections {
        target: osd.source?.audio ?? null
        ignoreUnknownSignals: true
        function onVolumeChanged() { osd.show("mic"); }
        function onMutedChanged() { osd.show("mic"); }
    }
    Connections {
        target: Layouts
        function onSwitched() { osd.show("layout"); }
    }

    Process {
        running: true
        command: ["sh", "-c",
            "b=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1); " +
            "k=$(ls -d /sys/class/leds/*kbd_backlight* 2>/dev/null | head -1); " +
            "echo \"$b\"; echo \"$( [ -n \"$b\" ] && cat \"$b/max_brightness\")\"; " +
            "echo \"$k\"; echo \"$( [ -n \"$k\" ] && cat \"$k/max_brightness\")\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                osd.backlight = l[0] || "";
                osd.screenMax = parseInt(l[1]) || 1;
                osd.kbdLight = l[2] || "";
                osd.kbdMax = parseInt(l[3]) || 0;
            }
        }
    }

    FileView {
        id: screenFile
        path: osd.backlight ? osd.backlight + "/brightness" : ""
        onLoaded: {
            const v = parseInt(text()) || 0;
            if (v !== osd.screenNow) { osd.screenNow = v; osd.show("screen"); }
        }
    }
    FileView {
        id: kbdFile
        path: osd.kbdLight ? osd.kbdLight + "/brightness" : ""
        onLoaded: {
            const v = parseInt(text()) || 0;
            if (v !== osd.kbdNow) { osd.kbdNow = v; osd.show("kbd"); }
        }
    }
    Timer {
        interval: 300
        repeat: true
        running: osd.backlight !== "" || osd.kbdLight !== ""
        onTriggered: {
            if (osd.backlight) screenFile.reload();
            if (osd.kbdLight) kbdFile.reload();
        }
    }

    // Значення для показу
    readonly property real value: kind === "volume" ? (sink?.audio?.volume ?? 0)
        : kind === "mic" ? (source?.audio?.volume ?? 0)
        : kind === "screen" ? screenNow / screenMax
        : kind === "kbd" ? (kbdMax > 0 ? kbdNow / kbdMax : 0) : 0
    readonly property bool muted: kind === "volume" ? (sink?.audio?.muted ?? false)
        : kind === "mic" ? (source?.audio?.muted ?? false) : false
    readonly property string glyph: {
        if (kind === "volume") return muted || value === 0 ? "\uf026" : value < 0.5 ? "\uf027" : "\uf028";
        if (kind === "mic") return muted ? "" : "";
        if (kind === "screen") return "";
        return "";
    }

    PanelWindow {
        id: win

        // Лише на моніторі з фокусом
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: osd.shown || pill.opacity > 0
        anchors.bottom: true
        margins.bottom: 96
        implicitWidth: pill.width
        implicitHeight: 52
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "varmir-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: pill
            width: osd.kind === "layout" ? layoutRow.implicitWidth + 16 : 300
            height: 52
            radius: 26
            color: Theme.glass
            border.width: 1
            border.color: osd.kind === "mic" && osd.muted ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.35) : Qt.rgba(1, 1, 1, 0.1)
            opacity: osd.shown ? 1 : 0
            scale: osd.shown ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

            // Смуга: гучність, мікрофон, яскравість
            RowLayout {
                visible: osd.kind !== "layout"
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 14

                Text {
                    text: osd.glyph
                    color: osd.kind === "mic" && osd.muted ? "#f87171" : osd.muted ? Theme.textSubtle : Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 18
                    Layout.preferredWidth: 20
                    horizontalAlignment: Text.AlignHCenter
                }

                // Клавіатура з кількома рівнями (вимк. / слабко / яскраво) — сегменти
                Row {
                    visible: osd.kind === "kbd" && osd.kbdMax > 0 && osd.kbdMax <= 4
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: osd.kbdMax
                        Rectangle {
                            required property int index
                            width: (parent.width - 4 * (osd.kbdMax - 1)) / osd.kbdMax
                            height: 6
                            radius: 3
                            color: index < osd.kbdNow ? Theme.emerald : Qt.rgba(1, 1, 1, 0.1)
                            gradient: index < osd.kbdNow ? brand : null
                        }
                    }
                }

                Rectangle {
                    visible: !(osd.kind === "kbd" && osd.kbdMax > 0 && osd.kbdMax <= 4)
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.1)
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, osd.value))
                        height: parent.height
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.2)
                        gradient: osd.muted ? null : brand
                        Behavior on width { NumberAnimation { duration: Theme.fast } }
                    }
                }

                Text {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: osd.muted ? Tr.t("osd.off")
                        : osd.kind === "kbd" && osd.kbdMax <= 4 ? osd.kbdNow + "/" + osd.kbdMax
                        : Math.round(osd.value * 100)
                    color: osd.kind === "mic" && osd.muted ? "#f87171" : Theme.textMuted
                    font.family: osd.muted ? Theme.font : Theme.mono
                    font.pixelSize: 13
                }
            }

            // Розкладка: усі з налаштувань, активна підсвічена
            Row {
                id: layoutRow
                visible: osd.kind === "layout"
                anchors.verticalCenter: parent.verticalCenter
                x: 8
                spacing: 8

                Repeater {
                    model: Array.from(Settings.data.kbLayouts)
                    Rectangle {
                        required property string modelData
                        readonly property bool on: modelData === Layouts.current
                        anchors.verticalCenter: parent.verticalCenter
                        width: code.implicitWidth + 24
                        height: 34
                        radius: 17
                        color: "transparent"
                        gradient: on ? brand : null
                        Text {
                            id: code
                            anchors.centerIn: parent
                            text: Layouts.find(parent.modelData).short
                            color: parent.on ? Theme.textOnAccent : Theme.textSubtle
                            font.family: Theme.mono
                            font.pixelSize: 13
                            font.weight: parent.on ? Font.DemiBold : Font.Normal
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 10
                    text: Layouts.find(Layouts.current).label
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }
        }

        Gradient {
            id: brand
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.emerald }
            GradientStop { position: 1; color: Theme.cyan }
        }
    }
}
