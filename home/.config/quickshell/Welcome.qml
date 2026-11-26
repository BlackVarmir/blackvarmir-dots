import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking

// Привітання при першому вході: мова, розкладка, Wi-Fi, шпалери, кілька клавіш.
// Показується один раз (Settings.data.welcomed); повторно: qs ipc call welcome show.
// Кожен крок можна пропустити кнопкою «Далі», Esc закриває і більше не показує.
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Panels.welcomeOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "varmir-welcome"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property int steps: 5
    readonly property var titles: [Tr.t("welcome.t0"), Tr.t("welcome.t1"), Tr.t("welcome.t2"), Tr.t("welcome.t3"), Tr.t("welcome.t4")]
    readonly property var hints: [Tr.t("welcome.d0"), Tr.t("welcome.d1"), Tr.t("welcome.d2"), Tr.t("welcome.d3"), Tr.t("welcome.d4")]
    property int step: 0
    readonly property string home: Quickshell.env("HOME") || ""

    function finish() {
        Settings.set("welcomed", true);
        Panels.welcomeOpen = false;
    }

    // Перший вхід: коли налаштування прочитано і привітання ще не бачили
    function check() {
        if (Settings.loaded && !Settings.data.welcomed) {
            win.step = 0;
            Panels.welcomeOpen = true;
        }
    }
    Component.onCompleted: check()
    Connections { target: Settings; function onLoadedChanged() { win.check(); } }

    IpcHandler {
        target: "welcome"
        function show(): void { win.step = 0; Panels.welcomeOpen = true; }
    }

    onVisibleChanged: if (visible) keys.forceActiveFocus()
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.finish()
        Keys.onReturnPressed: next.clicked()
    }

    // Затемнення поверх живого розмитого столу
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(8 / 255, 8 / 255, 10 / 255, 0.62)
    }

    // ───────────── Рядок вибору ─────────────
    component WRow: Rectangle {
        id: wr
        property string text: ""
        property string trail: ""
        property bool on: false
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 40
        radius: 10
        color: on ? Theme.accentSoft : Qt.rgba(1, 1, 1, wrArea.containsMouse ? 0.07 : 0.04)
        border.width: 1
        border.color: on ? Theme.emerald : Theme.hairline

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            text: wr.text
            color: "#e4e4e7"
            font.family: Theme.font
            font.pixelSize: 13
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12
            text: wr.trail
            color: Theme.textSubtle
            font.family: Theme.font
            font.pixelSize: 12
        }
        MouseArea {
            id: wrArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wr.clicked()
        }
    }

    component Kbd: Rectangle {
        property string text: ""
        implicitWidth: kt.implicitWidth + 12
        implicitHeight: 20
        radius: 5
        color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        border.color: Theme.hairline
        Text {
            id: kt
            anchors.centerIn: parent
            text: parent.text
            color: "#d4d4d8"
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    // ───────────── Картка ─────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 340
        height: 430
        radius: 18
        color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.78)
        border.width: 1
        border.color: Theme.hairlineStrong

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 26
            anchors.bottomMargin: 22
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: win.titles[win.step]
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 20
                font.weight: Font.DemiBold
                font.letterSpacing: -0.4
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: win.hints[win.step]
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: [cLang, cKeyboard, cWifi, cLook, cDone][win.step]
            }

            // Крапки кроків і кнопки
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: win.steps
                    Rectangle {
                        required property int index
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: index === win.step ? 22 : 6
                        implicitHeight: 6
                        radius: 3
                        color: index === win.step ? Theme.emerald : Qt.rgba(1, 1, 1, 0.2)
                        gradient: index === win.step ? dotGradient : null
                        Behavior on implicitWidth { NumberAnimation { duration: Theme.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                    }
                }
                Gradient {
                    id: dotGradient
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.emerald }
                    GradientStop { position: 1; color: Theme.cyan }
                }

                Item { Layout.fillWidth: true }

                VButton {
                    visible: win.step > 0
                    small: false
                    variant: "secondary"
                    text: Tr.t("welcome.back")
                    onClicked: win.step--
                }
                VButton {
                    id: next
                    small: false
                    text: win.step === win.steps - 1 ? Tr.t("welcome.start") : Tr.t("welcome.next")
                    onClicked: win.step < win.steps - 1 ? win.step++ : win.finish()
                }
            }
        }
    }

    // ───────────── Крок 1: мова ─────────────
    Component {
        id: cLang
        ColumnLayout {
            spacing: 8
            WRow { text: "English"; trail: "en"; on: Settings.shellLang === "en"; onClicked: Settings.set("shellLang", "en") }
            WRow { text: "Українська"; trail: "uk"; on: Settings.shellLang === "uk"; onClicked: Settings.set("shellLang", "uk") }
            WRow { text: Tr.t("welcome.sys"); trail: Tr.t("welcome.fromLang"); on: Settings.shellLang === "system"; onClicked: Settings.set("shellLang", "system") }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── Крок 2: розкладка ─────────────
    Component {
        id: cKeyboard
        ColumnLayout {
            spacing: 8
            readonly property var picked: Array.from(Settings.data.kbLayouts)
            Repeater {
                model: Layouts.catalog.slice(0, 5)
                WRow {
                    required property var modelData
                    text: modelData.label
                    trail: modelData.short
                    on: parent.picked.indexOf(modelData.value) !== -1
                    onClicked: {
                        const cur = parent.picked;
                        const i = cur.indexOf(modelData.value);
                        if (i === -1) Settings.set("kbLayouts", cur.concat([modelData.value]));
                        else if (cur.length > 1) Settings.set("kbLayouts", cur.filter(v => v !== modelData.value));
                    }
                }
            }
            RowLayout {
                spacing: 5
                Text { text: Tr.t("welcome.kbHint"); color: Theme.textMuted; font.family: Theme.font; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── Крок 3: Wi-Fi ─────────────
    readonly property var wifiDevice: {
        const list = Networking.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].type === DeviceType.Wifi) return list[i];
        return null;
    }
    readonly property var nets: {
        if (!wifiDevice) return [];
        return wifiDevice.networks.values.slice().sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        }).slice(0, 4);
    }
    property string wifiOpen: ""
    property string wifiError: ""

    Component {
        id: cWifi
        ColumnLayout {
            spacing: 8
            Component.onCompleted: if (win.wifiDevice) win.wifiDevice.scannerEnabled = true
            Component.onDestruction: if (win.wifiDevice) win.wifiDevice.scannerEnabled = false

            Repeater {
                model: win.nets
                ColumnLayout {
                    id: wnet
                    required property var modelData
                    readonly property bool open: modelData.security === WifiSecurityType.Open
                    Layout.fillWidth: true
                    spacing: 6

                    Connections {
                        target: wnet.modelData
                        function onConnectionFailed(reason) {
                            win.wifiOpen = wnet.modelData.name;
                            win.wifiError = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout
                                ? Tr.t("wifi.wrongPassword") : Tr.t("wifi.failed");
                        }
                    }

                    WRow {
                        text: wnet.modelData.name
                        trail: (wnet.modelData.connected ? Tr.t("wifi.connected") : wnet.open ? Tr.t("wifi.open") : "WPA2") + " · "
                            + ["▂", "▂▄", "▂▄▆", "▂▄▆█"][Math.min(3, Math.floor(wnet.modelData.signalStrength * 4))]
                        on: wnet.modelData.connected
                        onClicked: {
                            win.wifiError = "";
                            if (wnet.modelData.connected) return;
                            if (wnet.modelData.known || wnet.open) wnet.modelData.connect();
                            else win.wifiOpen = win.wifiOpen === wnet.modelData.name ? "" : wnet.modelData.name;
                        }
                    }

                    Rectangle {
                        visible: win.wifiOpen === wnet.modelData.name && !wnet.modelData.connected
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 8
                        color: Theme.inset
                        border.width: 1
                        border.color: win.wifiError !== "" ? Theme.error : (psk.activeFocus ? Theme.accentBorder : Theme.hairlineStrong)

                        TextInput {
                            id: psk
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 13
                            focus: parent.visible
                            Keys.onReturnPressed: event => { if (text.length >= 8) wnet.modelData.connectWithPsk(text); event.accepted = true; }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: psk.text.length === 0
                                text: win.wifiError !== "" ? win.wifiError : Tr.t("wifi.password")
                                color: win.wifiError !== "" ? Theme.error : Theme.textSubtle
                                font: psk.font
                            }
                        }
                    }
                }
            }
            Text {
                visible: win.nets.length === 0
                text: win.wifiDevice ? Tr.t("welcome.noNet") : Tr.t("wifi.noAdapter")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
            }
            Item { Layout.fillHeight: true }
        }
    }

    // ───────────── Крок 4: шпалери ─────────────
    FolderListModel {
        id: wallpapers
        folder: "file://" + win.home + "/.local/share/blackvarmir/wallpapers"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
    }

    Component {
        id: cLook
        GridLayout {
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: Math.min(4, wallpapers.count)
                WallpaperThumb {
                    required property int index
                    path: wallpapers.get(index, "filePath")
                    selected: (Settings.data.wallpaper || (win.home + "/.local/share/blackvarmir/wallpapers/varmir-aura.png")) === path
                    width: 134
                    height: 84
                    onPicked: Settings.set("wallpaper", path)
                }
            }
            Item { Layout.fillHeight: true; Layout.columnSpan: 2 }
        }
    }

    // ───────────── Крок 5: готово ─────────────
    Component {
        id: cDone
        ColumnLayout {
            spacing: 8
            Repeater {
                model: [
                    { keys: ["Super", "Space"], label: Tr.t("welcome.kSpot") },
                    { keys: ["Super", "Tab"], label: Tr.t("welcome.kOverview") },
                    { keys: ["Super", "L"], label: Tr.t("welcome.kLock") }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Theme.hairline
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        spacing: 4
                        Kbd { text: modelData.keys[0] }
                        Kbd { text: modelData.keys[1] }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        text: modelData.label
                        color: Theme.textSubtle
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
