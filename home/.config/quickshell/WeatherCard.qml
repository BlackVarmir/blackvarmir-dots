import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Налаштування погоди: автоматично (Wi-Fi / IP) або точка, знайдена пошуком OpenStreetMap.
SetCard {
    id: card

    label: Tr.t("wx.eyebrow")

    property var found: []
    property bool searching: false

    function search(q) {
        if (q.trim().length < 3) return;
        searching = true;
        finder.command = ["curl", "-fsS", "--max-time", "10", "-A", "BlackVarmir/1.0 (github.com/BlackVarmir/blackvarmir-dots)",
            "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&accept-language=" + Tr.lang + "&q=" + encodeURIComponent(q.trim())];
        finder.running = true;
    }

    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: {
                card.searching = false;
                try {
                    card.found = JSON.parse(text).map(r => ({ name: r.display_name, short: r.name || r.display_name.split(",")[0], lat: parseFloat(r.lat), lon: parseFloat(r.lon) }));
                } catch (e) { card.found = []; }
            }
        }
        onExited: code => { if (code !== 0) card.searching = false; }
    }

    SetRow {
        divider: false
        label: Tr.t("wx.where")
        hint: Weather.place
            ? Tr.t("wx.now", Weather.place, Tr.t("wx.src." + (Weather.source || "ip")))
            : Tr.t("wx.loading")
        Segmented {
            options: [{ value: "auto", label: Tr.t("wx.auto") }, { value: "manual", label: Tr.t("wx.manual") }]
            current: Settings.data.weatherMode
            onPicked: v => Settings.set("weatherMode", v)
        }
    }

    SetRow {
        visible: Settings.data.weatherMode === "manual"
        stacked: true
        label: Tr.t("wx.point")
        hint: Settings.data.weatherName ? Settings.data.weatherName : Tr.t("wx.pointHint")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 8
                color: Theme.inset
                border.width: 1
                border.color: query.activeFocus ? Theme.accentBorder : Theme.hairline
                TextInput {
                    id: query
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                    clip: true
                    onAccepted: card.search(text)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: query.text.length === 0
                        text: card.searching ? Tr.t("wx.searching") : Tr.t("wx.searchPlaceholder")
                        color: Theme.textSubtle
                        font: query.font
                    }
                }
            }

            Repeater {
                model: card.found
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 8
                    color: placeArea.containsMouse ? Theme.hover : "transparent"
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: modelData.name
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: placeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Settings.set("weatherName", parent.modelData.short);
                            Settings.set("weatherLon", parent.modelData.lon);
                            Settings.set("weatherLat", parent.modelData.lat);
                            card.found = [];
                            query.text = "";
                        }
                    }
                }
            }
        }
    }

    SetRow {
        label: Tr.t("wx.inBar")
        Toggle {
            checked: Settings.data.weatherInBar
            onToggled: v => Settings.set("weatherInBar", v)
        }
    }

    SetRow {
        visible: Settings.data.weatherMode === "auto"
        stacked: true
        label: Tr.t("wx.googleKey")
        hint: Tr.t("wx.googleKeyHint")
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 8
            color: Theme.inset
            border.width: 1
            border.color: keyInput.activeFocus ? Theme.accentBorder : Theme.hairline
            TextInput {
                id: keyInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: Settings.data.geoKey
                echoMode: TextInput.PasswordEchoOnEdit
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: 13
                clip: true
                onEditingFinished: if (text !== Settings.data.geoKey) { Settings.set("geoKey", text.trim()); Weather.refresh(); }
            }
        }
    }
}
