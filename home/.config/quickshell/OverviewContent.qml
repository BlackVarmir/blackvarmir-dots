import QtQuick
import Quickshell
import Quickshell.Hyprland

// Вміст огляду. Живе лише поки огляд відкритий.
Item {
    id: root

    required property var monitor

    // Пошук і вибір з клавіатури
    property string query: ""
    property int selectedWs: monitor?.activeWorkspace?.id ?? 1
    property string selectedAddr: ""
    property string dropTarget: ""

    // Логічний розмір монітора (з урахуванням масштабу) для пропорцій мініатюр
    readonly property real monW: (monitor?.width ?? 1920) / (monitor?.scale ?? 1)
    readonly property real monH: (monitor?.height ?? 1080) / (monitor?.scale ?? 1)
    // Скільки столів показуємо і в скількох колонках; картки стискаються, щоб усе вмістилося
    readonly property var wsIds: Workspaces.ids
    readonly property int cols: wsIds.length <= 6 ? 3 : 4
    readonly property int rows: Math.ceil(wsIds.length / cols)
    readonly property real cardW: {
        const byWidth = (width - 236 - 64) / cols;
        // висота під сіткою: пошук зверху, підказки й док знизу, підпис картки ≈ 30 px
        const free = height - 150 - 52 - 28 - 20 - 130 - rows * 30 - (rows - 1) * 44;
        return Math.max(160, Math.min(540, byWidth, free / rows * monW / monH));
    }
    readonly property real cardH: cardW * monH / monW

    readonly property var allWindows: Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? 0) > 0)

    function windowLabel(t) {
        const cls = t.lastIpcObject?.class ?? "";
        return t.title || cls || Tr.t("overview.window");
    }
    function matches(t) {
        if (query.length === 0) return true;
        const q = query.toLowerCase();
        return windowLabel(t).toLowerCase().indexOf(q) !== -1
            || String(t.lastIpcObject?.class ?? "").toLowerCase().indexOf(q) !== -1;
    }
    readonly property var matched: allWindows.filter(t => matches(t))

    onQueryChanged: {
        if (query.length > 0 && matched.length > 0) {
            selectedAddr = matched[0].address;
            selectedWs = matched[0].workspace?.id ?? selectedWs;
        } else {
            selectedAddr = "";
        }
    }

    function sel(addr) { return `address:0x${addr}`; }

    function focusWindow(t) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "${sel(t.address)}" })`);
        Panels.overviewOpen = false;
    }
    function closeWindow(t) {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "${sel(t.address)}" })`);
        refreshSoon.restart();
    }
    function moveWindow(addr, wsId) {
        Hyprland.dispatch(`hl.dsp.window.move({ window = "${sel(addr)}", workspace = ${wsId}, follow = false })`);
        refreshSoon.restart();
    }
    function goToWorkspace(wsId) {
        Workspaces.go(wsId);
        Panels.overviewOpen = false;
    }
    // Стрілки: крок по списку наявних столів (вбік на 1, вгору/вниз на ряд)
    function stepWorkspace(delta) {
        const i = wsIds.indexOf(selectedWs);
        const j = i + delta;
        if (j >= 0 && j < wsIds.length) selectedWs = wsIds[j];
        selectedAddr = "";
    }
    function activateSelection() {
        if (selectedAddr !== "") {
            const t = allWindows.find(w => w.address === selectedAddr);
            if (t) { focusWindow(t); return; }
        }
        goToWorkspace(selectedWs);
    }
    function cycleWindow(step) {
        const pool = (query.length > 0 ? matched : allWindows.filter(t => t.workspace?.id === selectedWs));
        if (pool.length === 0) return;
        let i = pool.findIndex(t => t.address === selectedAddr);
        i = (i + step + pool.length) % pool.length;
        selectedAddr = pool[i].address;
        selectedWs = pool[i].workspace?.id ?? selectedWs;
    }

    Timer {
        id: refreshSoon
        interval: 150
        onTriggered: Hyprland.refreshToplevels()
    }

    // Фон: затемнення поверх живого розмитого столу
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(8 / 255, 8 / 255, 10 / 255, 0.72)
        MouseArea {
            anchors.fill: parent
            onClicked: Panels.overviewOpen = false
        }
    }

    // ───────────── Пошук ─────────────
    Rectangle {
        id: searchBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: 44
        width: 520
        height: 44
        radius: Theme.radiusIsland
        color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.8)
        border.width: 1
        border.color: root.query.length > 0 ? Theme.accentBorder : Theme.hairlineStrong

        Text {
            id: searchGlyph
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: root.query.length > 0 ? Theme.emerald : Theme.textSubtle
            font.family: Theme.mono
            font.pixelSize: 15
        }

        TextInput {
            id: search
            anchors.left: searchGlyph.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
            onTextChanged: root.query = text
            Component.onCompleted: forceActiveFocus()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text.length === 0
                text: Tr.t("overview.search")
                color: Theme.textSubtle
                font: search.font
            }

            Keys.onPressed: event => {
                const k = event.key;
                if (k === Qt.Key_Escape) {
                    if (dock.menuIndex >= 0) dock.closeMenu();
                    else if (search.text.length > 0) search.text = "";
                    else Panels.overviewOpen = false;
                } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                    root.activateSelection();
                } else if (k === Qt.Key_Left) {
                    root.stepWorkspace(-1);
                } else if (k === Qt.Key_Right) {
                    root.stepWorkspace(1);
                } else if (k === Qt.Key_Up) {
                    root.stepWorkspace(-root.cols);
                } else if (k === Qt.Key_Down) {
                    root.stepWorkspace(root.cols);
                } else if (k === Qt.Key_Tab) {
                    root.cycleWindow(1);
                } else if (k === Qt.Key_Backtab) {
                    root.cycleWindow(-1);
                } else if (k === Qt.Key_Delete && root.selectedAddr !== "") {
                    const t = root.allWindows.find(w => w.address === root.selectedAddr);
                    if (t) root.closeWindow(t);
                    root.selectedAddr = "";
                } else if (search.text.length === 0 && k >= Qt.Key_0 && k <= Qt.Key_9) {
                    root.goToWorkspace(k === Qt.Key_0 ? 10 : k - Qt.Key_0);
                } else {
                    return;
                }
                event.accepted = true;
            }
        }
    }

    // ───────────── Сітка столів ─────────────
    Grid {
        id: grid
        anchors.horizontalCenter: parent.horizontalCenter
        y: searchBox.y + searchBox.height + 52
        columns: root.cols
        columnSpacing: 32
        rowSpacing: 44

        Repeater {
            model: root.wsIds

            WorkspaceCard {
                required property int modelData
                wsId: modelData
                overview: root
                width: root.cardW
            }
        }
    }

    // Підказки
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: grid.y + grid.height + 28
        spacing: 22

        Repeater {
            model: [["← → ↑ ↓", Tr.t("overview.kDesk")], ["Tab", Tr.t("overview.kWindow")], ["⏎", Tr.t("overview.kGo")], ["1…0", Tr.t("overview.kJump")], ["Del", Tr.t("overview.kClose")], ["Esc", Tr.t("overview.kExit")]]
            Row {
                required property var modelData
                spacing: 7
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: keyText.implicitWidth + 12
                    height: 20
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    Text {
                        id: keyText
                        anchors.centerIn: parent
                        text: modelData[0]
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 11
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[1]
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }
        }
    }

    // Клік повз відкрите меню дока закриває лише меню, а не весь огляд
    MouseArea {
        anchors.fill: parent
        visible: dock.menuIndex >= 0
        z: 50
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: dock.closeMenu()
    }

    // ───────────── Док ─────────────
    Dock {
        id: dock
        z: 60
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        windows: root.allWindows
        onLaunched: Panels.overviewOpen = false
        onFocusRequested: t => root.focusWindow(t)
        onCloseRequested: t => root.closeWindow(t)
    }

    // ───────────── «Привид» вікна під час перетягування ─────────────
    Rectangle {
        id: ghost
        property string addr: ""
        property string label: ""
        visible: Drag.active
        width: 130
        height: 74
        radius: 8
        color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.92)
        border.width: 1
        border.color: Qt.rgba(34 / 255, 211 / 255, 238 / 255, 0.6)
        rotation: -3
        opacity: 0.92
        z: 100

        Drag.keys: ["varmir-window"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Text {
            anchors.centerIn: parent
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: ghost.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // Викликається з мініатюри вікна
    function beginDrag(t, sceneX, sceneY) {
        ghost.addr = t.address;
        ghost.label = windowLabel(t);
        ghost.x = sceneX - ghost.width / 2;
        ghost.y = sceneY - ghost.height / 2;
        ghost.Drag.active = true;
    }
    function updateDrag(sceneX, sceneY) {
        ghost.x = sceneX - ghost.width / 2;
        ghost.y = sceneY - ghost.height / 2;
    }
    function endDrag() {
        if (!ghost.Drag.active) return;
        ghost.Drag.drop();
        ghost.Drag.active = false;
        dropTarget = "";
    }
}
