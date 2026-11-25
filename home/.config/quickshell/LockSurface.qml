import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// Вміст екрана блокування на одному моніторі. Макет — як у дизайні етапу 1,
// стани (перевірка, помилка, Caps Lock, сповіщення) — з етапу 5.
Item {
    id: surface

    required property var lock

    readonly property string wallpaper: Settings.data.wallpaper
        || (Quickshell.env("HOME") + "/.local/share/blackvarmir/wallpapers/varmir-aura.png")
    readonly property var player: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying) return list[i];
        return list.length > 0 ? list[0] : null;
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // Тло: розмиті шпалери, затемнення і фірмове сяйво
    Image {
        id: wall
        anchors.fill: parent
        source: "file://" + surface.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blurMax: 64
        blur: 1
        brightness: -0.25
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(7 / 255, 7 / 255, 8 / 255, 0.35) }
            GradientStop { position: 1; color: Qt.rgba(7 / 255, 7 / 255, 8 / 255, 0.7) }
        }
    }

    // Плавна поява
    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

        // Дата і час
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.14
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.date.toLocaleDateString(Tr.locale, "dddd · d MMMM").toUpperCase()
                color: Theme.emerald
                font.family: Theme.mono
                font.pixelSize: 13
                font.letterSpacing: 1.6
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, Settings.clock24 ? "HH:mm" : "h:mm")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Math.min(200, surface.height * 0.18)
                font.weight: Font.DemiBold
                font.letterSpacing: -8
            }
        }

        // Користувач і пароль
        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.55
            spacing: 16

            Avatar {
                Layout.alignment: Qt.AlignHCenter
                size: 84
                opacity: surface.lock.checking ? 0.6 : 1
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Sys.realName || Quickshell.env("USER") || ""
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: field
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 340
                implicitHeight: 48
                radius: 24
                color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.6)
                border.width: 1
                border.color: surface.lock.error && input.text.length === 0 ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.6)
                    : input.activeFocus ? Theme.accentBorder : Qt.rgba(1, 1, 1, 0.12)

                property real shake: 0
                transform: Translate { x: field.shake }
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: field; property: "shake"; to: -10; duration: 50 }
                    NumberAnimation { target: field; property: "shake"; to: 10; duration: 50 }
                    NumberAnimation { target: field; property: "shake"; to: -7; duration: 50 }
                    NumberAnimation { target: field; property: "shake"; to: 7; duration: 50 }
                    NumberAnimation { target: field; property: "shake"; to: -3; duration: 50 }
                    NumberAnimation { target: field; property: "shake"; to: 0; duration: 50 }
                }
                Connections {
                    target: surface.lock
                    function onFailed() { shakeAnim.restart(); input.forceActiveFocus(); }
                }

                TextInput {
                    id: input
                    visible: !surface.lock.checking
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 52
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 18
                    font.letterSpacing: 3
                    focus: true
                    enabled: !surface.lock.checking
                    text: surface.lock.password
                    onTextEdited: surface.lock.password = text
                    onAccepted: surface.lock.submit()
                    Keys.onPressed: surface.lock.checkCaps()
                    Keys.onEscapePressed: surface.lock.password = ""
                    Component.onCompleted: forceActiveFocus()

                    Text {
                        visible: input.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tr.t("lock.password")
                        color: Theme.textSubtle
                        font.family: Theme.font
                        font.pixelSize: 15
                    }
                }

                Row {
                    visible: surface.lock.checking
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        text: ""
                        color: Theme.emerald
                        font.family: Theme.mono
                        font.pixelSize: 15
                        RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: surface.lock.checking }
                    }
                    Text {
                        text: Tr.t("lock.checking")
                        color: Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    visible: !surface.lock.checking
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.emerald }
                        GradientStop { position: 1; color: Theme.cyan }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: Theme.textOnAccent
                        font.family: Theme.mono
                        font.pixelSize: 14
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: surface.lock.submit()
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 420
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: surface.lock.error || Tr.t("lock.hint")
                color: surface.lock.error ? "#f87171" : Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                LockChip {
                    visible: surface.lock.capsLock
                    glyph: ""
                    text: "Caps Lock"
                    warn: true
                }
                LockChip {
                    visible: NotifStore.count > 0
                    glyph: ""
                    text: Tr.plural(NotifStore.count, "plural.notifications")
                }
            }
        }

        // Плеєр
        Rectangle {
            visible: surface.player !== null
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 36
            implicitWidth: playerRow.implicitWidth + 28
            implicitHeight: 72
            radius: 16
            color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.55)
            border.width: 1
            border.color: Theme.hairline

            RowLayout {
                id: playerRow
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                spacing: 14
                ClippingRectangle {
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: 10
                    color: Theme.canvas
                    Image {
                        anchors.fill: parent
                        source: surface.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Column {
                    Layout.maximumWidth: 260
                    Text {
                        width: Math.min(implicitWidth, 260)
                        elide: Text.ElideRight
                        text: surface.player?.trackTitle || Tr.t("cc.untitled")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: Math.min(implicitWidth, 260)
                        elide: Text.ElideRight
                        text: surface.player?.trackArtist ?? ""
                        color: Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
                IconButton {
                    glyph: surface.player?.isPlaying ? "" : ""
                    tip: Tr.t("cc.pause")
                    onClicked: surface.player?.togglePlaying()
                }
            }
        }

        // Розкладка і батарея
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 44
            spacing: 18

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: kb.implicitWidth + 14
                height: 22
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.06)
                Text {
                    id: kb
                    anchors.centerIn: parent
                    text: Layouts.find(Layouts.current).short
                    color: Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }
            Text {
                visible: UPower.displayDevice?.isLaptopBattery ?? false
                anchors.verticalCenter: parent.verticalCenter
                text: "  " + Math.round((UPower.displayDevice?.percentage ?? 0) * 100) + "%"
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: 13
            }
        }
    }
}
