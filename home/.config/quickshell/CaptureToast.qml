import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Мініатюра в правому нижньому куті після знімка або запису: 5 с, наведення тримає її.
// Також показує зворотний відлік таймера знімка.
Scope {
    id: toast

    property bool shown: false

    Connections {
        target: Capture
        function onToastRevChanged() {
            toast.shown = true;
            hideTimer.restart();
        }
    }
    Timer { id: hideTimer; interval: 5000; onTriggered: if (!hover.containsMouse) toast.shown = false }

    // Зворотний відлік
    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: Capture.countdown > 0
        implicitWidth: 120
        implicitHeight: 120
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "varmir-osd"
        Rectangle {
            anchors.fill: parent
            radius: 60
            color: Theme.glassStrong
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            Text {
                anchors.centerIn: parent
                text: Capture.countdown
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 52
                font.weight: Font.DemiBold
            }
        }
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: toast.shown || card.opacity > 0
        anchors { right: true; bottom: true }
        margins { right: 20; bottom: 20 }
        implicitWidth: 300
        implicitHeight: card.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "varmir-capture-toast"

        Rectangle {
            id: card
            width: 300
            height: col.implicitHeight + 20
            radius: 16
            color: Theme.glassStrong
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            opacity: toast.shown ? 1 : 0
            transform: Translate { x: toast.shown ? 0 : 24 }
            Behavior on opacity { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                onExited: hideTimer.restart()
            }

            Column {
                id: col
                x: 10
                y: 10
                width: parent.width - 20
                spacing: 10

                Rectangle {
                    width: parent.width
                    height: 150
                    radius: 10
                    color: Theme.panel
                    border.width: 1
                    border.color: Theme.hairline
                    clip: true
                    Image {
                        visible: !Capture.lastIsVideo
                        anchors.fill: parent
                        anchors.margins: 1
                        source: Capture.lastIsVideo || !Capture.lastFile ? "" : "file://" + Capture.lastFile
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                    }

                    // Перетягнути мініатюру (і знімок, і відео) у застосунок — як файл
                    Item {
                        id: dragProxy
                        anchors.fill: parent
                        Drag.active: dragArea.drag.active
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                        Drag.mimeData: ({ "text/uri-list": "file://" + Capture.lastFile + "\r\n" })
                        Drag.imageSourceSize: Qt.size(180, 112)
                        Drag.imageSource: Capture.lastIsVideo || !Capture.lastFile ? "" : "file://" + Capture.lastFile
                        Drag.onDragFinished: dropAction => { if (dropAction !== Qt.IgnoreAction) toast.shown = false; }
                    }
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: dragProxy
                        // Після перетягування повернути «привид» на місце
                        onReleased: { dragProxy.x = 0; dragProxy.y = 0; }
                        onEntered: hideTimer.stop()
                        onExited: hideTimer.restart()
                    }
                    Text {
                        visible: Capture.lastIsVideo
                        anchors.centerIn: parent
                        text: ""
                        color: Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: 34
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (edit.visible ? edit.width + 8 : 0) - folder.width - 8
                        elide: Text.ElideRight
                        text: Capture.lastIsVideo ? "  " + Tr.t("cap.videoSaved") : "  " + Tr.t("cap.inClipboard")
                        color: Theme.emerald
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    ToastButton {
                        id: edit
                        visible: !Capture.lastIsVideo
                        text: Tr.t("cap.edit")
                        onClicked: {
                            toast.shown = false;
                            Quickshell.execDetached(["satty", "--filename", Capture.lastFile, "--output-filename", Capture.lastFile, "--copy-command", "wl-copy"]);
                        }
                    }
                    ToastButton {
                        id: folder
                        text: Tr.t("cap.folder")
                        onClicked: {
                            toast.shown = false;
                            Quickshell.execDetached(["nautilus", "--select", Capture.lastFile]);
                        }
                    }
                }
            }
        }
    }

    component ToastButton: Rectangle {
        id: btn
        property string text: ""
        signal clicked()
        width: label.implicitWidth + 20
        height: 26
        radius: 13
        color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 12
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
