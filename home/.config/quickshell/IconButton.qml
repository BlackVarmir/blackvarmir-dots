import QtQuick

// Квадратна кнопка-значок 36×36 (гліф Nerd Font).
Rectangle {
    id: button

    property string glyph: ""
    property string tip: ""
    property bool accent: false
    signal clicked()

    implicitWidth: 36
    implicitHeight: 36
    radius: 10
    color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    scale: area.pressed ? 0.94 : 1

    Accessible.role: Accessible.Button
    Accessible.name: tip

    Text {
        anchors.centerIn: parent
        text: button.glyph
        color: button.accent ? Theme.emerald : Theme.textMuted
        font.family: Theme.mono
        font.pixelSize: 15
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
