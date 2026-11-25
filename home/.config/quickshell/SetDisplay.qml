import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Екран: роздільність, частота, масштаб, розташування другого монітора, нічне світло.
// Зміна застосовується одразу, але без підтвердження за 15 с повертається як було —
// щоб не залишитися з чорним екраном після невдалого режиму.
SetPage {
    id: page

    title: Tr.t("set.display")
    subtitle: Tr.t("display.subtitle")

    Component.onCompleted: Hyprland.refreshMonitors()

    readonly property var monitors: Hyprland.monitors.values.filter(m => !(m.lastIpcObject?.disabled ?? false))
    readonly property var primary: monitors.find(m => m.name.startsWith("eDP")) ?? monitors[0] ?? null
    property string selectedName: primary?.name ?? ""
    readonly property var selected: monitors.find(m => m.name === selectedName) ?? primary
    readonly property var ipc: selected?.lastIpcObject ?? ({})

    // Режими вибраного монітора: "1920x1080@60.00Hz" → { res, hz }
    readonly property var modes: (ipc.availableModes ?? []).map(m => {
        const [res, hz] = m.replace("Hz", "").split("@");
        return { res: res, hz: Number(hz) };
    })
    readonly property var resolutions: {
        const seen = {};
        const out = [];
        modes.slice().sort((a, b) => {
            const [aw, ah] = a.res.split("x").map(Number);
            const [bw, bh] = b.res.split("x").map(Number);
            return bw * bh - aw * ah;
        }).forEach(m => { if (!seen[m.res]) { seen[m.res] = true; out.push({ value: m.res, label: m.res.replace("x", " × ") }); } });
        return out;
    }
    readonly property string currentRes: `${ipc.width ?? 0}x${ipc.height ?? 0}`
    readonly property var rates: modes.filter(m => m.res === currentRes)
        .map(m => ({ value: m.hz.toFixed(2), label: Tr.t("unit.hz", Math.round(m.hz)) }))
        .filter((r, i, a) => a.findIndex(x => x.value === r.value) === i)

    // ───── Застосувати з підтвердженням ─────
    property var pendingOld: null
    property string pendingName: ""
    property int secondsLeft: 0

    function cfgOf(m) {
        const o = m.lastIpcObject ?? {};
        return {
            mode: `${o.width}x${o.height}@${Number(o.refreshRate).toFixed(2)}`,
            position: `${o.x}x${o.y}`,
            scale: Number(o.scale ?? 1)
        };
    }

    function change(m, patch) {
        if (!m) return;
        if (pendingName !== "") keep();
        const old = cfgOf(m);
        const next = Object.assign({}, old, patch);
        pendingOld = old;
        pendingName = m.name;
        pendingNew = next;
        Settings.previewMonitor(m.name, next);
        secondsLeft = 15;
        countdown.restart();
        refresh.restart();
    }
    property var pendingNew: null

    function keep() {
        countdown.stop();
        const map = Object.assign({}, Settings.data.monitors || {});
        map[pendingName] = pendingNew;
        Settings.set("monitors", map);
        pendingName = "";
    }
    function revert() {
        countdown.stop();
        Settings.previewMonitor(pendingName, pendingOld);
        pendingName = "";
        refresh.restart();
    }

    // Розташування другого монітора відносно основного
    function place(where) {
        const m = selected;
        if (!m || !primary || m === primary) return;
        const p = primary.lastIpcObject ?? {}, o = m.lastIpcObject ?? {};
        const pw = Math.round(p.width / p.scale), ph = Math.round(p.height / p.scale);
        const ow = Math.round(o.width / o.scale), oh = Math.round(o.height / o.scale);
        const pos = where === "left" ? `${p.x - ow}x${p.y}`
            : where === "above" ? `${p.x}x${p.y - oh}`
            : where === "below" ? `${p.x}x${p.y + ph}`
            : `${p.x + pw}x${p.y}`;
        change(m, { position: pos });
    }
    readonly property string placement: {
        if (!selected || !primary || selected === primary) return "";
        const p = primary.lastIpcObject ?? {}, o = selected.lastIpcObject ?? {};
        if (o.x >= p.x + p.width / p.scale) return "right";
        if (o.x + o.width / o.scale <= p.x) return "left";
        if (o.y + o.height / o.scale <= p.y) return "above";
        return "below";
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: { page.secondsLeft -= 1; if (page.secondsLeft <= 0) page.revert(); }
    }
    Timer {
        id: refresh
        interval: 400
        onTriggered: Hyprland.refreshMonitors()
    }

    // ───── Схема моніторів ─────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 200
        radius: Theme.radiusTile
        color: Qt.rgba(1, 1, 1, 0.02)
        border.width: 1
        border.color: Theme.hairline

        Item {
            id: diagram
            anchors.fill: parent
            anchors.margins: 24

            readonly property var boxes: page.monitors.map(m => {
                const o = m.lastIpcObject ?? {};
                return { m: m, x: o.x ?? 0, y: o.y ?? 0, w: (o.width ?? 1920) / (o.scale ?? 1), h: (o.height ?? 1080) / (o.scale ?? 1) };
            })
            readonly property real minX: Math.min(...boxes.map(b => b.x), 0)
            readonly property real minY: Math.min(...boxes.map(b => b.y), 0)
            readonly property real spanW: Math.max(...boxes.map(b => b.x + b.w), 1) - minX
            readonly property real spanH: Math.max(...boxes.map(b => b.y + b.h), 1) - minY
            readonly property real k: Math.min(width / spanW, height / spanH)
            readonly property real offX: (width - spanW * k) / 2
            readonly property real offY: (height - spanH * k) / 2

            Repeater {
                model: diagram.boxes
                Rectangle {
                    id: box
                    required property var modelData
                    readonly property bool on: modelData.m.name === page.selected?.name
                    x: diagram.offX + (modelData.x - diagram.minX) * diagram.k
                    y: diagram.offY + (modelData.y - diagram.minY) * diagram.k
                    width: modelData.w * diagram.k - 6
                    height: modelData.h * diagram.k - 6
                    radius: 10
                    color: on ? Theme.accentSoft : Qt.rgba(1, 1, 1, 0.05)
                    border.width: on ? 2 : 1
                    border.color: on ? Theme.emerald : Theme.hairlineStrong

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: box.modelData.m.name.startsWith("eDP") ? Tr.t("display.builtin") : Tr.t("display.external")
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: box.modelData.m.name + " · " + (box.modelData.m.lastIpcObject?.width ?? "") + "×" + (box.modelData.m.lastIpcObject?.height ?? "")
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.selectedName = box.modelData.m.name
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: page.width > 1000 ? 2 : 1
        columnSpacing: 20
        rowSpacing: 20

        SetCard {
            Layout.alignment: Qt.AlignTop
            label: (page.selected?.name.startsWith("eDP") ? Tr.t("display.builtin") : Tr.t("display.external")).toUpperCase() + " · " + (page.selected?.name ?? "")

            SetRow {
                divider: false
                label: Tr.t("display.resolution")
                VSelect {
                    width: 190
                    options: page.resolutions
                    current: page.currentRes
                    onPicked: v => {
                        const best = page.modes.filter(m => m.res === v).sort((a, b) => b.hz - a.hz)[0];
                        page.change(page.selected, { mode: `${v}@${best.hz.toFixed(2)}` });
                    }
                }
            }
            SetRow {
                label: Tr.t("display.refresh")
                VSelect {
                    width: 190
                    options: page.rates
                    current: Number(page.ipc.refreshRate ?? 60).toFixed(2)
                    onPicked: v => page.change(page.selected, { mode: `${page.currentRes}@${v}` })
                }
            }
            SetRow {
                stacked: true
                label: Tr.t("display.scale")
                hint: Tr.t("display.scaleHint")
                Segmented {
                    options: [1, 1.25, 1.5, 2].map(v => ({ value: v, label: Math.round(v * 100) + "%" }))
                    current: Number(page.ipc.scale ?? 1)
                    onPicked: v => page.change(page.selected, { scale: v })
                }
            }
            SetRow {
                visible: page.selected !== page.primary
                stacked: true
                label: Tr.t("display.placement")
                Segmented {
                    options: [
                        { value: "left", label: Tr.t("display.left") },
                        { value: "right", label: Tr.t("display.right") },
                        { value: "above", label: Tr.t("display.above") },
                        { value: "below", label: Tr.t("display.below") }
                    ]
                    current: page.placement
                    onPicked: v => page.place(v)
                }
            }
        }

        SetCard {
            Layout.alignment: Qt.AlignTop
            label: Tr.t("night.eyebrow")

            SetRow {
                divider: false
                label: Tr.t("night.schedule")
                hint: Tr.t("night.scheduleHint")
                Toggle {
                    checked: Settings.data.nightSchedule
                    onToggled: v => Settings.set("nightSchedule", v)
                }
            }
            SetRow {
                visible: Settings.data.nightSchedule
                label: Tr.t("night.from")
                VSelect {
                    width: 120
                    options: ["18:00", "19:00", "20:00", "21:00", "22:00", "23:00"].map(v => ({ value: v, label: v }))
                    current: Settings.data.nightFrom
                    onPicked: v => Settings.set("nightFrom", v)
                }
            }
            SetRow {
                visible: Settings.data.nightSchedule
                label: Tr.t("night.to")
                VSelect {
                    width: 120
                    options: ["5:00", "6:00", "7:00", "8:00", "9:00"].map(v => ({ value: v, label: v }))
                    current: Settings.data.nightTo
                    onPicked: v => Settings.set("nightTo", v)
                }
            }
            SetRow {
                stacked: true
                label: Tr.t("night.warmth")
                Segmented {
                    options: [3500, 4000, 4500, 5500].map(v => ({ value: v, label: v + " K" }))
                    current: Settings.data.nightTemp
                    onPicked: v => Settings.set("nightTemp", v)
                }
            }
        }
    }

    // ───── Панель підтвердження ─────
    Rectangle {
        visible: page.pendingName !== ""
        Layout.fillWidth: true
        implicitHeight: confirmRow.implicitHeight + 20
        radius: Theme.radiusTile
        color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.98)
        border.width: 1
        border.color: Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.4)

        RowLayout {
            id: confirmRow
            x: 18
            y: 10
            width: parent.width - 28
            spacing: 14
            Text {
                Layout.fillWidth: true
                text: Tr.t("display.keepQuestion")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
            }
            Text {
                text: Tr.t("display.revertIn", page.secondsLeft)
                color: Theme.warning
                font.family: Theme.mono
                font.pixelSize: 13
            }
            VButton { text: Tr.t("display.revert"); variant: "ghost"; onClicked: page.revert() }
            VButton { text: Tr.t("display.keep"); onClicked: page.keep() }
        }
    }
}
