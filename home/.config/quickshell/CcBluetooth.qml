import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

// Підменю Bluetooth: підключені, запам'ятовані і пристрої поруч.
// Пошук нових пристроїв іде лише поки підменю відкрите, щоб не садити батарею.
ColumnLayout {
    id: page

    property var adapter: null
    signal back()

    spacing: 10

    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var connectedList: devices.filter(d => d.connected)
    readonly property var pairedList: devices.filter(d => d.paired && !d.connected)
    readonly property var nearbyList: devices.filter(d => !d.paired && !d.connected)

    Component.onCompleted: if (adapter && adapter.enabled) adapter.discovering = true
    Component.onDestruction: if (adapter) adapter.discovering = false

    function glyphFor(icon) {
        if (icon.indexOf("audio") !== -1 || icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1) return "";
        if (icon.indexOf("keyboard") !== -1) return "";
        if (icon.indexOf("mouse") !== -1) return "";
        if (icon.indexOf("phone") !== -1) return "";
        if (icon.indexOf("computer") !== -1) return "";
        return "";
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        onBack: page.back()
        Toggle {
            checked: page.adapter?.enabled ?? false
            onToggled: v => {
                if (!page.adapter) return;
                page.adapter.enabled = v;
                page.adapter.discovering = v;
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

            Eyebrow { visible: page.connectedList.length > 0; text: "ПІДКЛЮЧЕНІ" }
            Repeater {
                model: page.connectedList
                BtRow { required property var modelData; device: modelData; glyph: page.glyphFor(modelData.icon); Layout.fillWidth: true }
            }

            Eyebrow { visible: page.pairedList.length > 0; text: "ЗАПАМ'ЯТОВАНІ" }
            Repeater {
                model: page.pairedList
                BtRow { required property var modelData; device: modelData; glyph: page.glyphFor(modelData.icon); Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: page.adapter?.enabled ?? false
                Eyebrow { Layout.fillWidth: true; text: "ПОРУЧ" }
                Text {
                    text: (page.adapter?.discovering ?? false) ? "пошук…" : ""
                    color: Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }
            Repeater {
                model: page.nearbyList
                BtRow { required property var modelData; device: modelData; glyph: page.glyphFor(modelData.icon); Layout.fillWidth: true }
            }

            Text {
                visible: !(page.adapter?.enabled ?? false)
                Layout.fillWidth: true
                Layout.topMargin: 20
                horizontalAlignment: Text.AlignHCenter
                text: page.adapter ? "Bluetooth вимкнено" : "Адаптер Bluetooth не знайдено"
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 14
            }
        }
    }
}
