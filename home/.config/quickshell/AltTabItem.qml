import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Картка вікна в Alt + Tab: знімок вікна, значок застосунку, назва.
Item {
    id: item

    required property var toplevel
    property bool selected: false
    property bool otherWorkspace: false
    signal hovered()
    signal chosen()

    readonly property var ipc: toplevel.lastIpcObject ?? ({})
    // Порожній клас дав би випадковий застосунок зі списку (значок і назва «Qt V4L2 test Utility»)
    readonly property var entry: (ipc.class ?? "") !== "" ? DesktopEntries.heuristicLookup(ipc.class) : null
    readonly property real aspect: (ipc.size?.[0] ?? 16) / Math.max(1, ipc.size?.[1] ?? 10)

    width: 220
    height: 160

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: item.selected ? Theme.accentSoft : area.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        border.width: item.selected ? 2 : 0
        border.color: Theme.emerald
    }

    // Знімок робиться один раз при відкритті перемикача: живе відео тут не потрібне
    Rectangle {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10 + (124 - height) / 2
        width: item.aspect >= 200 / 124 ? 200 : 124 * item.aspect
        height: item.aspect >= 200 / 124 ? 200 / item.aspect : 124
        radius: 10
        color: "#111113"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        clip: true

        ScreencopyView {
            anchors.fill: parent
            anchors.margins: 1
            captureSource: item.toplevel.wayland
            live: false
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        spacing: 8
        width: Math.min(implicitWidth, 200)

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 18
            source: Quickshell.iconPath(item.entry?.icon ?? "", "application-x-executable")
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 200 - 26 - (ws.visible ? ws.width + 8 : 0))
            elide: Text.ElideRight
            text: item.ipc.title || item.entry?.name || item.ipc.class || ""
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }
        Text {
            id: ws
            visible: item.otherWorkspace
            anchors.verticalCenter: parent.verticalCenter
            text: item.ipc.workspace?.id ?? ""
            color: Theme.textSubtle
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onEntered: item.hovered()
        onClicked: item.chosen()
    }
}
