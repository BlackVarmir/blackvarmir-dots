import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Верхня панель: три скляні «острівці».
// Ліво: логотип (відкриває Spotlight) · робочі столи · активне вікно.
// Центр: годинник і дата. Право: розкладка · гучність · батарея.
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

        // Робочі столи 1–6: активний — витягнута градієнтна пігулка,
        // зайнятий — яскрава крапка, порожній — тьмяна.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Repeater {
                model: 6

                Rectangle {
                    id: dot
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var ws: {
                        const list = Hyprland.workspaces.values;
                        for (let i = 0; i < list.length; i++)
                            if (list[i].id === wsId) return list[i];
                        return null;
                    }
                    readonly property bool active: bar.monitor?.activeWorkspace?.id === wsId
                    readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0

                    anchors.verticalCenter: parent.verticalCenter
                    width: active ? 26 : (occupied ? 8 : 6)
                    height: active || occupied ? 8 : 6
                    radius: height / 2
                    color: active ? Theme.emerald : (occupied ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.2))
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
                        onClicked: {
                            if (dot.ws) dot.ws.activate();
                            else Hyprland.dispatch(`hl.dsp.focus({ workspace = ${dot.wsId} })`);
                        }
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

    // ───────────── Центр ─────────────
    Island {
        anchors.centerIn: parent
        padding: 18
        spacing: 10

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
