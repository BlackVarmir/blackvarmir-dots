import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

// Підменю Wi-Fi: список мереж, пароль прямо в рядку мережі.
// Сканування працює лише поки підменю відкрите.
ColumnLayout {
    id: page

    property var device: null
    signal back()

    // Яка мережа розгорнута (за назвою) і помилка підключення
    property string expanded: ""
    property string error: ""

    spacing: 10

    readonly property var networks: {
        if (!device) return [];
        return device.networks.values.slice().sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
    }

    Component.onCompleted: if (device) device.scannerEnabled = true
    Component.onDestruction: if (device) device.scannerEnabled = false

    PageHeader {
        Layout.fillWidth: true
        title: "Wi-Fi"
        onBack: page.back()
        Toggle {
            checked: Networking.wifiEnabled
            onToggled: v => Networking.wifiEnabled = v
        }
    }

    Eyebrow {
        text: page.device ? Tr.t("wifi.networks", page.networks.length) : Tr.t("wifi.noAdapter")
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 4
        model: page.networks

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property var net: modelData
            readonly property bool open: net.security === WifiSecurityType.Open
            readonly property bool isExpanded: page.expanded === net.name

            width: ListView.view.width
            height: col.implicitHeight + 20
            radius: 12
            color: net.connected ? Theme.accentSoft
                : isExpanded ? Qt.rgba(1, 1, 1, 0.05)
                : rowArea.containsMouse ? Theme.hover : "transparent"
            border.width: net.connected || isExpanded ? 1 : 0
            border.color: net.connected ? Theme.accentBorder : Theme.hairlineStrong

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    page.error = "";
                    if (row.isExpanded) {
                        page.expanded = "";
                    } else if (!row.net.connected && (row.net.known || row.open)) {
                        row.net.connect();
                    } else {
                        page.expanded = row.net.name;
                    }
                }
            }

            Connections {
                target: row.net
                function onConnectionFailed(reason) {
                    page.expanded = row.net.name;
                    page.error = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout
                        ? Tr.t("wifi.wrongPassword") : Tr.t("wifi.failed");
                }
            }

            ColumnLayout {
                id: col
                x: 12
                y: 10
                width: parent.width - 24
                spacing: 10

                RowLayout {
                    spacing: 12
                    Text {
                        text: ""
                        color: row.net.connected ? Theme.emerald : Theme.textMuted
                        opacity: 0.35 + 0.65 * row.net.signalStrength
                        font.family: Theme.mono
                        font.pixelSize: 15
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: row.net.name
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: row.net.connected ? Font.DemiBold : Font.Normal
                        }
                        Text {
                            text: row.net.stateChanging ? Tr.t("wifi.connecting")
                                : row.net.connected ? Tr.t("wifi.connected")
                                : row.open ? Tr.t("wifi.open")
                                : row.net.known ? Tr.t("wifi.saved") : Tr.t("wifi.secured")
                            color: Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                    Text {
                        visible: !row.open && !row.net.connected
                        text: ""
                        color: Theme.textSubtle
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                    Text {
                        visible: row.net.connected
                        text: ""
                        color: Theme.emerald
                        font.family: Theme.mono
                        font.pixelSize: 13
                    }
                }

                // Пароль для нової захищеної мережі
                ColumnLayout {
                    visible: row.isExpanded && !row.net.connected
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 8
                        color: Theme.inset
                        border.width: 1
                        border.color: page.error !== "" ? Theme.error : (psk.activeFocus ? Theme.accentBorder : Theme.hairlineStrong)

                        TextInput {
                            id: psk
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 14
                            focus: row.isExpanded
                            onAccepted: if (text.length >= 8) row.net.connectWithPsk(text)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: psk.text.length === 0
                                text: Tr.t("wifi.password")
                                color: Theme.textSubtle
                                font: psk.font
                            }
                        }
                    }
                    Text {
                        visible: page.error !== ""
                        text: page.error
                        color: Theme.error
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 8
                        VButton { text: Tr.t("common.cancel"); variant: "ghost"; onClicked: page.expanded = "" }
                        VButton {
                            text: Tr.t("wifi.connect")
                            opacity: psk.text.length >= 8 ? 1 : 0.5
                            onClicked: if (psk.text.length >= 8) row.net.connectWithPsk(psk.text)
                        }
                    }
                }

                // Дії для підключеної мережі
                RowLayout {
                    visible: row.isExpanded && row.net.connected
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    VButton { text: Tr.t("wifi.forget"); variant: "ghost"; onClicked: { row.net.forget(); page.expanded = ""; } }
                    VButton { text: Tr.t("wifi.disconnect"); variant: "secondary"; onClicked: { row.net.disconnect(); page.expanded = ""; } }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: Tr.t("wifi.hint")
        color: Theme.textSubtle
        font.family: Theme.font
        font.pixelSize: 12
    }
}
