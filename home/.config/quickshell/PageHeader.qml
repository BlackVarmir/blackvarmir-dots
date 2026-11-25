import QtQuick
import QtQuick.Layouts

// Заголовок підменю: «назад» · назва · елемент праворуч (перемикач, текст).
RowLayout {
    id: header

    property string title: ""
    default property alias trailing: slot.data
    signal back()

    spacing: 12

    Rectangle {
        width: 36
        height: 36
        radius: 10
        color: backArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Theme.hairline

        Text {
            anchors.centerIn: parent
            text: ""
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: 12
        }
        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: header.back()
        }
    }

    Text {
        Layout.fillWidth: true
        text: header.title
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 18
        font.weight: Font.DemiBold
    }

    Item {
        id: slot
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
