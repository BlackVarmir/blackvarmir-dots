import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Історія буфера обміну: Super + V. Дані — cliphist (його наповнюють wl-paste --watch
// з autostart.lua). Закріплені записи — ~/.local/share/blackvarmir/clipboard-pins.json.
//   Enter — скопіювати і вставити у вікно, що мало фокус (wtype Ctrl + V)
//   Shift + Enter — лише скопіювати · Ctrl + P — закріпити · Delete — видалити
PanelWindow {
    id: clip

    visible: Panels.clipboardOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "varmir-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/blackvarmir/clipboard"
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/blackvarmir"

    property var history: []      // { id, preview, type, title, meta, image }
    property string query: ""
    property int current: 0

    // Закріплені: зберігаємо сам вміст, бо id у cliphist змінюються
    FileView {
        id: pinFile
        path: clip.dataDir + "/clipboard-pins.json"
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: pins
            property list<string> items: []
        }
    }

    function classify(text) {
        const t = text.trim();
        if (/^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) .*\]\]$/i.test(t)) return "image";
        if (/^(https?|ftp):\/\/\S+$/i.test(t)) return "link";
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t) || /^rgba?\(\s*\d/.test(t)) return "color";
        return "text";
    }

    function typeLabel(type) {
        return Tr.t("clip." + type);
    }

    readonly property var items: {
        const q = query.trim().toLowerCase();
        const pinned = Array.from(pins.items).map(text => ({ id: "", preview: text, type: classify(text), pinned: true }));
        const rest = history.filter(h => Array.from(pins.items).indexOf(h.preview) === -1);
        const all = pinned.concat(rest);
        return q.length === 0 ? all : all.filter(i => i.preview.toLowerCase().indexOf(q) !== -1);
    }
    readonly property var selected: items[current] ?? null
    onItemsChanged: current = Math.min(current, Math.max(0, items.length - 1))

    onVisibleChanged: {
        if (!visible) return;
        input.text = "";
        current = 0;
        input.forceActiveFocus();
        lister.running = true;
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab === -1) continue;
                    const preview = line.slice(tab + 1);
                    out.push({ id: line.slice(0, tab), preview: preview, type: clip.classify(preview), pinned: false });
                }
                clip.history = out;
            }
        }
    }

    // Мініатюри зображень: розпаковуємо в кеш один раз
    property var thumbs: ({})
    Process {
        id: thumber
        property string pendingId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const t = Object.assign({}, clip.thumbs);
                t[thumber.pendingId] = "file://" + clip.cacheDir + "/" + thumber.pendingId + ".png";
                clip.thumbs = t;
            }
        }
    }
    function ensureThumb(item) {
        if (!item || item.type !== "image" || !item.id || thumbs[item.id] || thumber.running) return;
        thumber.pendingId = item.id;
        thumber.command = ["bash", "-c", 'mkdir -p "$1" && [ -s "$1/$2.png" ] || cliphist decode "$2" > "$1/$2.png"; echo', "clip", cacheDir, item.id];
        thumber.running = true;
    }
    onSelectedChanged: ensureThumb(selected)

    function copyCmd(item) {
        if (item.id) return ["bash", "-c", 'cliphist decode "$1" | wl-copy', "clip", item.id];
        return ["wl-copy", "--", item.preview];
    }

    function choose(paste) {
        const item = selected;
        if (!item) return;
        Panels.clipboardOpen = false;
        Quickshell.execDetached(copyCmd(item));
        // Вставляємо, коли фокус уже повернувся у вікно
        if (paste) pasteTimer.start();
    }
    Timer {
        id: pasteTimer
        interval: 180
        onTriggered: Quickshell.execDetached(["wtype", "-M", "ctrl", "v", "-m", "ctrl"])
    }

    function togglePin() {
        const item = selected;
        if (!item || item.type === "image") return;
        const list = Array.from(pins.items);
        const i = list.indexOf(item.preview);
        if (i === -1) list.unshift(item.preview);
        else list.splice(i, 1);
        pins.items = list;
    }

    function remove() {
        const item = selected;
        if (!item) return;
        if (item.pinned) { togglePin(); return; }
        Quickshell.execDetached(["bash", "-c", 'printf "%s\\t%s\\n" "$1" "$2" | cliphist delete', "clip", item.id, item.preview]);
        history = history.filter(h => h.id !== item.id);
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(6 / 255, 6 / 255, 7 / 255, 0.45)
        MouseArea { anchors.fill: parent; onClicked: Panels.clipboardOpen = false }
    }

    Rectangle {
        id: card
        width: 1040
        height: 560
        x: (parent.width - width) / 2
        y: parent.height * 0.16
        radius: Theme.radiusOverlay
        color: Theme.glassStrong
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        clip: true
        MouseArea { anchors.fill: parent }

        // Пошук
        Item {
            id: head
            width: parent.width
            height: 60
            Text {
                id: glyph
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Theme.emerald
                font.family: Theme.mono
                font.pixelSize: 18
            }
            TextInput {
                id: input
                anchors.left: glyph.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 18
                clip: true
                onTextChanged: { clip.query = text; clip.current = 0; }
                Keys.onPressed: event => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    if (event.key === Qt.Key_Escape) Panels.clipboardOpen = false;
                    else if (event.key === Qt.Key_Down) clip.current = Math.min(clip.current + 1, clip.items.length - 1);
                    else if (event.key === Qt.Key_Up) clip.current = Math.max(clip.current - 1, 0);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) clip.choose((event.modifiers & Qt.ShiftModifier) === 0);
                    else if (ctrl && event.key === Qt.Key_P) clip.togglePin();
                    else if (event.key === Qt.Key_Delete) clip.remove();
                    else return;
                    event.accepted = true;
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: Tr.t("clip.search")
                    color: Theme.textSubtle
                    font: input.font
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }
        }

        // Список
        ListView {
            id: list
            anchors.top: head.bottom
            anchors.bottom: foot.top
            anchors.left: parent.left
            width: parent.width - 380
            anchors.margins: 0
            topMargin: 8
            bottomMargin: 8
            clip: true
            model: clip.items
            currentIndex: clip.current
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === clip.current
                // Заголовок групи над першим закріпленим і першим звичайним записом
                readonly property bool header: index === 0 || clip.items[index - 1].pinned !== modelData.pinned
                width: ListView.view.width
                height: 46 + (header ? 28 : 0)

                Text {
                    visible: row.header
                    x: 22
                    y: 10
                    text: row.modelData.pinned ? Tr.t("clip.pinned") : Tr.t("clip.recent")
                    color: Theme.textSubtle
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: row.header ? 28 : 0
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    radius: 10
                    color: row.sel ? Theme.accentSoft : rowArea.containsMouse ? Theme.hover : "transparent"

                    Rectangle {
                        id: tile
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 8
                        color: row.modelData.type === "color" ? row.modelData.preview.trim() : Qt.rgba(1, 1, 1, 0.06)
                        border.width: row.modelData.type === "color" ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        Text {
                            visible: row.modelData.type !== "color"
                            anchors.centerIn: parent
                            text: row.modelData.pinned ? "" : row.modelData.type === "image" ? "" : row.modelData.type === "link" ? "" : ""
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        anchors.left: tile.right
                        anchors.leftMargin: 12
                        anchors.right: meta.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: row.modelData.type === "image" ? Tr.t("clip.image") : row.modelData.preview.replace(/\s+/g, " ")
                        color: Theme.text
                        font.family: row.modelData.type === "color" ? Theme.mono : Theme.font
                        font.pixelSize: 14
                    }
                    Text {
                        id: meta
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: clip.typeLabel(row.modelData.type)
                        color: Theme.textSubtle
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { clip.current = row.index; clip.choose(true); }
                        onEntered: clip.current = row.index
                    }
                }
            }

            Text {
                visible: clip.items.length === 0
                anchors.centerIn: parent
                text: Tr.t("clip.empty")
                color: Theme.textSubtle
                font.family: Theme.font
                font.pixelSize: 14
            }
        }

        // Перегляд
        Rectangle {
            anchors.top: head.bottom
            anchors.bottom: foot.top
            anchors.right: parent.right
            width: 380
            color: "transparent"
            Rectangle { width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.07) }

            Column {
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 12
                visible: clip.selected !== null

                Rectangle {
                    visible: clip.selected?.type === "image"
                    width: parent.width
                    height: 200
                    radius: 12
                    color: Theme.panel
                    border.width: 1
                    border.color: Theme.hairline
                    clip: true
                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: clip.thumbs[clip.selected?.id ?? ""] ?? ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }
                Rectangle {
                    visible: clip.selected?.type === "color"
                    width: parent.width
                    height: 120
                    radius: 12
                    color: clip.selected?.type === "color" ? clip.selected.preview.trim() : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                }
                Text {
                    width: parent.width
                    visible: clip.selected?.type !== "image"
                    text: clip.selected?.preview ?? ""
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 14
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: clip.selected?.type === "text" ? Theme.font : Theme.mono
                    font.pixelSize: 13
                    lineHeight: 1.3
                }
                Text {
                    width: parent.width
                    visible: clip.selected?.type === "image"
                    text: (clip.selected?.preview ?? "").replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "")
                    color: Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: 12
                }
            }
        }

        // Підказки
        Rectangle {
            id: foot
            anchors.bottom: parent.bottom
            width: parent.width
            height: 40
            color: Qt.rgba(1, 1, 1, 0.02)
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: Tr.t("clip.hint")
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 12
            }
        }
    }
}
