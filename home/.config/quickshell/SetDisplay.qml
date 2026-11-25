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

    // Монітор перетягнули на схемі: (gx, gy) — куди лягає його лівий верхній кут
    // у логічних координатах. Притягуємо до найближчого краю основного монітора і
    // вирівнюємо по верху / центру / низу, якщо до них близько.
    function dropAt(m, gx, gy) {
        if (!m || !primary || m === primary) return;
        const p = primary.lastIpcObject ?? {}, o = m.lastIpcObject ?? {};
        const pw = Math.round(p.width / p.scale), ph = Math.round(p.height / p.scale);
        const ow = Math.round(o.width / o.scale), oh = Math.round(o.height / o.scale);
        const dx = (gx + ow / 2 - (p.x + pw / 2)) / pw, dy = (gy + oh / 2 - (p.y + ph / 2)) / ph;
        let x, y;
        const snap = (v, targets, span) => {
            for (const t of targets) if (Math.abs(v - t) < span * 0.08) return t;
            return v;
        };
        if (Math.abs(dx) >= Math.abs(dy)) {
            x = dx > 0 ? p.x + pw : p.x - ow;
            y = snap(Math.max(p.y - oh + 50, Math.min(p.y + ph - 50, gy)), [p.y, p.y + (ph - oh) / 2, p.y + ph - oh], ph);
        } else {
            y = dy > 0 ? p.y + ph : p.y - oh;
            x = snap(Math.max(p.x - ow + 50, Math.min(p.x + pw - 50, gx)), [p.x, p.x + (pw - ow) / 2, p.x + pw - ow], pw);
        }
        x = Math.round(x);
        y = Math.round(y);
        if (x === o.x && y === o.y) return;
        change(m, { position: `${x}x${y}` });
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
                    readonly property bool movable: modelData.m !== page.primary
                    // Зсув під час перетягування (у пікселях схеми)
                    property real dragX: 0
                    property real dragY: 0
                    z: dragArea.pressed ? 2 : 1
                    x: diagram.offX + (modelData.x - diagram.minX) * diagram.k + dragX
                    y: diagram.offY + (modelData.y - diagram.minY) * diagram.k + dragY
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
                        id: dragArea
                        anchors.fill: parent
                        cursorShape: box.movable ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                        property point start
                        onPressed: mouse => {
                            page.selectedName = box.modelData.m.name;
                            start = mapToItem(diagram, mouse.x, mouse.y);
                        }
                        onPositionChanged: mouse => {
                            if (!box.movable || !pressed) return;
                            const pt = mapToItem(diagram, mouse.x, mouse.y);
                            box.dragX = pt.x - start.x;
                            box.dragY = pt.y - start.y;
                        }
                        onReleased: {
                            if (box.movable && (Math.abs(box.dragX) > 3 || Math.abs(box.dragY) > 3))
                                page.dropAt(box.modelData.m,
                                    box.modelData.x + box.dragX / diagram.k,
                                    box.modelData.y + box.dragY / diagram.k);
                            box.dragX = 0;
                            box.dragY = 0;
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.topMargin: -8
        text: Tr.t("display.selected", (page.selected?.name.startsWith("eDP") ? Tr.t("display.builtinScreen") : (page.selected?.name ?? "")))
        color: Theme.textSubtle
        font.family: Theme.font
        font.pixelSize: 12
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
