import QtQuick
import Quickshell
import Quickshell.Widgets

// Док в огляді столів: закріплені застосунки + запущені незакріплені (пунктирна рамка).
// Крапка під значком — по одній на кожне вікно (до 3), смарагдова — активне вікно.
// Клік: запущений — перейти до вікна (повторний клік перебирає вікна), не запущений — відкрити.
Rectangle {
    id: dock

    required property var windows
    signal launched()
    signal focusRequested(var toplevel)

    // Скільки разів клікнули по застосунку — для перебору його вікон
    property var cycle: ({})

    function entryFor(t) {
        return DesktopEntries.heuristicLookup(t.lastIpcObject?.class ?? "");
    }

    readonly property var items: {
        const result = [];
        const seen = {};
        for (let i = 0; i < Theme.pinnedApps.length; i++) {
            const e = DesktopEntries.byId(Theme.pinnedApps[i]);
            if (e && !seen[e.id]) { seen[e.id] = true; result.push({ entry: e, pinned: true }); }
        }
        for (let i = 0; i < windows.length; i++) {
            const e = entryFor(windows[i]);
            if (e && !seen[e.id]) { seen[e.id] = true; result.push({ entry: e, pinned: false }); }
        }
        return result;
    }

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 76
    radius: 22
    color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.75)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.1)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: dock.items

            Item {
                id: app
                required property var modelData
                required property int index

                readonly property var entry: modelData.entry
                readonly property var wins: dock.windows.filter(t => dock.entryFor(t)?.id === entry.id)
                readonly property bool hasActive: wins.some(t => t.activated)
                readonly property bool hovered: area.containsMouse
                // Роздільник перед першим незакріпленим
                readonly property bool firstUnpinned: !modelData.pinned && index > 0 && dock.items[index - 1].pinned

                width: tile.width + (firstUnpinned ? 17 : 0)
                height: 64

                Rectangle {
                    visible: app.firstUnpinned
                    x: 0
                    anchors.verticalCenter: tile.verticalCenter
                    width: 1
                    height: 36
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                Rectangle {
                    id: tile
                    x: app.firstUnpinned ? 17 : 0
                    y: app.hovered ? 0 : 6
                    width: 52
                    height: 52
                    radius: 14
                    color: app.hasActive ? Theme.accentSoft : (app.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))
                    border.width: 1
                    border.color: app.hasActive ? Theme.accentBorder : (app.hovered ? Qt.rgba(1, 1, 1, 0.28) : Theme.hairline)

                    Behavior on y { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

                    // Пунктир для незакріплених: чотири штрихи по кутах замість суцільної рамки
                    Rectangle {
                        anchors.fill: parent
                        visible: !app.modelData.pinned
                        radius: 14
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                        opacity: 0.6
                    }

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 30
                        source: Quickshell.iconPath(app.entry.icon, "application-x-executable")
                        asynchronous: true
                    }
                }

                // Крапки вікон
                Row {
                    anchors.horizontalCenter: tile.horizontalCenter
                    anchors.top: tile.bottom
                    anchors.topMargin: 4
                    spacing: 3
                    Repeater {
                        model: Math.min(3, app.wins.length)
                        Rectangle {
                            required property int index
                            width: 4
                            height: 4
                            radius: 2
                            color: app.hasActive && index === 0 ? Theme.emerald : Theme.textMuted
                        }
                    }
                }

                // Підказка
                Rectangle {
                    visible: app.hovered
                    anchors.horizontalCenter: tile.horizontalCenter
                    anchors.bottom: tile.top
                    anchors.bottomMargin: 10
                    width: tipText.implicitWidth + 20
                    height: 26
                    radius: 8
                    color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.95)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        text: app.entry.name + (app.wins.length > 0
                            ? " · " + app.wins.length + (app.wins.length === 1 ? " вікно" : app.wins.length < 5 ? " вікна" : " вікон") : "")
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: tile
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (app.wins.length === 0) {
                            app.entry.execute();
                            dock.launched();
                            return;
                        }
                        const n = (dock.cycle[app.entry.id] ?? -1) + 1;
                        dock.cycle[app.entry.id] = n;
                        dock.focusRequested(app.wins[n % app.wins.length]);
                    }
                }
            }
        }
    }
}
