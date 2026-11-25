import QtQuick
import QtQuick.Layouts

// Картка налаштувань: «брова» зверху і рядки під нею.
Rectangle {
    id: card

    property string label: ""
    default property alias rows: rowsColumn.data

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight
    radius: Theme.radiusTile
    color: Qt.rgba(1, 1, 1, 0.035)
    border.width: 1
    border.color: Theme.hairline

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        Eyebrow {
            visible: card.label.length > 0
            Layout.leftMargin: 18
            Layout.topMargin: 10
            Layout.bottomMargin: 2
            text: card.label
        }

        ColumnLayout {
            id: rowsColumn
            Layout.fillWidth: true
            spacing: 0
        }
    }
}
