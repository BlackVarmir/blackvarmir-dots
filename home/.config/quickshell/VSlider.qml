import QtQuick

// Повзунок 0…1 з градієнтною заливкою. Колесо миші — крок 5%.
Item {
    id: slider

    property real value: 0
    signal moved(real value)

    implicitHeight: 20

    function setFromX(x) {
        moved(Math.max(0, Math.min(1, x / width)));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.1)

        Rectangle {
            width: Math.max(height, track.width * slider.value)
            height: parent.height
            radius: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.emerald }
                GradientStop { position: 1; color: Theme.cyan }
            }
        }
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: (slider.width - width) * slider.value
        color: Theme.text
        border.width: area.containsMouse || area.pressed ? 4 : 0
        border.color: Theme.accentBorder
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => slider.setFromX(mouse.x)
        onPositionChanged: mouse => { if (pressed) slider.setFromX(mouse.x); }
        onWheel: wheel => slider.moved(Math.max(0, Math.min(1, slider.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
