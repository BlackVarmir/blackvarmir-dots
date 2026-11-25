import QtQuick
import Quickshell.Widgets

// Мініатюра шпалер у налаштуваннях.
Item {
    id: thumb

    required property string path
    property bool selected: false
    signal picked()

    width: 170
    height: 96

    // Кільце вибору
    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        radius: 15
        color: "transparent"
        visible: thumb.selected
        border.width: 4
        border.color: Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.2)
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.inset
        border.width: thumb.selected ? 2 : 1
        border.color: thumb.selected ? Theme.emerald : (area.containsMouse ? Theme.hairlineStrong : Theme.hairline)

        Image {
            anchors.fill: parent
            source: "file://" + thumb.path
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 340
            asynchronous: true
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: thumb.picked()
    }
}
