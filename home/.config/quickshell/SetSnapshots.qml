import QtQuick
import QtQuick.Layouts
import Quickshell

// Знімки: список, створення, відновлення, коли робити і скільки тримати.
SetPage {
    id: page

    title: Tr.t("set.snapshots")
    subtitle: Tr.t("snap.subtitle")

    property int confirm: 0            // номер знімка в діалозі відновлення
    property bool creating: false
    property string restoreError: ""

    Component.onCompleted: {
        Snapshots.refresh();
        if (Snapshots.restoreRequest > 0) { confirm = Snapshots.restoreRequest; Snapshots.restoreRequest = 0; }
    }
    Connections {
        target: Snapshots
        function onRestoreRequestChanged() { if (Snapshots.restoreRequest > 0) { page.confirm = Snapshots.restoreRequest; Snapshots.restoreRequest = 0; } }
        function onRestoreFinished(ok) { page.restoreError = ok ? "" : Tr.t("set.rootFailed"); if (!ok) page.confirm = 0; }
    }

    function when(d) {
        const now = new Date();
        const days = Math.floor((new Date(now.getFullYear(), now.getMonth(), now.getDate()) - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000);
        const time = Qt.formatTime(d, Settings.clock24 ? "HH:mm" : "h:mm AP");
        if (days === 0) return Tr.t("snap.today", time);
        if (days === 1) return Tr.t("snap.yesterday", time);
        return d.toLocaleDateString(Tr.locale, "d MMMM");
    }
    readonly property var confirmItem: Snapshots.list.find(s => s.number === confirm) ?? null

    // Не btrfs — пояснення замість розділу
    Text {
        visible: Snapshots.loaded && !Snapshots.available
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: Snapshots.error ? Tr.t("snap.notConfigured") : Tr.t("snap.noBtrfs")
        color: Theme.textMuted
        font.family: Theme.font
        font.pixelSize: 14
    }

    // Підсумок
    Rectangle {
        visible: Snapshots.available
        Layout.fillWidth: true
        implicitHeight: summary.implicitHeight + 28
        radius: 12
        color: Snapshots.bootedFrom > 0 ? Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.08) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.08)
        border.width: 1
        border.color: Snapshots.bootedFrom > 0 ? Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.3) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.25)
        RowLayout {
            id: summary
            x: 18
            y: 14
            width: parent.width - 36
            spacing: 12
            Text {
                text: Snapshots.bootedFrom > 0 ? "" : ""
                color: Snapshots.bootedFrom > 0 ? Theme.warning : Theme.emerald
                font.family: Theme.mono
                font.pixelSize: 16
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                text: {
                    if (Snapshots.bootedFrom > 0) return Tr.t("snap.bootedFrom", Snapshots.bootedFrom);
                    const last = Snapshots.list[0];
                    return (last ? Tr.t("snap.last", page.when(last.date), last.title.toLowerCase()) : Tr.t("snap.none"))
                        + " " + Tr.t("snap.free", Snapshots.freeSpace);
                }
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
            }
            VButton {
                visible: Snapshots.bootedFrom > 0
                text: Tr.t("snap.restoreThis")
                onClicked: page.confirm = Snapshots.bootedFrom
            }
        }
    }

    // Діалог відновлення
    Rectangle {
        visible: page.confirm > 0
        Layout.fillWidth: true
        implicitHeight: dlg.implicitHeight + 40
        radius: 16
        color: Theme.inset
        border.width: 1
        border.color: Theme.accentBorder
        ColumnLayout {
            id: dlg
            x: 22
            y: 20
            width: parent.width - 44
            spacing: 10
            Text {
                text: Tr.t("snap.confirmTitle", page.confirm)
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                text: Tr.t("snap.confirmBody", page.confirmItem ? page.when(page.confirmItem.date) : "", page.confirmItem?.title.toLowerCase() ?? "")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Tr.t("snap.confirmSafe")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
            }
            Text {
                visible: page.restoreError.length > 0
                text: page.restoreError
                color: Theme.error
                font.family: Theme.font
                font.pixelSize: 13
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                VButton { variant: "secondary"; text: Tr.t("common.cancel"); onClicked: page.confirm = 0 }
                VButton { text: Tr.t("snap.restoreReboot"); onClicked: Snapshots.restore(page.confirm) }
            }
        }
    }

    // Список
    SetCard {
        visible: Snapshots.available
        label: Tr.t("snap.eyebrow", Snapshots.list.length)

        SetRow {
            divider: false
            label: page.creating ? "" : Tr.t("snap.createHint")
            RowLayout {
                spacing: 8
                Rectangle {
                    visible: page.creating
                    implicitWidth: 300
                    implicitHeight: 36
                    radius: 8
                    color: Theme.inset
                    border.width: 1
                    border.color: Theme.accentBorder
                    TextInput {
                        id: newName
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                        maximumLength: 80
                        clip: true
                        onAccepted: { Snapshots.create(text.trim()); text = ""; page.creating = false; }
                        Keys.onEscapePressed: page.creating = false
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: newName.text.length === 0
                            text: Tr.t("snap.namePlaceholder")
                            color: Theme.textSubtle
                            font: newName.font
                        }
                    }
                }
                VButton {
                    variant: "secondary"
                    text: page.creating ? Tr.t("common.save") : "+ " + Tr.t("snap.create")
                    onClicked: {
                        if (!page.creating) { page.creating = true; newName.forceActiveFocus(); return; }
                        Snapshots.create(newName.text.trim());
                        newName.text = "";
                        page.creating = false;
                    }
                }
            }
        }

        Repeater {
            model: Snapshots.list
            Item {
                id: item
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 64

                Rectangle { width: parent.width; height: 1; color: Theme.hairline }
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    color: area.containsMouse || item.modelData.number === Snapshots.bootedFrom ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.06) : "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 14
                    spacing: 14

                    Text {
                        Layout.preferredWidth: 40
                        text: "#" + item.modelData.number
                        color: Theme.textSubtle
                        font.family: Theme.mono
                        font.pixelSize: 13
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: item.modelData.title + (item.modelData.pinned ? "  " : "")
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 14
                        }
                        Text {
                            visible: item.modelData.detail.length > 0
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: item.modelData.detail
                            color: Theme.textSubtle
                            font.family: Theme.mono
                            font.pixelSize: 11
                        }
                    }
                    Rectangle {
                        implicitWidth: tag.implicitWidth + 16
                        implicitHeight: 20
                        radius: 10
                        color: item.modelData.auto ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                        Text {
                            id: tag
                            anchors.centerIn: parent
                            text: item.modelData.auto ? Tr.t("snap.auto") : Tr.t("snap.manualTag")
                            color: item.modelData.auto ? Theme.emeraldLight : Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }
                    Text {
                        Layout.preferredWidth: 140
                        horizontalAlignment: Text.AlignRight
                        text: page.when(item.modelData.date)
                        color: Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                    Row {
                        Layout.preferredWidth: 170
                        layoutDirection: Qt.RightToLeft
                        spacing: 6
                        opacity: area.containsMouse || item.index === 0 ? 1 : 0
                        VButton { variant: "secondary"; text: Tr.t("snap.restore"); onClicked: page.confirm = item.modelData.number }
                        IconButton { glyph: ""; tip: Tr.t("snap.delete"); onClicked: Snapshots.remove(item.modelData.number) }
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }

    // Коли робити
    SetCard {
        visible: Snapshots.available
        label: Tr.t("snap.whenEyebrow")

        SetRow {
            divider: false
            label: Tr.t("snap.beforeUpdates")
            hint: Tr.t("snap.beforeUpdatesHint")
            Toggle { checked: Snapshots.beforeUpdates; onToggled: v => Snapshots.setBeforeUpdates(v) }
        }
        SetRow {
            label: Tr.t("snap.dailyToggle")
            hint: Tr.t("snap.dailyHint")
            Toggle { checked: Snapshots.daily; onToggled: v => Snapshots.setDaily(v) }
        }
        SetRow {
            label: Tr.t("snap.keep")
            hint: Tr.t("snap.keepHint")
            Segmented {
                options: [5, 10, 20].map(n => ({ value: n, label: String(n) }))
                current: Snapshots.keep
                onPicked: v => Snapshots.setKeep(v)
            }
        }
    }
}
