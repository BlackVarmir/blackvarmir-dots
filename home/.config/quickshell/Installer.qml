import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking

// Установник: мова, розкладка, Wi-Fi, диск, шпалери, користувач, підтвердження.
// Показується в живому сеансі (змінна BV_INSTALLER=1) або командою qs ipc call installer open.
// BV_DRYRUN=1: план складається й показується, але на диск нічого не пишеться.
// Логіка дисків: installer/backend.py (шлях з BV_REPO, типово /opt/blackvarmir-dots).
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: shown
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "varmir-installer"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool shown: Quickshell.env("BV_INSTALLER") === "1"
    readonly property bool dryRun: Quickshell.env("BV_DRYRUN") === "1"
    // Де лежить бекенд: BV_REPO, на ISO /opt/blackvarmir-dots, у розробці ~/blackvarmir-dots
    readonly property string runBackend: 'for d in "$BV_REPO" /opt/blackvarmir-dots "$HOME/blackvarmir-dots"; do '
        + '[ -f "$d/installer/backend.py" ] && exec python3 "$d/installer/backend.py" "$@"; done; '
        + 'echo "backend.py not found" >&2; exit 3'
    readonly property string home: Quickshell.env("HOME") || ""

    // Кроки: 0 мова, 1 розкладка, 2 Wi-Fi, 3 диск, 4 скільки віддати (лише поруч із Windows),
    // 5 шпалери, 6 користувач, 7 підтвердження, 8 встановлення, 9 готово
    readonly property var order: ["lang", "kb", "net", "disk", "along", "look", "user", "confirm", "run", "done"]
    property int step: 0
    readonly property string cur: order[step]
    readonly property bool busyStep: cur === "run" || cur === "done"

    // Вибір користувача
    property var disks: []
    property bool disksLoaded: false
    property string diskPath: ""
    property string mode: "erase"          // erase | alongside
    property real linuxGb: 100
    property string fullName: ""
    property string userName: ""
    property string hostName: "blackvarmir"
    property string pw: ""
    property string pw2: ""
    property var plan: null
    property string planError: ""
    property int runIndex: -1

    readonly property var disk: disks.find(d => d.path === diskPath) ?? null
    readonly property var windows: disk && disk.windows.length > 0 ? disk.windows[0] : null
    readonly property bool nameOk: /^[a-z_][a-z0-9_-]{0,31}$/.test(userName)
    readonly property bool pwOk: pw.length > 0 && pw === pw2

    function gb(bytes) { return Math.round(bytes / (1 << 30)) + " GB"; }

    function open() { step = 0; shown = true; loadDisks(); }
    function close() { shown = false; }

    // Наступний і попередній крок: «Скільки віддати» показується лише в режимі поруч із Windows
    function go(delta) {
        let s = step + delta;
        if (order[s] === "along" && mode !== "alongside") s += delta;
        step = Math.max(0, Math.min(order.length - 1, s));
        if (cur === "disk") loadDisks();
        if (cur === "confirm") buildPlan();
        if (cur === "run") startRun();
    }

    readonly property bool canNext: {
        if (cur === "disk") return disk !== null && !disk.busy && (mode === "erase" || (windows !== null && !windows.bitlocker));
        if (cur === "along") return linuxGb >= 40 && linuxGb <= maxGb;
        if (cur === "user") return nameOk && pwOk && hostName.length > 0;
        if (cur === "confirm") return plan !== null && plan.ok;
        return true;
    }
    readonly property real maxGb: windows && windows.minBytes ? Math.floor((windows.size - windows.minBytes) / (1 << 30)) - 2 : 40

    Component.onCompleted: if (shown) loadDisks()

    IpcHandler {
        target: "installer"
        function open(): void { win.open(); }
        function close(): void { win.close(); }
    }

    // ───────────── Бекенд ─────────────
    Process {
        id: disksProc
        command: ["bash", "-c", win.runBackend, "_", "disks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.disks = JSON.parse(text).disks; } catch (e) { win.disks = []; }
                win.disksLoaded = true;
                if (!win.disk) {
                    const first = win.disks.find(d => !d.busy);
                    win.diskPath = first ? first.path : "";
                }
            }
        }
    }
    function loadDisks() { win.disksLoaded = false; disksProc.running = true; }

    Process {
        id: planProc
        property string payload: ""
        command: ["bash", "-c", "printf '%s' \"$1\" | { shift; " + win.runBackend + "; }", "_", payload, "plan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    win.plan = JSON.parse(text);
                    win.planError = win.plan.ok ? "" : win.plan.error;
                } catch (e) {
                    win.plan = { ok: false };
                    win.planError = Tr.t("inst.planFailed");
                }
            }
        }
    }
    function buildPlan() {
        win.plan = null;
        win.planError = "";
        planProc.payload = JSON.stringify({
            mode: win.mode,
            disk: win.diskPath,
            windowsPart: win.windows ? win.windows.path : "",
            linuxBytes: Math.round(win.linuxGb * (1 << 30))
        });
        planProc.running = true;
    }

    // Виконання: поки що лише показ кроків плану (пробний запуск). Запис на диск додається окремою зміною.
    Timer {
        id: runTimer
        interval: 700
        repeat: true
        onTriggered: {
            win.runIndex++;
            if (win.runIndex >= win.plan.steps.length) { stop(); win.step = win.order.indexOf("done"); }
        }
    }
    function startRun() { win.runIndex = 0; runTimer.start(); }

    onVisibleChanged: if (visible) keys.forceActiveFocus()
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onReturnPressed: if (next.visible && win.canNext) next.clicked()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(8 / 255, 8 / 255, 10 / 255, 0.62)
    }

    // ───────────── Спільні компоненти ─────────────
    component IRow: Rectangle {
        id: wr
        property string text: ""
        property string hint: ""
        property string trail: ""
        property bool on: false
        property bool disabled: false
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: hint !== "" ? 50 : 40
        radius: 10
        opacity: disabled ? 0.45 : 1
        color: on ? Theme.accentSoft : Qt.rgba(1, 1, 1, wrArea.containsMouse && !disabled ? 0.07 : 0.04)
        border.width: 1
        border.color: on ? Theme.emerald : Theme.hairline

        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            spacing: 1
            Text { text: wr.text; color: "#e4e4e7"; font.family: Theme.font; font.pixelSize: 13 }
            Text { visible: wr.hint !== ""; text: wr.hint; color: Theme.textSubtle; font.family: Theme.font; font.pixelSize: 11 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12
            text: wr.trail
            color: Theme.textSubtle
            font.family: Theme.font
            font.pixelSize: 12
        }
        MouseArea {
            id: wrArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: wr.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: if (!wr.disabled) wr.clicked()
        }
    }

    component Field: Rectangle {
        id: fld
        property alias text: input.text
        property string placeholder: ""
        property bool secret: false
        property bool bad: false
        Layout.fillWidth: true
        implicitHeight: 38
        radius: 8
        color: Theme.inset
        border.width: 1
        border.color: bad ? Theme.error : (input.activeFocus ? Theme.accentBorder : Theme.hairlineStrong)
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            echoMode: fld.secret ? TextInput.Password : TextInput.Normal
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: fld.placeholder
                color: Theme.textSubtle
                font: input.font
            }
        }
    }

    component Note: Text {
        Layout.fillWidth: true
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: 12
        lineHeight: 1.25
        wrapMode: Text.WordWrap
    }

    // ───────────── Картка ─────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 340
        height: 430
        radius: 18
        color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.78)
        border.width: 1
        border.color: Theme.hairlineStrong

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 26
            anchors.bottomMargin: 22
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: win.cur === "disk" && win.disk && win.mode === "alongside" && win.windows && win.windows.bitlocker
                    ? Tr.t("inst.t.bitlocker") : Tr.t("inst.t." + win.cur)
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 20
                font.weight: Font.DemiBold
                font.letterSpacing: -0.4
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: win.cur === "disk" && win.mode === "alongside" && win.windows && win.windows.bitlocker
                    ? Tr.t("inst.d.bitlocker") : Tr.t("inst.d." + win.cur)
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: ({ lang: cLang, kb: cKeyboard, net: cWifi, disk: cDisk, along: cAlong,
                    look: cLook, user: cUser, confirm: cConfirm, run: cRun, done: cDone })[win.cur]
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: win.order.length - 3
                    Rectangle {
                        required property int index
                        Layout.alignment: Qt.AlignVCenter
                        readonly property bool active: index === Math.min(win.step, win.order.length - 4)
                        implicitWidth: active ? 22 : 6
                        implicitHeight: 6
                        radius: 3
                        color: active ? Theme.emerald : Qt.rgba(1, 1, 1, 0.2)
                        gradient: active ? dotGradient : null
                        Behavior on implicitWidth { NumberAnimation { duration: Theme.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                    }
                }
                Gradient {
                    id: dotGradient
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.emerald }
                    GradientStop { position: 1; color: Theme.cyan }
                }

                Item { Layout.fillWidth: true }

                VButton {
                    visible: win.step > 0 && !win.busyStep
                    small: false
                    variant: "secondary"
                    text: Tr.t("inst.back")
                    onClicked: win.go(-1)
                }
                VButton {
                    id: next
                    visible: win.cur !== "run"
                    small: false
                    opacity: win.canNext ? 1 : 0.4
                    text: win.cur === "confirm" ? Tr.t("inst.install") : win.cur === "done" ? (win.dryRun ? Tr.t("inst.close") : Tr.t("inst.reboot")) : Tr.t("inst.next")
                    onClicked: {
                        if (!win.canNext) return;
                        if (win.cur === "done") { win.dryRun ? win.close() : rebooter.running = true; }
                        else win.go(1);
                    }
                }
            }
        }
    }
    Process { id: rebooter; command: ["systemctl", "reboot"] }

    // ───────────── 1: мова ─────────────
    Component {
        id: cLang
        ColumnLayout {
            spacing: 8
            IRow { text: "English"; trail: "en"; on: Settings.shellLang === "en"; onClicked: Settings.set("shellLang", "en") }
            IRow { text: "Українська"; trail: "uk"; on: Settings.shellLang === "uk"; onClicked: Settings.set("shellLang", "uk") }
            IRow { text: Tr.t("inst.sys"); trail: Tr.t("inst.fromLang"); on: Settings.shellLang === "system"; onClicked: Settings.set("shellLang", "system") }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── 2: розкладка ─────────────
    Component {
        id: cKeyboard
        ColumnLayout {
            spacing: 8
            readonly property var picked: Array.from(Settings.data.kbLayouts)
            Repeater {
                model: Layouts.catalog.slice(0, 5)
                IRow {
                    required property var modelData
                    text: modelData.label
                    trail: modelData.short
                    on: parent.picked.indexOf(modelData.value) !== -1
                    onClicked: {
                        const cur = parent.picked;
                        const i = cur.indexOf(modelData.value);
                        if (i === -1) Settings.set("kbLayouts", cur.concat([modelData.value]));
                        else if (cur.length > 1) Settings.set("kbLayouts", cur.filter(v => v !== modelData.value));
                    }
                }
            }
            Note { text: Tr.t("inst.kbHint") }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── 3: Wi-Fi ─────────────
    readonly property var wifiDevice: {
        const list = Networking.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].type === DeviceType.Wifi) return list[i];
        return null;
    }
    readonly property var nets: {
        if (!wifiDevice) return [];
        return wifiDevice.networks.values.slice().sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        }).slice(0, 4);
    }
    property string wifiOpen: ""
    property string wifiError: ""

    Component {
        id: cWifi
        ColumnLayout {
            spacing: 8
            Component.onCompleted: if (win.wifiDevice) win.wifiDevice.scannerEnabled = true
            Component.onDestruction: if (win.wifiDevice) win.wifiDevice.scannerEnabled = false

            Repeater {
                model: win.nets
                ColumnLayout {
                    id: wnet
                    required property var modelData
                    readonly property bool open: modelData.security === WifiSecurityType.Open
                    Layout.fillWidth: true
                    spacing: 6

                    Connections {
                        target: wnet.modelData
                        function onConnectionFailed(reason) {
                            win.wifiOpen = wnet.modelData.name;
                            win.wifiError = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout
                                ? Tr.t("wifi.wrongPassword") : Tr.t("wifi.failed");
                        }
                    }

                    IRow {
                        text: wnet.modelData.name
                        trail: (wnet.modelData.connected ? Tr.t("wifi.connected") : wnet.open ? Tr.t("wifi.open") : "WPA2") + " · "
                            + ["▂", "▂▄", "▂▄▆", "▂▄▆█"][Math.min(3, Math.floor(wnet.modelData.signalStrength * 4))]
                        on: wnet.modelData.connected
                        onClicked: {
                            win.wifiError = "";
                            if (wnet.modelData.connected) return;
                            if (wnet.modelData.known || wnet.open) wnet.modelData.connect();
                            else win.wifiOpen = win.wifiOpen === wnet.modelData.name ? "" : wnet.modelData.name;
                        }
                    }

                    Rectangle {
                        visible: win.wifiOpen === wnet.modelData.name && !wnet.modelData.connected
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 8
                        color: Theme.inset
                        border.width: 1
                        border.color: win.wifiError !== "" ? Theme.error : (psk.activeFocus ? Theme.accentBorder : Theme.hairlineStrong)

                        TextInput {
                            id: psk
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 13
                            focus: parent.visible
                            Keys.onReturnPressed: event => { if (text.length >= 8) wnet.modelData.connectWithPsk(text); event.accepted = true; }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: psk.text.length === 0
                                text: win.wifiError !== "" ? win.wifiError : Tr.t("wifi.password")
                                color: win.wifiError !== "" ? Theme.error : Theme.textSubtle
                                font: psk.font
                            }
                        }
                    }
                }
            }
            Note { visible: win.nets.length === 0; text: win.wifiDevice ? Tr.t("inst.noNet") : Tr.t("wifi.noAdapter") }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── 4: диск ─────────────
    Component {
        id: cDisk
        ColumnLayout {
            spacing: 8

            Repeater {
                model: win.disks
                IRow {
                    required property var modelData
                    text: (modelData.model || modelData.path)
                    trail: win.gb(modelData.size) + (modelData.busy ? " · " + Tr.t("inst.diskBusy") : "")
                    on: win.diskPath === modelData.path
                    disabled: modelData.busy
                    onClicked: win.diskPath = modelData.path
                }
            }
            Note { visible: win.disksLoaded && win.disks.length === 0; text: Tr.t("inst.noDisks") }
            Note { visible: win.disks.some(d => d.busy); text: Tr.t("inst.busyHint") }

            IRow {
                text: Tr.t("inst.modeErase"); hint: Tr.t("inst.modeEraseHint")
                on: win.mode === "erase"
                onClicked: win.mode = "erase"
            }
            IRow {
                text: Tr.t("inst.modeAlong")
                hint: win.windows ? Tr.t("inst.modeAlongHint") : Tr.t("inst.noWindows")
                disabled: !win.windows
                on: win.mode === "alongside"
                onClicked: win.mode = "alongside"
            }
            IRow { text: Tr.t("inst.modeCustom"); hint: Tr.t("inst.modeCustomHint"); disabled: true }

            Note {
                visible: win.mode === "alongside" && win.windows && win.windows.bitlocker
                color: Theme.warning
                text: Tr.t("inst.blSteps")
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── 5: скільки віддати ─────────────
    Component {
        id: cAlong
        ColumnLayout {
            spacing: 12
            readonly property real total: win.windows ? win.windows.size / (1 << 30) : 1

            Row {
                Layout.fillWidth: true
                height: 34
                spacing: 0
                Rectangle {
                    width: (parent.width) * (1 - win.linuxGb / parent.parent.total)
                    height: parent.height
                    color: "#1e3a5f"
                    radius: 8
                    Text { anchors.centerIn: parent; color: "#d4d4d8"; font.family: Theme.font; font.pixelSize: 10
                        text: Tr.t("inst.winGb", Math.round(parent.parent.parent.total - win.linuxGb) + " GB") }
                }
                Rectangle {
                    width: parent.width * (win.linuxGb / parent.parent.total)
                    height: parent.height
                    radius: 8
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.emerald }
                        GradientStop { position: 1; color: Theme.cyan }
                    }
                    Text { anchors.centerIn: parent; color: Theme.textOnAccent; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold
                        text: Tr.t("inst.archGb", Math.round(win.linuxGb) + " GB") }
                }
            }
            VSlider {
                Layout.fillWidth: true
                value: (win.linuxGb - 40) / Math.max(1, win.maxGb - 40)
                onMoved: v => win.linuxGb = Math.round(40 + v * Math.max(0, win.maxGb - 40))
            }
            Note { text: Tr.t("inst.alongMin", "40 GB") }
            IRow { text: Tr.t("inst.swap"); trail: Tr.t("inst.swapZram"); disabled: true }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── 6: шпалери ─────────────
    FolderListModel {
        id: wallpapers
        folder: "file://" + win.home + "/.local/share/blackvarmir/wallpapers"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
    }

    Component {
        id: cLook
        GridLayout {
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: Math.min(4, wallpapers.count)
                WallpaperThumb {
                    required property int index
                    path: wallpapers.get(index, "filePath")
                    selected: (Settings.data.wallpaper || (win.home + "/.local/share/blackvarmir/wallpapers/varmir-aura.png")) === path
                    width: 134
                    height: 84
                    onPicked: Settings.set("wallpaper", path)
                }
            }
            Item { Layout.fillHeight: true; Layout.columnSpan: 2 }
        }
    }

    // ───────────── 7: користувач ─────────────
    Component {
        id: cUser
        ColumnLayout {
            spacing: 8
            Field { placeholder: Tr.t("inst.fullName"); text: win.fullName; onTextChanged: win.fullName = text }
            Field { placeholder: Tr.t("inst.userName"); text: win.userName; bad: win.userName !== "" && !win.nameOk; onTextChanged: win.userName = text }
            Field { placeholder: Tr.t("inst.hostName"); text: win.hostName; onTextChanged: win.hostName = text }
            Field { placeholder: Tr.t("inst.password"); secret: true; text: win.pw; onTextChanged: win.pw = text }
            Field { placeholder: Tr.t("inst.password2"); secret: true; text: win.pw2; bad: win.pw2 !== "" && !win.pwOk; onTextChanged: win.pw2 = text }
            Note { visible: win.userName !== "" && !win.nameOk; color: Theme.error; text: Tr.t("inst.errName") }
            Note { visible: win.pw2 !== "" && !win.pwOk; color: Theme.error; text: Tr.t("inst.errPw") }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── 8: підтвердження ─────────────
    Component {
        id: cConfirm
        ColumnLayout {
            spacing: 8
            Note { visible: win.plan === null; text: "…" }
            Note { visible: win.planError !== ""; color: Theme.error; text: win.planError }
            Repeater {
                model: win.plan && win.plan.ok ? win.plan.summary : []
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: sum.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: modelData.kind === "erased" ? Theme.error : modelData.kind === "created" ? Theme.accentBorder : Theme.hairline
                    Text {
                        id: sum
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        width: parent.width - 20
                        text: modelData.text
                        color: modelData.kind === "erased" ? Theme.error : "#e4e4e7"
                        font.family: Theme.font
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }
            }
            Note { visible: win.plan && win.plan.ok; color: Theme.warning; text: Tr.t("inst.confirmWarn") }
            Note { visible: win.dryRun; text: Tr.t("inst.dryRun") }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── 9: встановлення ─────────────
    Component {
        id: cRun
        ColumnLayout {
            spacing: 10
            readonly property int total: win.plan ? win.plan.steps.length : 1
            Rectangle {
                Layout.fillWidth: true
                height: 8
                radius: 4
                color: Qt.rgba(1, 1, 1, 0.08)
                Rectangle {
                    width: parent.width * Math.min(1, win.runIndex / parent.parent.total)
                    height: parent.height
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.emerald }
                        GradientStop { position: 1; color: Theme.cyan }
                    }
                    Behavior on width { NumberAnimation { duration: Theme.slow } }
                }
            }
            Repeater {
                model: win.plan && win.plan.ok ? win.plan.steps : []
                Text {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    text: (index < win.runIndex ? "✓ " : index === win.runIndex ? "▸ " : "· ") + modelData.title
                    color: index <= win.runIndex ? Theme.text : Theme.textSubtle
                    font.family: Theme.mono
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── 10: готово ─────────────
    Component {
        id: cDone
        ColumnLayout {
            spacing: 8
            Item { Layout.fillHeight: true }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 56
                height: 56
                radius: 28
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.emerald }
                    GradientStop { position: 1; color: Theme.cyan }
                }
                Text { anchors.centerIn: parent; text: "✓"; color: Theme.textOnAccent; font.pixelSize: 30 }
            }
            Note { visible: win.dryRun; horizontalAlignment: Text.AlignHCenter; text: Tr.t("inst.dryRun") }
            Item { Layout.fillHeight: true }
        }
    }
}
