import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

// Рядок пристрою Bluetooth з однією дією: підключити / відключити / з'єднати.
Rectangle {
    id: row

    required property var device
    property string glyph: ""

    readonly property bool busy: device.pairing || device.state === BluetoothDeviceState.Connecting

    implicitHeight: 56
    radius: 12
    color: device.connected ? Theme.accentSoft : (area.containsMouse ? Theme.hover : "transparent")
    border.width: device.connected ? 1 : 0
    border.color: Theme.accentBorder

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 12

        Text {
            text: row.glyph
            color: row.device.connected ? Theme.emerald : Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: 16
            Layout.preferredWidth: 18
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: row.device.name || row.device.address
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: row.device.connected ? Font.DemiBold : Font.Normal
            }
            Text {
                text: row.busy ? "З'єднання…"
                    : row.device.connected
                        ? (row.device.batteryAvailable ? "Підключено · заряд " + Math.round(row.device.battery * 100) + "%" : "Підключено")
                    : row.device.paired ? "Не підключено" : "Готовий до з'єднання"
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        VButton {
            visible: !row.busy
            variant: row.device.connected ? "ghost" : "secondary"
            text: row.device.connected ? "Відключити" : row.device.paired ? "Підключити" : "З'єднати"
            onClicked: {
                if (row.device.connected) {
                    row.device.disconnect();
                } else if (row.device.paired) {
                    row.device.connect();
                } else {
                    row.device.trusted = true;
                    row.device.pair();
                }
            }
        }
    }
}
