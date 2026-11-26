import QtQuick
import QtQuick.Layouts

// Підменю VPN: тунелі NetworkManager (WireGuard і плагіни VPN) і додавання нового.
// Активними можуть бути кілька тунелів одразу: кожен WireGuard — окремий інтерфейс.
ColumnLayout {
    id: page

    signal back()

    // Режим додавання: «file» — шлях до .conf, «paste» — вставити вміст конфігу
    property string addMode: "file"
    // Тунель, для якого чекаємо підтвердження видалення
    property string confirmDelete: ""

    spacing: 10

    Component.onCompleted: Vpn.refresh()

    PageHeader {
        Layout.fillWidth: true
        title: "VPN"
        onBack: page.back()
        Text {
            text: Vpn.activeCount > 0 ? Tr.t("vpn.activeCount", Vpn.activeCount) : ""
            color: Theme.emerald
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    // Поле вводу в стилі Varmir (однорядкове або з прокруткою для вставки конфігу)
    component VField: Rectangle {
        id: fld
        property alias text: input.text
        property string placeholder: ""
        property bool multiline: false
        signal accepted()

        Layout.fillWidth: true
        implicitHeight: multiline ? 120 : 38
        radius: 8
        color: Theme.inset
        border.width: 1
        border.color: (input.activeFocus ? Theme.accentBorder : Theme.hairlineStrong)
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 1
            contentHeight: input.implicitHeight + 16
            boundsBehavior: Flickable.StopAtBounds
            interactive: fld.multiline

            TextEdit {
                id: input
                x: 12
                y: fld.multiline ? 8 : (fld.height - implicitHeight) / 2
                width: parent.width - 24
                wrapMode: fld.multiline ? TextEdit.Wrap : TextEdit.NoWrap
                selectByMouse: true
                color: Theme.text
                selectionColor: Theme.accentSoft
                font.family: fld.multiline ? Theme.mono : Theme.font
                font.pixelSize: fld.multiline ? 11 : 13
                Keys.onReturnPressed: event => {
                    if (fld.multiline) event.accepted = false;
                    else fld.accepted();
                }
                Text {
                    visible: input.text.length === 0
                    text: fld.placeholder
                    color: Theme.textMuted
                    font: input.font
                }
            }
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: sections.implicitHeight

        ColumnLayout {
            id: sections
            width: parent.width
            spacing: 6

            Eyebrow { text: Tr.t("vpn.tunnels") }

            Text {
                visible: Vpn.tunnels.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                wrapMode: Text.WordWrap
                text: Tr.t("vpn.empty")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: Vpn.tunnels

                Rectangle {
                    id: row
                    required property var modelData
                    readonly property var t: modelData
                    readonly property bool working: Vpn.pending === t.name

                    Layout.fillWidth: true
                    implicitHeight: 56
                    radius: 12
                    color: t.active ? Theme.accentSoft : "transparent"
                    border.width: t.active ? 1 : 0
                    border.color: Theme.accentBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            text: ""
                            color: row.t.active ? Theme.emerald : Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 15
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: row.t.name
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: row.t.active ? Font.DemiBold : Font.Normal
                            }
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: row.working ? Tr.t("vpn.working")
                                    : row.t.active ? Tr.t("vpn.connectedVia", row.t.device)
                                    : row.t.kind === "wireguard" ? "WireGuard" : "VPN"
                                color: Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        VButton {
                            visible: !row.working && !row.t.active
                            variant: page.confirmDelete === row.t.name ? "danger" : "ghost"
                            text: page.confirmDelete === row.t.name ? Tr.t("vpn.confirmDelete") : Tr.t("vpn.delete")
                            onClicked: {
                                if (page.confirmDelete === row.t.name) {
                                    page.confirmDelete = "";
                                    Vpn.remove(row.t.name);
                                } else {
                                    page.confirmDelete = row.t.name;
                                }
                            }
                        }
                        VButton {
                            visible: !row.working
                            variant: row.t.active ? "ghost" : "secondary"
                            text: row.t.active ? Tr.t("vpn.disconnect") : Tr.t("vpn.connect")
                            onClicked: {
                                page.confirmDelete = "";
                                Vpn.toggle(row.t);
                            }
                        }
                    }
                }
            }

            Text {
                visible: Vpn.error !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: Vpn.error
                color: Theme.error
                font.family: Theme.font
                font.pixelSize: 12
            }

            // ───────── Додати тунель ─────────
            Eyebrow { Layout.topMargin: 12; text: Tr.t("vpn.add") }

            Segmented {
                options: [
                    { value: "file", label: Tr.t("vpn.fromFile") },
                    { value: "paste", label: Tr.t("vpn.fromText") }
                ]
                current: page.addMode
                onPicked: v => page.addMode = v
            }

            VField {
                id: pathField
                visible: page.addMode === "file"
                placeholder: Tr.t("vpn.pathHint")
                onAccepted: addButton.clicked()
            }

            VField {
                id: nameField
                visible: page.addMode === "paste"
                placeholder: Tr.t("vpn.nameHint")
            }
            VField {
                id: textField
                visible: page.addMode === "paste"
                multiline: true
                placeholder: Tr.t("vpn.pasteHint")
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Tr.t("vpn.multiHint")
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 11
                }
                VButton {
                    id: addButton
                    variant: "primary"
                    enabled: !Vpn.busy
                    text: Tr.t("vpn.import")
                    onClicked: {
                        if (page.addMode === "file") {
                            Vpn.importFile(pathField.text);
                            pathField.text = "";
                        } else {
                            Vpn.importText(nameField.text, textField.text);
                            textField.text = "";
                            nameField.text = "";
                        }
                    }
                }
            }
        }
    }
}
