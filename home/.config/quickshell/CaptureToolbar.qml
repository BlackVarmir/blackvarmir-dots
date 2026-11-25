import QtQuick

// Панель інструментів знімка: режим, знімок / запис, таймер, звук, кнопка «Зняти».
Rectangle {
    id: bar

    property bool canCapture: false
    signal captureRequested()

    width: row.implicitWidth + 16
    height: 52
    radius: 16
    color: Theme.glassStrong
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.1)

    // Кліки по панелі не мають малювати область під нею
    MouseArea { anchors.fill: parent }

    component Seg: Rectangle {
        id: seg
        property var options: []
        property string current: ""
        signal picked(string value)
        width: segRow.implicitWidth + 6
        height: 38
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.05)
        Row {
            id: segRow
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: seg.options
                Rectangle {
                    required property var modelData
                    readonly property bool on: modelData.value === seg.current
                    width: segLabel.implicitWidth + 24
                    height: 32
                    radius: 9
                    color: on ? Qt.rgba(1, 1, 1, 0.1) : segArea.containsMouse ? Theme.hover : "transparent"
                    Text {
                        id: segLabel
                        anchors.centerIn: parent
                        text: modelData.glyph + "  " + modelData.label
                        color: parent.on ? Theme.text : Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: segArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.picked(parent.modelData.value)
                    }
                }
            }
        }
    }

    component Pill: Rectangle {
        id: pill
        property string text: ""
        signal clicked()
        width: pillText.implicitWidth + 24
        height: 34
        radius: 10
        color: pillArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.text
            color: Theme.textMuted
            font.family: Theme.font
            font.pixelSize: 12
        }
        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Seg {
            anchors.verticalCenter: parent.verticalCenter
            options: [
                { value: "region", glyph: "", label: Tr.t("cap.region") },
                { value: "window", glyph: "", label: Tr.t("cap.window") },
                { value: "screen", glyph: "", label: Tr.t("cap.screen") }
            ]
            current: Capture.mode
            onPicked: v => Capture.mode = v
        }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 28; color: Qt.rgba(1, 1, 1, 0.1) }
        Seg {
            anchors.verticalCenter: parent.verticalCenter
            options: [
                { value: "shot", glyph: "", label: Tr.t("cap.shot") },
                { value: "record", glyph: "", label: Tr.t("cap.record") }
            ]
            current: Capture.action
            onPicked: v => Capture.action = v
        }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 28; color: Qt.rgba(1, 1, 1, 0.1) }
        Pill {
            anchors.verticalCenter: parent.verticalCenter
            text: "  " + (Capture.delay === 0 ? Tr.t("cap.noTimer") : Tr.t("cap.timer", Capture.delay))
            onClicked: Capture.delay = Capture.delay === 0 ? 3 : Capture.delay === 3 ? 10 : 0
        }
        Pill {
            visible: Capture.action === "record"
            anchors.verticalCenter: parent.verticalCenter
            text: (Capture.audio === "none" ? "  " : "  ")
                + (Capture.audio === "mic" ? Tr.t("cap.audioMic") : Capture.audio === "system" ? Tr.t("cap.audioSystem") : Tr.t("cap.audioNone"))
            onClicked: Settings.set("recordAudio", Capture.audio === "none" ? "system" : Capture.audio === "system" ? "mic" : "none")
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: goLabel.implicitWidth + 32
            height: 38
            radius: 10
            opacity: bar.canCapture ? 1 : 0.45
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.emerald }
                GradientStop { position: 1; color: Theme.cyan }
            }
            Text {
                id: goLabel
                anchors.centerIn: parent
                text: (Capture.action === "record" ? Tr.t("cap.startRecord") : Tr.t("cap.take")) + "  ⏎"
                color: Theme.textOnAccent
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            MouseArea {
                anchors.fill: parent
                enabled: bar.canCapture
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.captureRequested()
            }
        }
    }
}
