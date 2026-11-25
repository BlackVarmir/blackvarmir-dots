import QtQuick

// Перемикач у стилі Varmir Design System: увімкнений заливається фірмовим градієнтом.
Item {
    id: toggle

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        border.color: Theme.hairlineStrong
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        opacity: toggle.checked ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.emerald }
            GradientStop { position: 1; color: Theme.cyan }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.base } }
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        y: 3
        x: toggle.checked ? toggle.width - width - 3 : 3
        color: toggle.checked ? Theme.textOnAccent : Theme.text
        Behavior on x { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled(!toggle.checked)
    }
}
