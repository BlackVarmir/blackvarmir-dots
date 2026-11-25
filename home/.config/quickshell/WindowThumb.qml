import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Мініатюра вікна в огляді. Знімок вікна робиться один раз при відкритті;
// живе відео — лише для вікна під курсором (так дешевше для відеокарти).
Item {
    id: thumb

    required property var toplevel
    required property var overview
    required property real k // масштаб: пікселі картки / логічні пікселі монітора

    readonly property var ipc: toplevel.lastIpcObject ?? ({})
    readonly property var at: ipc.at ?? [0, 0]
    readonly property var size: ipc.size ?? [400, 300]
    readonly property real monX: overview.monitor?.x ?? 0
    readonly property real monY: overview.monitor?.y ?? 0

    readonly property bool hovered: area.containsMouse
    readonly property bool selected: overview.selectedAddr === toplevel.address
    readonly property bool dimmed: overview.query.length > 0 && !overview.matches(toplevel)
    readonly property string label: overview.windowLabel(toplevel)
    readonly property var entry: DesktopEntries.heuristicLookup(ipc.class ?? "")

    x: (at[0] - monX) * k
    y: (at[1] - monY) * k
    width: Math.max(24, size[0] * k)
    height: Math.max(18, size[1] * k)
    z: (ipc.floating ?? false) ? 2 : 1
    opacity: dimmed ? 0.35 : 1

    Behavior on opacity { NumberAnimation { duration: Theme.base } }

    Rectangle {
        anchors.fill: parent
        radius: 6
        clip: true
        color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.9)
        border.width: thumb.selected ? 2 : 1
        border.color: thumb.selected ? Theme.emerald
            : thumb.hovered ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.1)

        ScreencopyView {
            id: shot
            anchors.fill: parent
            anchors.margins: 1
            captureSource: thumb.toplevel.wayland
            live: thumb.hovered
        }

        // Поки знімка немає — значок застосунку
        IconImage {
            anchors.centerIn: parent
            visible: !shot.hasContent
            implicitSize: Math.min(28, parent.height * 0.5)
            source: Quickshell.iconPath(thumb.entry?.icon ?? "", "application-x-executable")
            asynchronous: true
        }
    }

    // Підпис під курсором або для вибраного вікна
    Rectangle {
        visible: thumb.hovered || thumb.selected
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: Math.min(parent.width - 12, caption.implicitWidth + 14)
        height: 20
        radius: 6
        color: Qt.rgba(10 / 255, 10 / 255, 11 / 255, 0.9)
        Text {
            id: caption
            anchors.centerIn: parent
            width: parent.width - 10
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: thumb.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property bool dragging: false
        property point pressPos

        onPressed: mouse => { pressPos = Qt.point(mouse.x, mouse.y); dragging = false; }
        onPositionChanged: mouse => {
            if (!pressed) return;
            const p = mapToItem(thumb.overview, mouse.x, mouse.y);
            if (!dragging && Math.abs(mouse.x - pressPos.x) + Math.abs(mouse.y - pressPos.y) > 8) {
                dragging = true;
                thumb.overview.beginDrag(thumb.toplevel, p.x, p.y);
            } else if (dragging) {
                thumb.overview.updateDrag(p.x, p.y);
            }
        }
        onReleased: {
            if (dragging) { thumb.overview.endDrag(); dragging = false; }
        }
        onClicked: if (!dragging) thumb.overview.focusWindow(thumb.toplevel)
    }

    // «×» — закрити саме це вікно
    Rectangle {
        visible: thumb.hovered && !area.dragging
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 5
        width: 20
        height: 20
        radius: 10
        color: closeArea.containsMouse ? "#f87171" : Theme.error
        Text {
            anchors.centerIn: parent
            text: "×"
            color: "#ffffff"
            font.pixelSize: 14
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: thumb.overview.closeWindow(thumb.toplevel)
        }
    }
}
