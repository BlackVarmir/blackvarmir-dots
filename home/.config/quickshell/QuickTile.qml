import QtQuick

// Плитка швидкого налаштування. Клік по плитці — увімкнути/вимкнути,
// стрілка праворуч (якщо є підменю) — відкрити підменю.
Rectangle {
    id: tile

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool hasMenu: false
    signal clicked()
    signal menuRequested()

    implicitHeight: 64
    radius: Theme.radiusTile
    color: active ? Theme.accentSoft : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05))
    border.width: 1
    border.color: active ? Theme.accentBorder : Theme.hairline

    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }

    Text {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: tile.glyph
        color: tile.active ? Theme.emerald : Theme.textMuted
        font.family: Theme.mono
        font.pixelSize: 17
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: menuButton.visible ? menuButton.left : parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: tile.title
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: tile.subtitle
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    Rectangle {
        id: menuButton
        visible: tile.hasMenu
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 44
        radius: 9
        color: menuArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

        Text {
            anchors.centerIn: parent
            text: ""
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: 11
        }

        MouseArea {
            id: menuArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.menuRequested()
        }
    }
}
