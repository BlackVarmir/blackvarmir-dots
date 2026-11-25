import QtQuick
import QtQuick.Layouts

// Рядок налаштування: назва і пояснення ліворуч, елемент керування праворуч.
// stacked: true — елемент керування під назвою на всю ширину (для сегментованих перемикачів).
Item {
    id: row

    property string label: ""
    property string hint: ""
    property bool stacked: false
    property bool divider: true
    default property alias control: slot.data

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + 26

    Rectangle {
        visible: row.divider
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    GridLayout {
        id: layout
        x: 18
        y: 13
        width: parent.width - 36
        columns: row.stacked ? 1 : 2
        rowSpacing: 10
        columnSpacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: row.label
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
            }
            Text {
                Layout.fillWidth: true
                visible: row.hint.length > 0
                text: row.hint
                wrapMode: Text.Wrap
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        Item {
            id: slot
            Layout.alignment: row.stacked ? Qt.AlignLeft : Qt.AlignRight | Qt.AlignVCenter
            Layout.fillWidth: row.stacked
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
