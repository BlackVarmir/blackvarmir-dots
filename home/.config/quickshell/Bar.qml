import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Верхня панель: три скляні «острівці».
// Ліво: логотип (відкриває Spotlight) · робочі столи · активне вікно.
// Центр: годинник і дата. Право: оновлення · розкладка · гучність · батарея.
// Усе оновлюється подіями (Hyprland IPC, PipeWire, UPower), без опитування.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.barMargin
        left: Theme.edge
        right: Theme.edge
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    WlrLayershell.namespace: "varmir-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Стан, що потрібен кільком острівцям
    readonly property var monitor: Hyprland.monitorFor(bar.screen)
    readonly property string kbLayout: Layouts.find(Layouts.current).short

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // ───────────── Ліво ─────────────
    Island {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        padding: 8
        spacing: 14

        // Логотип-хвиля: кнопка Spotlight
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 28
            radius: Theme.radiusChip
            color: logoArea.containsMouse ? Theme.accentBorder : Theme.accentSoft

            Behavior on color { ColorAnimation { duration: Theme.fast } }

            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: [16, 11, 6, 11, 16]
                    Rectangle {
                        required property int modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: modelData
                        radius: 1.5
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.emerald }
                            GradientStop { position: 1; color: Theme.cyan }
                        }
                    }
                }
            }

            MouseArea {
                id: logoArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggleSpotlight()
            }
        }

        // Робочі столи (динамічні): активний — витягнута градієнтна пігулка,
        // зайнятий — яскрава крапка, порожній — тьмяна.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Repeater {
                model: Workspaces.ids

                Rectangle {
                    id: dot
                    required property int modelData
                    readonly property int wsId: modelData
                    readonly property var ws: Workspaces.find(wsId)
                    readonly property bool active: bar.monitor?.activeWorkspace?.id === wsId
                    readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0
                    // Порожній стіл наприкінці: пунктирна крапка «новий»
                    readonly property bool fresh: Workspaces.trailing === wsId && !active

                    anchors.verticalCenter: parent.verticalCenter
                    width: active ? 26 : (occupied ? 8 : 6)
                    height: active || occupied ? 8 : 6
                    radius: height / 2
                    color: fresh ? "transparent" : (active ? Theme.emerald : (occupied ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.2)))
                    border.width: fresh ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.35)
                    gradient: active ? activeGradient : null

                    Gradient {
                        id: activeGradient
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.emerald }
                        GradientStop { position: 1; color: Theme.cyan }
                    }

                    Behavior on width {
                        NumberAnimation { duration: Theme.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        // activate() сам підбирає синтаксис (Lua чи старий hyprlang)
                        onClicked: Workspaces.go(dot.wsId)
                    }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 18
            color: Qt.rgba(1, 1, 1, 0.1)
            visible: windowTitle.text.length > 0
        }

        Text {
            id: windowTitle
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 360)
            elide: Text.ElideRight
            text: Hyprland.activeToplevel?.title ?? ""
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: 13
        }
    }

    // ───────────── Центр (клік відкриває календар і погоду) ─────────────
    // Під час запису екрана ліворуч від годинника — острівець з часом запису
    Island {
        visible: Capture.recording
        anchors.right: clockIsland.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        padding: 14
        spacing: 10
        clickable: true
        onClicked: Capture.stop()

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 9
            height: 9
            radius: 5
            color: Theme.error
            SequentialAnimation on opacity {
                running: Capture.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const sec = Math.floor((recClock.date.getTime() - Capture.recordStart) / 1000);
                return String(Math.floor(sec / 60)).padStart(2, "0") + ":" + String(Math.max(0, sec) % 60).padStart(2, "0");
            }
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: 13
            SystemClock { id: recClock; precision: SystemClock.Seconds; enabled: Capture.recording }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    Island {
        id: clockIsland
        anchors.centerIn: parent
        padding: 18
        spacing: 10
        clickable: true
        highlighted: Panels.calendarOpen
        onClicked: Panels.toggleCalendar()

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, Settings.clock24 ? "HH:mm" : "h:mm AP")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: clock.date.toLocaleDateString(Tr.locale, "ddd, d MMMM")
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: 13
        }

        Text {
            visible: Settings.data.weatherInBar && Weather.ready
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.glyph(Weather.current?.code ?? 3, Weather.current?.isDay) + " " + Weather.deg(Weather.current?.temp ?? 0)
            color: Weather.stale ? Theme.textSubtle : Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: 13
        }
    }

    // ───────────── Право (клік відкриває центр керування) ─────────────
    Island {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        padding: 12
        spacing: 14
        clickable: true
        highlighted: Panels.controlOpen
        onClicked: Panels.toggleControl()

        // Оновлення: лише коли вони є; клік — список (не центр керування)
        Rectangle {
            visible: Updates.count > 0
            anchors.verticalCenter: parent.verticalCenter
            width: updRow.implicitWidth + 14
            height: 22
            radius: 7
            color: Panels.updatesOpen || updArea.containsMouse ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.26) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.16)
            Row {
                id: updRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Updates.news.length > 0 ? "\uf071" : "\uf019"
                    color: Updates.news.length > 0 ? Theme.warning : Theme.emeraldLight
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Updates.count
                    color: Theme.emeraldLight
                    font.family: Theme.mono
                    font.pixelSize: 12
                }
            }
            MouseArea {
                id: updArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggleUpdates()
            }
        }

        // Розкладка
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: layoutText.implicitWidth + 14
            height: 20
            radius: 6
            color: Theme.hover

            Text {
                id: layoutText
                anchors.centerIn: parent
                text: bar.kbLayout
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: 11
                font.letterSpacing: 1
            }
        }

        // Гучність (колесо миші змінює, клік вимикає звук)
        Item {
            id: volume
            readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: volumeRow.implicitWidth
            implicitHeight: volumeRow.implicitHeight
            visible: audio !== null

            Row {
                id: volumeRow
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (volume.audio?.muted ?? false) ? "" : ""
                    color: Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: 15
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round((volume.audio?.volume ?? 0) * 100) + "%"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggleControl()
                onWheel: wheel => {
                    if (!volume.audio) return;
                    const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    volume.audio.volume = Math.max(0, Math.min(1, volume.audio.volume + step));
                }
            }
        }

        // Батарея (лише на ноутбуці)
        Row {
            id: battery
            readonly property var dev: UPower.displayDevice
            readonly property real level: dev?.percentage ?? 0
            readonly property bool charging: dev?.state === UPowerDeviceState.Charging
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: dev?.isLaptopBattery ?? false

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: battery.charging ? ""
                    : battery.level > 0.85 ? ""
                    : battery.level > 0.6 ? ""
                    : battery.level > 0.35 ? ""
                    : battery.level > 0.15 ? "" : ""
                color: battery.level <= 0.15 && !battery.charging ? Theme.error : Theme.emerald
                font.family: Theme.mono
                font.pixelSize: 14
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(battery.level * 100) + "%"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
            }
        }

        // Сповіщення: крапка, якщо є непрочитані; перекреслений дзвінок у режимі «Не турбувати»
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16

            Text {
                anchors.centerIn: parent
                text: NotifStore.dnd ? "\uf1f6" : "\uf0f3"
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: 14
            }
            Rectangle {
                visible: NotifStore.count > 0 && !NotifStore.dnd
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: -2
                width: 6
                height: 6
                radius: 3
                color: Theme.emerald
            }
        }
    }
}
