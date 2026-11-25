import QtQuick

// Маленька підказка під полем пароля: Caps Lock, кількість сповіщень.
Rectangle {
    id: chip

    property string glyph: ""
    property string text: ""
    property bool warn: false

    width: row.implicitWidth + 20
    height: 24
    radius: 12
    color: warn ? Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.12) : Qt.rgba(1, 1, 1, 0.06)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.glyph
            color: chip.warn ? Theme.warning : Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: 11
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            color: chip.warn ? Theme.warning : Theme.textMuted
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
