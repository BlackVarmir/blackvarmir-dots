import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

// Alt + Tab: вікна з усіх столів у порядку останнього використання.
// Клавіші ловить Hyprland (підмапа «alttab» у binds.lua) і кличе сюди через qs ipc,
// тож вікну не потрібен фокус клавіатури, а відпускання Alt надійно доходить.
Scope {
    id: root

    property bool active: false     // перемикач запущено (Alt ще тримають)
    property bool shown: false      // показаний (Alt тримають довше 150 мс)
    property var list: []
    property int index: 0
    property bool appOnly: false

    readonly property var current: list[index] ?? null
    readonly property int currentWs: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 0

    function ipcOf(t) { return t.lastIpcObject ?? ({}); }

    // Адреси вікон від останнього активного; оновлюється подією activewindowv2
    property var mru: []
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindowv2" && event.data) {
                const m = root.mru.filter(a => a !== event.data);
                m.unshift(event.data);
                root.mru = m.slice(0, 64);
            } else if (event.name === "closewindow") {
                root.mru = root.mru.filter(a => a !== event.data);
            }
        }
    }

    function build(appOnly) {
        let l = Hyprland.toplevels.values.filter(t => {
            const ws = ipcOf(t).workspace?.name ?? "";
            return ipcOf(t).mapped !== false && !ws.startsWith("special");
        });
        // Порядок: власна історія фокусу (події Hyprland), далі — як запам'ятав Hyprland
        const rank = t => {
            const i = mru.indexOf(t.address);
            return i !== -1 ? i : 1000 + (ipcOf(t).focusHistoryID ?? 999);
        };
        l.sort((a, b) => rank(a) - rank(b));
        if (appOnly && l.length > 0) {
            const cls = ipcOf(l[0]).class;
            l = l.filter(t => ipcOf(t).class === cls);
        }
        return l;
    }

    // Кожна клавіша — окремий процес qs ipc, тож «відпустили Alt» може прийти раніше
    // за «Alt + Tab». Тоді запам'ятовуємо його й одразу переходимо, щойно перемикач стартує.
    property real earlyCommit: 0

    function start(dir, app) {
        if (active) { step(dir); return; }
        // lastIpcObject (title, class, розмір) сам не оновлюється: без цього картки порожні
        Hyprland.refreshToplevels();
        if (dir < 0) Layouts.undoRecentSwitch();
        Panels.closeAll();
        list = build(app);
        appOnly = app;
        index = list.length < 2 ? 0 : dir > 0 ? 1 : list.length - 1;
        active = true;
        if (Date.now() - earlyCommit < 400) { earlyCommit = 0; commit(); return; }
        showDelay.restart();
    }

    function step(dir) {
        if (list.length > 0) index = (index + dir + list.length) % list.length;
    }

    function finish() {
        active = false;
        shown = false;
        showDelay.stop();
        Hyprland.dispatch('hl.dsp.submap("reset")');
    }

    function commit() {
        const t = current;
        const wasActive = active;
        if (!wasActive) { earlyCommit = Date.now(); return; }
        finish();
        if (!t) return;
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${t.address}" })`);
    }

    function closeCurrent() {
        const t = current;
        if (!t) return;
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${t.address}" })`);
        const l = list.slice();
        l.splice(index, 1);
        list = l;
        if (list.length === 0) { finish(); return; }
        index = Math.min(index, list.length - 1);
    }

    Timer {
        id: showDelay
        interval: 150
        onTriggered: {
            Hyprland.refreshToplevels();
            root.shown = root.active && root.list.length > 0;
            submapProbe.running = true;
        }
    }

    // Запобіжник: якщо підмапу вже скинуто (Alt відпустили, а подія загубилась) — переходимо
    Process {
        id: submapProbe
        command: ["hyprctl", "submap"]
        stdout: StdioCollector {
            onStreamFinished: if (root.active && text.trim() !== "alttab") root.commit()
        }
    }

    IpcHandler {
        target: "alttab"
        function next(): void { root.start(1, false); }
        function prev(): void { root.start(-1, false); }
        function appNext(): void { root.start(1, true); }
        function commit(): void { root.commit(); }
        function cancel(): void { root.finish(); }
        function close(): void { root.closeCurrent(); }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.shown
        implicitWidth: Math.min(card.implicitWidth, (screen?.width ?? 1920) - 120)
        implicitHeight: card.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "varmir-alttab"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card
            anchors.fill: parent
            implicitWidth: strip.contentWidth + 36
            implicitHeight: 224
            radius: 22
            color: Theme.glass
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)

            ListView {
                id: strip
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 18
                height: 160
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                interactive: false
                model: root.list
                currentIndex: root.index
                highlightMoveDuration: Theme.base
                preferredHighlightBegin: 0
                preferredHighlightEnd: width
                highlightRangeMode: ListView.ApplyRange
                delegate: AltTabItem {
                    required property var modelData
                    required property int index
                    toplevel: modelData
                    selected: index === root.index
                    otherWorkspace: (root.ipcOf(modelData).workspace?.id ?? root.currentWs) !== root.currentWs
                    onHovered: root.index = index
                    onChosen: { root.index = index; root.commit(); }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 16
                Repeater {
                    model: [["Tab", Tr.t("at.next")], ["⇧ Tab", Tr.t("at.prev")], ["Q", Tr.t("at.close")], ["Alt", Tr.t("at.release")]]
                    Row {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            width: key.implicitWidth + 12
                            height: 18
                            radius: 5
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Text {
                                id: key
                                anchors.centerIn: parent
                                text: modelData[0]
                                color: Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: 11
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[1]
                            color: Theme.textSubtle
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
