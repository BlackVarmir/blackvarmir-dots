import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Панель знімків на одному моніторі: затемнення, вибір області / вікна / екрана
// і панель інструментів унизу (лише на моніторі з фокусом).
PanelWindow {
    id: ov

    required property var modelData
    screen: modelData

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === screen?.name
    readonly property var monitor: Hyprland.monitorFor(screen)

    visible: Panels.captureOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "varmir-capture"
    WlrLayershell.keyboardFocus: focusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Виділена область у локальних координатах монітора
    property rect sel: Qt.rect(0, 0, 0, 0)
    readonly property bool hasSel: sel.width > 4 && sel.height > 4
    property var hoverWindow: null

    onVisibleChanged: {
        sel = Qt.rect(0, 0, 0, 0);
        hoverWindow = null;
        if (visible) Hyprland.refreshToplevels();
    }

    // Вікна на активному столі цього монітора (для режиму «Вікно»), верхні першими
    readonly property var windows: {
        const ws = monitor?.activeWorkspace?.id;
        return Hyprland.toplevels.values
            .map(t => t.lastIpcObject ?? {})
            .filter(o => o.workspace?.id === ws && o.mapped !== false && o.at && o.size)
            .sort((a, b) => (a.focusHistoryID ?? 99) - (b.focusHistoryID ?? 99));
    }

    function globalGeometry(r) {
        const x = Math.round(r.x + screen.x), y = Math.round(r.y + screen.y);
        return `${x},${y} ${Math.round(r.width)}x${Math.round(r.height)}`;
    }

    function windowAt(px, py) {
        const gx = px + screen.x, gy = py + screen.y;
        return windows.find(o => gx >= o.at[0] && gx < o.at[0] + o.size[0] && gy >= o.at[1] && gy < o.at[1] + o.size[1]) ?? null;
    }

    function capture() {
        if (Capture.mode === "screen") Capture.take({ output: screen.name });
        else if (Capture.mode === "window" && hoverWindow)
            Capture.take({ geometry: `${hoverWindow.at[0]},${hoverWindow.at[1]} ${hoverWindow.size[0]}x${hoverWindow.size[1]}` });
        else if (Capture.mode === "region" && hasSel) Capture.take({ geometry: globalGeometry(sel) });
    }

    // Затемнення; у режимі «Область» вирізаємо виділене (чотири смуги навколо)
    Item {
        anchors.fill: parent
        readonly property bool cut: Capture.mode === "region" && ov.hasSel
        Rectangle { visible: !parent.cut; anchors.fill: parent; color: Qt.rgba(0, 0, 0, Capture.mode === "screen" && !ov.focusedScreen ? 0.55 : 0.4) }
        Rectangle { visible: parent.cut; x: 0; y: 0; width: parent.width; height: ov.sel.y; color: Qt.rgba(0, 0, 0, 0.45) }
        Rectangle { visible: parent.cut; x: 0; y: ov.sel.y + ov.sel.height; width: parent.width; height: parent.height - y; color: Qt.rgba(0, 0, 0, 0.45) }
        Rectangle { visible: parent.cut; x: 0; y: ov.sel.y; width: ov.sel.x; height: ov.sel.height; color: Qt.rgba(0, 0, 0, 0.45) }
        Rectangle { visible: parent.cut; x: ov.sel.x + ov.sel.width; y: ov.sel.y; width: parent.width - x; height: ov.sel.height; color: Qt.rgba(0, 0, 0, 0.45) }
    }

    // Рамка області
    Rectangle {
        visible: Capture.mode === "region" && ov.hasSel
        x: ov.sel.x; y: ov.sel.y; width: ov.sel.width; height: ov.sel.height
        color: Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.04)
        border.width: 1.5
        border.color: Theme.emerald

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            width: size.implicitWidth + 16
            height: 22
            radius: 6
            color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.85)
            Text {
                id: size
                anchors.centerIn: parent
                text: Math.round(ov.sel.width * (ov.monitor?.scale ?? 1)) + " × " + Math.round(ov.sel.height * (ov.monitor?.scale ?? 1))
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: 12
            }
        }
    }

    // Підсвітка вікна під курсором
    Rectangle {
        visible: Capture.mode === "window" && ov.hoverWindow !== null
        x: (ov.hoverWindow?.at[0] ?? 0) - ov.screen.x
        y: (ov.hoverWindow?.at[1] ?? 0) - ov.screen.y
        width: ov.hoverWindow?.size[0] ?? 0
        height: ov.hoverWindow?.size[1] ?? 0
        radius: 12
        color: Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.10)
        border.width: 2
        border.color: Theme.emerald
    }

    // Підсвітка екрана
    Rectangle {
        visible: Capture.mode === "screen" && area.containsMouse
        anchors.fill: parent
        color: "transparent"
        border.width: 3
        border.color: Theme.emerald
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Capture.mode === "region" ? Qt.CrossCursor : Qt.PointingHandCursor

        property point origin
        property bool moving: false
        property rect startSel

        onPositionChanged: mouse => {
            if (Capture.mode === "window") { ov.hoverWindow = ov.windowAt(mouse.x, mouse.y); return; }
            if (Capture.mode !== "region" || !pressed) return;
            if (moving) {
                ov.sel = Qt.rect(
                    Math.max(0, Math.min(ov.width - startSel.width, startSel.x + mouse.x - origin.x)),
                    Math.max(0, Math.min(ov.height - startSel.height, startSel.y + mouse.y - origin.y)),
                    startSel.width, startSel.height);
            } else {
                ov.sel = Qt.rect(Math.min(origin.x, mouse.x), Math.min(origin.y, mouse.y),
                    Math.abs(mouse.x - origin.x), Math.abs(mouse.y - origin.y));
            }
        }
        onPressed: mouse => {
            if (Capture.mode !== "region") return;
            origin = Qt.point(mouse.x, mouse.y);
            // Натиск усередині виділення — пересунути його, інакше малювати нове
            moving = ov.hasSel && mouse.x >= ov.sel.x && mouse.x <= ov.sel.x + ov.sel.width
                && mouse.y >= ov.sel.y && mouse.y <= ov.sel.y + ov.sel.height;
            startSel = ov.sel;
        }
        onClicked: if (Capture.mode !== "region") ov.capture()
        onDoubleClicked: if (Capture.mode === "region" && ov.hasSel) ov.capture()
    }

    // Клавіші
    Item {
        anchors.fill: parent
        focus: ov.focusedScreen
        Keys.onEscapePressed: Panels.captureOpen = false
        Keys.onReturnPressed: ov.capture()
        Keys.onEnterPressed: ov.capture()
    }

    // Панель інструментів
    CaptureToolbar {
        visible: ov.focusedScreen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        canCapture: Capture.mode === "screen" || (Capture.mode === "region" && ov.hasSel) || (Capture.mode === "window" && ov.hoverWindow !== null)
        onCaptureRequested: ov.capture()
    }
}
