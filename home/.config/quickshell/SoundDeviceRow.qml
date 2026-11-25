import QtQuick
import QtQuick.Layouts

// Рядок звукового пристрою: клік робить його основним.
Item {
    id: row

    required property var node
    property string title: ""
    property bool active: false
    property bool divider: true
    signal chosen()

    Layout.fillWidth: true
    implicitHeight: 56

    Rectangle {
        visible: row.divider
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 10
        color: row.active ? Theme.accentSoft : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 14

        Text {
            text: row.node.isSink ? "" : ""
            color: row.active ? Theme.emerald : Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: 15
            Layout.preferredWidth: 18
        }
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: row.title
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: row.active ? Font.DemiBold : Font.Normal
        }
        Text {
            visible: row.active
            text: Tr.t("sound.inUse")
            color: Theme.emerald
            font.family: Theme.font
            font.pixelSize: 13
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.chosen()
    }
}
