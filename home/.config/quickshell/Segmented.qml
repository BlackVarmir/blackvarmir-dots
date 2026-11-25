import QtQuick

// Сегментований перемикач: options — [{ value, label }], current — вибране значення.
Rectangle {
    id: seg

    property var options: []
    property var current
    signal picked(var value)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 36
    radius: 10
    color: Qt.rgba(1, 1, 1, 0.05)
    border.width: 1
    border.color: Theme.hairline

    Row {
        id: row
        x: 3
        y: 3

        Repeater {
            model: seg.options

            Rectangle {
                id: opt
                required property var modelData
                readonly property bool on: seg.current === modelData.value

                width: label.implicitWidth + 24
                height: 30
                radius: 8
                color: on ? Theme.accentSoft : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                border.width: on ? 1 : 0
                border.color: Theme.accentBorder

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: opt.modelData.label
                    color: opt.on ? Theme.emeraldLight : Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(opt.modelData.value)
                }
            }
        }
    }
}
