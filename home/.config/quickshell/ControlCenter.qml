import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

// Центр керування: Super + N або клік по правому «острівцю» панелі.
// Головна сторінка: плитки, повзунки, плеєр, сповіщення.
// Підменю Wi-Fi, Bluetooth і Живлення відкриваються на місці головної сторінки.
PanelWindow {
    id: cc

    visible: Panels.controlOpen
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "varmir-control"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // main | wifi | bluetooth | power
    property string page: "main"
    Connections {
        target: Panels
        function onPowerRequestChanged() { if (Panels.powerRequest) cc.page = "power"; }
    }

    readonly property var wifiDevice: {
        const list = Networking.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].type === DeviceType.Wifi) return list[i];
        return null;
    }
    readonly property var wifiNetwork: {
        if (!wifiDevice) return null;
        const list = wifiDevice.networks.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].connected) return list[i];
        return null;
    }
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property var player: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying) return list[i];
        return list.length > 0 ? list[0] : null;
    }
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null

    function profileName(p) {
        return p === PowerProfile.PowerSaver ? Tr.t("power.saver")
            : p === PowerProfile.Performance ? Tr.t("power.performance") : Tr.t("power.balanced");
    }

    onVisibleChanged: {
        if (visible) {
            page = "main";
            NotifStore.hiddenCount = 0;
            Sys.refresh();
            Vpn.refresh();
            focusCatcher.forceActiveFocus();
        }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Клік повз панель закриває її
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.controlOpen = false
    }

    Item {
        id: focusCatcher
        focus: true
        Keys.onEscapePressed: {
            if (cc.page !== "main") cc.page = "main";
            else Panels.controlOpen = false;
        }
    }

    Rectangle {
        id: panel
        anchors.right: parent.right
        anchors.rightMargin: Theme.edge
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin + Theme.barHeight + 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.edge
        width: 430
        radius: Theme.radiusOverlay
        color: Theme.glassStrong
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        clip: true

        opacity: cc.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

        // Поглинає кліки всередині панелі
        MouseArea { anchors.fill: parent }

        // ───────────── Головна сторінка ─────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14
            visible: cc.page === "main"

            // Користувач і швидкі дії
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.emerald }
                        GradientStop { position: 1; color: Theme.cyan }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: String(Quickshell.env("USER") || "?").slice(0, 2).toUpperCase()
                        color: Theme.textOnAccent
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: Quickshell.env("USER") || ""
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: Tr.t("cc.uptime", Sys.uptimeText)
                        color: Theme.textSubtle
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                }

                IconButton {
                    glyph: ""
                    tip: Tr.t("cc.screenshot")
                    onClicked: Capture.open()
                }
                IconButton {
                    glyph: "\uf013"
                    tip: Tr.t("cc.settings")
                    onClicked: Panels.openSettings("")
                }
                IconButton {
                    glyph: ""
                    tip: Tr.t("power.lock")
                    onClicked: { Panels.closeAll(); Quickshell.execDetached(["loginctl", "lock-session"]); }
                }
                IconButton {
                    glyph: ""
                    tip: Tr.t("power.title")
                    onClicked: cc.page = "power"
                }
            }

            // Плитки
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                QuickTile {
                    Layout.fillWidth: true
                    glyph: ""
                    title: "Wi-Fi"
                    subtitle: !Networking.wifiEnabled ? Tr.t("common.off") : (cc.wifiNetwork?.name ?? Tr.t("wifi.notConnected"))
                    active: Networking.wifiEnabled
                    hasMenu: true
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    onMenuRequested: cc.page = "wifi"
                }
                QuickTile {
                    Layout.fillWidth: true
                    glyph: ""
                    title: "Bluetooth"
                    subtitle: !(cc.btAdapter?.enabled ?? false) ? Tr.t("common.off")
                        : cc.btConnected.length > 0 ? cc.btConnected.map(d => d.name).join(", ") : Tr.t("bt.noDevices")
                    active: cc.btAdapter?.enabled ?? false
                    hasMenu: true
                    onClicked: if (cc.btAdapter) cc.btAdapter.enabled = !cc.btAdapter.enabled
                    onMenuRequested: cc.page = "bluetooth"
                }
                QuickTile {
                    Layout.fillWidth: true
                    glyph: NotifStore.dnd ? "" : ""
                    title: Tr.t("cc.dnd")
                    subtitle: NotifStore.dnd ? Tr.t("common.on") : Tr.t("common.off")
                    active: NotifStore.dnd
                    onClicked: NotifStore.dnd = !NotifStore.dnd
                }
                QuickTile {
                    Layout.fillWidth: true
                    glyph: ""
                    title: Tr.t("cc.nightLight")
                    subtitle: Sys.nightLight ? "4000 K" : Tr.t("common.off")
                    active: Sys.nightLight
                    onClicked: Sys.nightLight = !Sys.nightLight
                }
                QuickTile {
                    Layout.fillWidth: true
                    glyph: ""
                    title: "VPN"
                    subtitle: Vpn.activeCount > 1 ? Tr.t("vpn.activeCount", Vpn.activeCount)
                        : Vpn.activeCount === 1 ? Vpn.activeList[0].name
                        : Vpn.tunnels.length === 0 ? Tr.t("cc.vpnNone") : Tr.t("common.off")
                    active: Vpn.activeCount > 0
                    hasMenu: true
                    // Один тунель — перемикається прямо з плитки, інакше відкривається список
                    onClicked: { if (!Vpn.toggleSingle()) cc.page = "vpn"; }
                    onMenuRequested: cc.page = "vpn"
                }
                QuickTile {
                    Layout.fillWidth: true
                    glyph: PowerProfiles.profile === PowerProfile.PowerSaver ? ""
                        : PowerProfiles.profile === PowerProfile.Performance ? "" : ""
                    title: Tr.t("power.title")
                    subtitle: cc.profileName(PowerProfiles.profile)
                    active: PowerProfiles.profile !== PowerProfile.Balanced
                    hasMenu: true
                    onClicked: cc.page = "power"
                    onMenuRequested: cc.page = "power"
                }
            }

            // Гучність і яскравість
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sliders.implicitHeight + 28
                radius: Theme.radiusTile
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Theme.hairline

                ColumnLayout {
                    id: sliders
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        spacing: 12
                        Text {
                            text: (cc.audio?.muted ?? false) ? "" : ""
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 15
                            Layout.preferredWidth: 18
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (cc.audio) cc.audio.muted = !cc.audio.muted
                            }
                        }
                        VSlider {
                            Layout.fillWidth: true
                            value: cc.audio?.volume ?? 0
                            onMoved: v => { if (cc.audio) cc.audio.volume = v; }
                        }
                        Text {
                            text: Math.round((cc.audio?.volume ?? 0) * 100) + "%"
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 12
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    RowLayout {
                        spacing: 12
                        Text {
                            text: ""
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 15
                            Layout.preferredWidth: 18
                        }
                        VSlider {
                            Layout.fillWidth: true
                            value: Sys.brightness
                            onMoved: v => Sys.setBrightness(Math.max(0.05, v))
                        }
                        Text {
                            text: Math.round(Sys.brightness * 100) + "%"
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 12
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // Плеєр (MPRIS: браузер, Spotify, mpv тощо)
            Rectangle {
                Layout.fillWidth: true
                visible: cc.player !== null
                implicitHeight: 88
                radius: Theme.radiusTile
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Theme.hairline

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    Rectangle {
                        width: 60
                        height: 60
                        radius: 12
                        color: Theme.canvas
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: cc.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Row {
                            anchors.centerIn: parent
                            spacing: 3
                            visible: !(cc.player?.trackArtUrl)
                            Repeater {
                                model: [26, 16, 8, 16, 26]
                                Rectangle {
                                    required property int modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 4
                                    height: modelData
                                    radius: 2
                                    color: Theme.emerald
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: cc.player?.trackTitle || Tr.t("cc.untitled")
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: (cc.player?.trackArtist || "") + (cc.player?.identity ? " · " + cc.player.identity : "")
                            color: Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }

                    IconButton { glyph: ""; tip: Tr.t("cc.prev"); onClicked: cc.player?.previous() }
                    IconButton {
                        glyph: (cc.player?.isPlaying ?? false) ? "" : ""
                        tip: Tr.t("cc.pause")
                        accent: true
                        onClicked: cc.player?.togglePlaying()
                    }
                    IconButton { glyph: ""; tip: Tr.t("cc.next"); onClicked: cc.player?.next() }
                }
            }

            // Сповіщення
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: Tr.t("cc.notifications", NotifStore.count)
                    color: Theme.emerald
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1.3
                }
                Text {
                    visible: NotifStore.count > 0
                    text: Tr.t("cc.clearAll")
                    color: clearArea.containsMouse ? Theme.text : Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 13
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotifStore.clearAll()
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotifStore.count > 0
                clip: true
                spacing: 10
                model: NotifStore.list.slice().reverse()
                delegate: NotificationCard {
                    required property var modelData
                    notification: modelData
                    compact: true
                    width: ListView.view.width
                    onCloseRequested: NotifStore.dismiss(modelData)
                }
            }

            // Порожній стан
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotifStore.count === 0
                radius: Theme.radiusTile
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 10
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: NotifStore.dnd ? "" : ""
                        color: Theme.textSubtle
                        font.family: Theme.mono
                        font.pixelSize: 26
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Tr.t("cc.noNotifications")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        visible: NotifStore.dnd
                        text: Tr.t("cc.dndHint")
                        color: Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }
        }

        // ───────────── Підменю ─────────────
        Loader {
            anchors.fill: parent
            anchors.margins: 18
            active: cc.page === "wifi"
            sourceComponent: CcWifi {
                device: cc.wifiDevice
                onBack: cc.page = "main"
            }
        }
        Loader {
            anchors.fill: parent
            anchors.margins: 18
            active: cc.page === "bluetooth"
            sourceComponent: CcBluetooth {
                adapter: cc.btAdapter
                onBack: cc.page = "main"
            }
        }
        Loader {
            anchors.fill: parent
            anchors.margins: 18
            active: cc.page === "vpn"
            sourceComponent: CcVpn {
                onBack: cc.page = "main"
            }
        }
        Loader {
            anchors.fill: parent
            anchors.margins: 18
            active: cc.page === "power"
            sourceComponent: CcPower {
                onBack: cc.page = "main"
            }
        }
    }
}
