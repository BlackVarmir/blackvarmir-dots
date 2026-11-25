import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

// Підменю Живлення: профіль, заряд, дії з сеансом.
// Вимкнення і перезавантаження чекають 10 с — можна передумати.
ColumnLayout {
    id: page

    signal back()
    spacing: 10

    // "" | "poweroff" | "reboot"
    property string pending: ""
    property int secondsLeft: 10

    readonly property var battery: UPower.displayDevice

    function run(action) {
        if (action === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"]);
        else if (action === "reboot") Quickshell.execDetached(["systemctl", "reboot"]);
    }

    Component.onCompleted: if (Panels.powerRequest) { start(Panels.powerRequest); Panels.powerRequest = ""; }

    function start(action) {
        pending = action;
        secondsLeft = 10;
        countdown.restart();
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            page.secondsLeft -= 1;
            if (page.secondsLeft <= 0) {
                stop();
                page.run(page.pending);
            }
        }
    }

    PageHeader {
        Layout.fillWidth: true
        title: Tr.t("power.title")
        onBack: page.back()
        Text {
            visible: page.battery?.isLaptopBattery ?? false
            text: {
                const b = page.battery;
                if (!b) return "";
                let s = Math.round(b.percentage * 100) + "%";
                const secs = b.timeToEmpty > 0 ? b.timeToEmpty : 0;
                if (secs > 0) s += " · ≈ " + Tr.t("time.hm", Math.floor(secs / 3600), Math.floor(secs % 3600 / 60));
                return s;
            }
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: 13
        }
    }

    Eyebrow { text: Tr.t("power.profile") }

    GridLayout {
        Layout.fillWidth: true
        columns: PowerProfiles.hasPerformanceProfile ? 3 : 2
        columnSpacing: 8

        Repeater {
            model: [
                { profile: PowerProfile.PowerSaver, label: Tr.t("power.saver"), glyph: "" },
                { profile: PowerProfile.Balanced, label: Tr.t("power.balanced"), glyph: "" },
                { profile: PowerProfile.Performance, label: Tr.t("power.performance"), glyph: "" }
            ].filter(p => p.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

            Rectangle {
                id: opt
                required property var modelData
                readonly property bool selected: PowerProfiles.profile === modelData.profile

                Layout.fillWidth: true
                implicitHeight: 84
                radius: Theme.radiusTile
                color: selected ? Theme.accentSoft : (optArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                border.width: 1
                border.color: selected ? Theme.accentBorder : Theme.hairline

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: opt.modelData.glyph
                        color: opt.selected ? Theme.emeraldLight : Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: 17
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: opt.modelData.label
                        color: opt.selected ? Theme.emeraldLight : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: opt.selected ? Font.DemiBold : Font.Medium
                    }
                }

                MouseArea {
                    id: optArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PowerProfiles.profile = opt.modelData.profile
                }
            }
        }
    }

    Eyebrow { text: Tr.t("power.session") }

    Repeater {
        model: [
            { id: "lock", label: Tr.t("power.lock"), glyph: "", hint: "Super + L" },
            { id: "sleep", label: Tr.t("power.sleep"), glyph: "", hint: "" },
            { id: "logout", label: Tr.t("power.logout"), glyph: "", hint: "" },
            { id: "reboot", label: Tr.t("power.reboot"), glyph: "", hint: "" },
            { id: "poweroff", label: Tr.t("power.poweroff"), glyph: "", hint: "" }
        ]

        Rectangle {
            id: action
            required property var modelData
            readonly property bool isPending: page.pending === modelData.id

            Layout.fillWidth: true
            implicitHeight: isPending ? 120 : 46
            radius: 12
            color: isPending ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.1) : (actArea.containsMouse ? Theme.hover : "transparent")
            border.width: isPending ? 1 : 0
            border.color: Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.35)

            Behavior on implicitHeight { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

            MouseArea {
                id: actArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !action.isPending
                onClicked: {
                    const id = action.modelData.id;
                    if (id === "lock") { Panels.closeAll(); Quickshell.execDetached(["loginctl", "lock-session"]); }
                    else if (id === "sleep") { Panels.closeAll(); Quickshell.execDetached(["systemctl", "suspend"]); }
                    else if (id === "logout") Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]);
                    else page.start(id);
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    spacing: 12
                    Text {
                        text: action.modelData.glyph
                        color: action.isPending ? Theme.error : Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: 15
                        Layout.preferredWidth: 18
                    }
                    Text {
                        Layout.fillWidth: true
                        text: action.modelData.label
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: action.isPending ? Font.DemiBold : Font.Normal
                    }
                    Text {
                        text: action.isPending ? Tr.t("power.inSeconds", page.secondsLeft) : action.modelData.hint
                        color: action.isPending ? Theme.error : Theme.textSubtle
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    visible: action.isPending
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.1)
                    Rectangle {
                        width: parent.width * (10 - page.secondsLeft) / 10
                        height: parent.height
                        radius: 2
                        color: Theme.error
                        Behavior on width { NumberAnimation { duration: 1000 } }
                    }
                }

                RowLayout {
                    visible: action.isPending
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    VButton { text: Tr.t("common.cancel"); variant: "ghost"; onClicked: { countdown.stop(); page.pending = ""; } }
                    VButton {
                        text: action.modelData.id === "reboot" ? Tr.t("power.rebootNow") : Tr.t("power.poweroffNow")
                        variant: "danger"
                        onClicked: { countdown.stop(); page.run(page.pending); }
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: Tr.t("power.hint")
        color: Theme.textSubtle
        font.family: Theme.font
        font.pixelSize: 12
    }
}
