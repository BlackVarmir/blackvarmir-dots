import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Календар і погода: клік по годиннику на панелі. Esc або клік повз — закрити.
PanelWindow {
    id: pop

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Panels.calendarOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "varmir-calendar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Регіон форматів (перший день тижня, назви)
    readonly property var region: Qt.locale((Quickshell.env("LC_TIME") || Quickshell.env("LANG") || "uk_UA").split(".")[0])
    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()

    onVisibleChanged: if (visible) { today = new Date(); year = today.getFullYear(); month = today.getMonth(); keys.forceActiveFocus(); }

    function shift(d) {
        let m = month + d, y = year;
        if (m < 0) { m = 11; y -= 1; }
        if (m > 11) { m = 0; y += 1; }
        month = m;
        year = y;
    }

    // 42 клітинки: тиждень починається з дня з регіону (Qt: 1 = понеділок … 7 = неділя, 0 = неділя)
    readonly property var cells: {
        const first = new Date(year, month, 1);
        const fdow = region.firstDayOfWeek % 7;          // 0 = неділя
        const offset = (first.getDay() - fdow + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - offset + i);
            out.push({
                day: d.getDate(),
                other: d.getMonth() !== month,
                weekend: region.weekDays.indexOf(d.getDay() === 0 ? 7 : d.getDay()) === -1,
                today: d.toDateString() === today.toDateString()
            });
        }
        return out;
    }
    readonly property var weekdayNames: {
        const out = [];
        const fdow = region.firstDayOfWeek % 7;
        for (let i = 0; i < 7; i++) out.push(region.dayName((fdow + i) % 7, Locale.ShortFormat));
        return out;
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Panels.calendarOpen = false
        Keys.onLeftPressed: pop.shift(-1)
        Keys.onRightPressed: pop.shift(1)
    }

    MouseArea { anchors.fill: parent; onClicked: Panels.calendarOpen = false }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barMargin + Theme.barHeight + 8
        width: 660
        height: Math.max(calCol.implicitHeight, wxCol.implicitHeight) + 40
        radius: Theme.radiusOverlay
        color: Theme.glassStrong
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        opacity: pop.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.base } }

        MouseArea {
            anchors.fill: parent
            onWheel: wheel => pop.shift(wheel.angleDelta.y > 0 ? -1 : 1)
        }

        // Календар
        Column {
            id: calCol
            x: 20
            y: 20
            width: 290
            spacing: 12

            Item {
                width: parent.width
                height: 24
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const s = new Date(pop.year, pop.month, 1).toLocaleDateString(Tr.locale, "LLLL yyyy");
                        return s.charAt(0).toUpperCase() + s.slice(1);
                    }
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { pop.year = pop.today.getFullYear(); pop.month = pop.today.getMonth(); }
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    IconButton { glyph: ""; tip: ""; onClicked: pop.shift(-1) }
                    IconButton { glyph: ""; tip: ""; onClicked: pop.shift(1) }
                }
            }

            Grid {
                columns: 7
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: pop.weekdayNames
                    Text {
                        required property string modelData
                        width: 38
                        height: 22
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: Theme.textSubtle
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
                Repeater {
                    model: pop.cells
                    Rectangle {
                        required property var modelData
                        width: 38
                        height: 32
                        radius: 8
                        color: "transparent"
                        gradient: modelData.today ? todayGrad : null
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.day
                            color: parent.modelData.today ? Theme.textOnAccent
                                : parent.modelData.other ? "#3f3f46"
                                : parent.modelData.weekend ? Theme.textMuted : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: parent.modelData.today ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
        }

        Gradient {
            id: todayGrad
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.emerald }
            GradientStop { position: 1; color: Theme.cyan }
        }

        Rectangle { x: 330; y: 0; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.08) }

        // Погода
        Column {
            id: wxCol
            x: 350
            y: 20
            width: parent.width - 370
            spacing: 14

            Text {
                visible: !Weather.ready
                width: parent.width
                wrapMode: Text.Wrap
                text: Tr.t("wx.loading")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
            }

            Row {
                visible: Weather.ready
                spacing: 14
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.glyph(Weather.current?.code ?? 3, Weather.current?.isDay)
                    color: Weather.stale ? Theme.textSubtle : Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 38
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: Weather.deg(Weather.current?.temp ?? 0)
                        color: Weather.stale ? Theme.textSubtle : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: Weather.describe(Weather.current?.code ?? 3) + " · " + Tr.t("wx.feels", Weather.deg(Weather.current?.feels ?? 0))
                        color: Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }

            Text {
                visible: Weather.ready
                width: parent.width
                elide: Text.ElideRight
                text: [
                    (Weather.place || "—") + (Weather.approximate ? " (" + Tr.t("wx.approx") + ")" : ""),
                    Tr.t(Weather.imperial ? "wx.windMph" : "wx.windMs", Math.round(Weather.current?.wind ?? 0)),
                    Tr.t("wx.humidity", Weather.current?.humidity ?? 0)
                ].join(" · ")
                color: Theme.textSubtle
                font.family: Theme.font
                font.pixelSize: 12
            }

            Row {
                visible: Weather.ready
                spacing: 6
                Repeater {
                    model: Weather.hourly
                    Rectangle {
                        required property var modelData
                        width: 52
                        height: 64
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.04)
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.hour; color: Theme.textSubtle; font.family: Theme.font; font.pixelSize: 11 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.glyph(modelData.code, modelData.hour >= 7 && modelData.hour < 19); color: Theme.textMuted; font.family: Theme.mono; font.pixelSize: 14 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.deg(modelData.temp); color: Theme.text; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }
                }
            }

            Column {
                visible: Weather.ready
                width: parent.width
                spacing: 6
                Repeater {
                    model: Weather.daily
                    Item {
                        required property var modelData
                        width: parent.width
                        height: 20
                        Text {
                            text: {
                                const s = new Date(modelData.date + "T12:00:00").toLocaleDateString(Tr.locale, "ddd");
                                return s.charAt(0).toUpperCase() + s.slice(1);
                            }
                            color: Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                        Text {
                            x: 50
                            text: Weather.glyph(modelData.code, true) + "  " + Weather.describe(modelData.code)
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 13
                        }
                        Text {
                            anchors.right: parent.right
                            text: Weather.deg(modelData.max) + " / " + Weather.deg(modelData.min)
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
