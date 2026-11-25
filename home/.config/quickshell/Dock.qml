import QtQuick
import Quickshell
import Quickshell.Widgets

// Док в огляді столів: закріплені застосунки + запущені незакріплені (пунктирна рамка).
// Крапка під значком — по одній на кожне вікно (до 3), смарагдова — активне вікно.
// Лівий клік: запущений — перейти до вікна (повторний клік перебирає вікна), не запущений — відкрити.
// Правий клік: меню з вікнами, діями застосунку, закріпленням і порядком.
Rectangle {
    id: dock

    required property var windows
    signal launched()
    signal focusRequested(var toplevel)
    signal closeRequested(var toplevel)

    // Скільки разів клікнули по застосунку — для перебору його вікон
    property var cycle: ({})
    // Індекс значка з відкритим меню, -1 — меню закрите
    property int menuIndex: -1

    function entryFor(t) {
        return DesktopEntries.heuristicLookup(t.lastIpcObject?.class ?? "");
    }
    function windowsOf(entry) {
        return windows.filter(t => entryFor(t)?.id === entry.id);
    }
    function closeMenu() { menuIndex = -1; }

    readonly property var items: {
        const result = [];
        const seen = {};
        const pins = DockStore.pinned;
        for (let i = 0; i < pins.length; i++) {
            const e = DesktopEntries.byId(pins[i]);
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
                readonly property var wins: dock.windowsOf(entry)
                readonly property bool hasActive: wins.some(t => t.activated)
                readonly property bool menuOpen: dock.menuIndex === index
                readonly property bool hovered: area.containsMouse || menuOpen
                // Роздільник перед першим незакріпленим
                readonly property bool firstUnpinned: !modelData.pinned && index > 0 && dock.items[index - 1].pinned
                readonly property int pinPos: DockStore.pinned.indexOf(entry.id)

                width: tile.width + (firstUnpinned ? 17 : 0)
                height: 64
                z: menuOpen ? 10 : 0

                Rectangle {
                    visible: app.firstUnpinned
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
                    border.color: app.hasActive ? Theme.accentBorder
                        : !app.modelData.pinned ? Qt.rgba(1, 1, 1, 0.22)
                        : app.hovered ? Qt.rgba(1, 1, 1, 0.28) : Theme.hairline

                    Behavior on y { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

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

                // Підказка (ховається, коли відкрите меню)
                Rectangle {
                    visible: area.containsMouse && !app.menuOpen
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
                        text: app.entry.name + (app.wins.length > 0 ? " · " + Plural.windows(app.wins.length) : "")
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
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            dock.menuIndex = app.menuOpen ? -1 : app.index;
                            return;
                        }
                        dock.closeMenu();
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

                // ───────────── Контекстне меню ─────────────
                Rectangle {
                    id: menu
                    visible: app.menuOpen
                    anchors.horizontalCenter: tile.horizontalCenter
                    anchors.bottom: tile.top
                    anchors.bottomMargin: 12
                    width: 260
                    height: menuCol.implicitHeight + 12
                    radius: Theme.radiusTile
                    color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.97)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    z: 10

                    // Пункти меню будуються з поточного стану застосунку
                    readonly property var entries: {
                        const e = app.entry;
                        const list = [];
                        list.push({ kind: "header", text: e.name.toUpperCase() + (app.wins.length > 0 ? " · " + Plural.windows(app.wins.length).toUpperCase() : "") });
                        for (let i = 0; i < app.wins.length; i++)
                            list.push({ kind: "item", glyph: "", text: app.wins[i].title || e.name, act: "focus", win: app.wins[i], accent: app.wins[i].activated });
                        list.push({ kind: "sep" });
                        list.push({ kind: "item", glyph: app.wins.length > 0 ? "" : "", text: app.wins.length > 0 ? Tr.t("dock.newWindow") : Tr.t("dock.open"), act: "launch" });
                        const actions = e.actions ?? [];
                        for (let i = 0; i < actions.length; i++)
                            list.push({ kind: "item", glyph: "", text: actions[i].name, act: "action", action: actions[i] });
                        list.push({ kind: "sep" });
                        if (app.modelData.pinned) {
                            if (app.pinPos > 0) list.push({ kind: "item", glyph: "", text: Tr.t("dock.left"), act: "left" });
                            if (app.pinPos >= 0 && app.pinPos < DockStore.pinned.length - 1) list.push({ kind: "item", glyph: "", text: Tr.t("dock.right"), act: "right" });
                            list.push({ kind: "item", glyph: "", text: Tr.t("dock.unpin"), act: "unpin" });
                        } else {
                            list.push({ kind: "item", glyph: "", text: Tr.t("dock.pin"), act: "pin", accent: true });
                        }
                        if (app.wins.length > 0)
                            list.push({ kind: "item", glyph: "", text: app.wins.length === 1 ? Tr.t("dock.closeOne") : Tr.t("dock.closeMany", Plural.windows(app.wins.length)), act: "close", danger: true });
                        return list;
                    }

                    function run(item) {
                        const e = app.entry;
                        switch (item.act) {
                        case "focus": dock.focusRequested(item.win); break;
                        case "launch": e.execute(); dock.launched(); break;
                        case "action": item.action.execute(); dock.launched(); break;
                        case "left": DockStore.move(e.id, -1); break;
                        case "right": DockStore.move(e.id, 1); break;
                        case "unpin": DockStore.unpin(e.id); break;
                        case "pin": DockStore.pin(e.id); break;
                        case "close": app.wins.forEach(t => dock.closeRequested(t)); break;
                        }
                        dock.closeMenu();
                    }

                    // Поглинає кліки по самому меню
                    MouseArea { anchors.fill: parent }

                    Column {
                        id: menuCol
                        x: 6
                        y: 6
                        width: parent.width - 12

                        Repeater {
                            model: menu.entries

                            Item {
                                id: mi
                                required property var modelData
                                width: menuCol.width
                                height: modelData.kind === "sep" ? 11 : modelData.kind === "header" ? 28 : 34

                                Rectangle {
                                    visible: mi.modelData.kind === "sep"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 4
                                    width: parent.width - 8
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                }

                                Text {
                                    visible: mi.modelData.kind === "header"
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20
                                    elide: Text.ElideRight
                                    text: mi.modelData.text ?? ""
                                    color: Theme.textSubtle
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    font.letterSpacing: 1
                                }

                                Rectangle {
                                    visible: mi.modelData.kind === "item"
                                    anchors.fill: parent
                                    radius: 8
                                    color: mi.modelData.accent ? Theme.accentSoft : (itemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                                    Text {
                                        id: itemGlyph
                                        x: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        horizontalAlignment: Text.AlignHCenter
                                        text: mi.modelData.glyph ?? ""
                                        color: mi.modelData.danger ? Theme.error : mi.modelData.accent ? Theme.emerald : Theme.textMuted
                                        font.family: Theme.mono
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        anchors.left: itemGlyph.right
                                        anchors.leftMargin: 10
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        text: mi.modelData.text ?? ""
                                        color: mi.modelData.danger ? Theme.error : mi.modelData.accent ? Theme.emeraldLight : Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                    }
                                    MouseArea {
                                        id: itemArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: menu.run(mi.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
