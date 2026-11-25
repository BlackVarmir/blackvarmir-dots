import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io

// Spotlight: Super + Space.
// Без префікса шукає застосунки, а з 3 літер — ще й файли в домашній теці. Префікси:
//   /  лише файли (Enter відкриває, Shift + Enter показує в теці)
//   =  обчислити вираз (Enter копіює результат)
//   >  виконати команду в терміналі
//   ?  шукати в інтернеті
// Застосунки Quickshell тримає в пам'яті. Файли шукає plocate за готовим індексом
// (його оновлює таймер plocate-updatedb щогодини), тож диск під час набору не сканується.
PanelWindow {
    id: spotlight

    visible: Panels.spotlightOpen
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "varmir-spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string query: ""
    property int current: 0
    readonly property int maxResults: 8
    readonly property string home: Quickshell.env("HOME") || ""

    // Файли з plocate: приходять асинхронно, трохи пізніше за застосунки
    property var fileResults: []
    property string fileQuery: ""

    // Які слова шукати у файлах (порожньо — файли не потрібні)
    readonly property string fileTerms: {
        const q = query.trim();
        if (q.startsWith("/")) return q.slice(1).trim();
        if (/^[=>?]/.test(q)) return "";
        return q.length >= 3 ? q : "";
    }
    onFileTermsChanged: {
        fileResults = [];
        if (fileTerms.length === 0) {
            locate.running = false;
            return;
        }
        fileDebounce.restart();
    }

    readonly property var results: {
        const q = query.trim();
        if (q.length === 0) return [];

        if (q.startsWith("=")) {
            const expr = q.slice(1).trim();
            const value = calc(expr);
            return value === null ? [] : [{
                kind: "calc", title: value, subtitle: "Результат · Enter копіює", glyph: "="
            }];
        }
        if (q.startsWith(">")) {
            const cmd = q.slice(1).trim();
            return cmd.length === 0 ? [] : [{
                kind: "cmd", title: cmd, subtitle: "Виконати в новому терміналі", glyph: "", payload: cmd
            }];
        }
        if (q.startsWith("/")) {
            return fileResults.slice(0, maxResults);
        }
        if (q.startsWith("?")) {
            const text = q.slice(1).trim();
            return text.length === 0 ? [] : [{
                kind: "web", title: text, subtitle: "Шукати в інтернеті", glyph: "", payload: text
            }];
        }
        const apps = searchApps(q);
        // Без префікса: застосунки першими, під ними до 3 файлів
        return apps.slice(0, maxResults - Math.min(3, fileResults.length)).concat(fileResults.slice(0, 3));
    }

    // ───────────── Файли (plocate) ─────────────
    Timer {
        id: fileDebounce
        interval: 120
        onTriggered: {
            const words = spotlight.fileTerms.split(/\s+/).filter(w => w.length > 0);
            if (words.length === 0) return;
            locate.running = false;
            spotlight.fileQuery = spotlight.fileTerms;
            // -i без урахування регістру, -b лише за назвою файлу, -e лише наявні файли.
            // Кілька слів — файл має містити всі.
            locate.command = ["plocate", "-i", "-b", "-e", "-l", "400", "--"].concat(words);
            locate.running = true;
        }
    }

    Process {
        id: locate
        stdout: StdioCollector {
            onStreamFinished: {
                // Відповідь на застарілий запит — ігнорувати
                if (spotlight.fileQuery !== spotlight.fileTerms) return;
                spotlight.fileResults = spotlight.rankFiles(text.split("\n"), spotlight.fileTerms);
            }
        }
    }

    function rankFiles(paths, terms) {
        const first = terms.toLowerCase().split(/\s+/)[0];
        const prefix = home + "/";
        const skip = /\/(\.[^/]*|node_modules|__pycache__|target|build|dist)(\/|$)/;
        const scored = [];
        for (let i = 0; i < paths.length; i++) {
            const p = paths[i];
            if (!p.startsWith(prefix)) continue;
            const rel = p.slice(prefix.length);
            if (skip.test("/" + rel)) continue;
            const name = rel.slice(rel.lastIndexOf("/") + 1);
            const lower = name.toLowerCase();
            let score = lower.startsWith(first) ? 100 : /[\s._-]/.test(lower.charAt(lower.indexOf(first) - 1)) ? 80 : 60;
            score -= rel.split("/").length * 3 + name.length * 0.1;
            scored.push({ score: score, path: p, rel: rel, name: name });
        }
        scored.sort((a, b) => b.score - a.score);
        return scored.slice(0, maxResults).map(f => {
            const dir = f.rel.lastIndexOf("/") === -1 ? "~" : "~/" + f.rel.slice(0, f.rel.lastIndexOf("/"));
            return { kind: "file", title: f.name, subtitle: dir, icon: iconForFile(f.name), payload: f.path };
        });
    }

    // Значок за розширенням (є в Papirus і Adwaita); без розширення — тека
    function iconForFile(name) {
        const dot = name.lastIndexOf(".");
        if (dot <= 0) return "folder";
        const ext = name.slice(dot + 1).toLowerCase();
        const map = {
            pdf: "application-pdf",
            png: "image-x-generic", jpg: "image-x-generic", jpeg: "image-x-generic", webp: "image-x-generic", svg: "image-x-generic", gif: "image-x-generic",
            mp3: "audio-x-generic", flac: "audio-x-generic", ogg: "audio-x-generic", wav: "audio-x-generic", m4a: "audio-x-generic",
            mp4: "video-x-generic", mkv: "video-x-generic", webm: "video-x-generic", mov: "video-x-generic",
            zip: "package-x-generic", tar: "package-x-generic", gz: "package-x-generic", xz: "package-x-generic", zst: "package-x-generic", "7z": "package-x-generic",
            doc: "x-office-document", docx: "x-office-document", odt: "x-office-document",
            xls: "x-office-spreadsheet", xlsx: "x-office-spreadsheet", ods: "x-office-spreadsheet", csv: "x-office-spreadsheet",
            ppt: "x-office-presentation", pptx: "x-office-presentation", odp: "x-office-presentation",
            py: "text-x-script", js: "text-x-script", ts: "text-x-script", cs: "text-x-script", sh: "text-x-script", lua: "text-x-script", qml: "text-x-script"
        };
        return map[ext] || "text-x-generic";
    }

    // Безпечний калькулятор: лише цифри, оператори і дужки
    function calc(expr) {
        if (!/^[0-9+\-*/().,%\s^]+$/.test(expr)) return null;
        try {
            const js = expr.replace(/,/g, ".").replace(/\^/g, "**");
            const v = Function(`"use strict"; return (${js});`)();
            if (typeof v !== "number" || !isFinite(v)) return null;
            return String(Math.round(v * 1e10) / 1e10);
        } catch (e) {
            return null;
        }
    }

    function searchApps(q) {
        const needle = q.toLowerCase();
        const scored = [];
        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < apps.length; i++) {
            const a = apps[i];
            if (a.noDisplay) continue;
            const name = a.name.toLowerCase();
            const generic = (a.genericName || "").toLowerCase();
            const keywords = (a.keywords || []).join(" ").toLowerCase();
            let score = 0;
            if (name.startsWith(needle)) score = 100;
            else if (name.indexOf(" " + needle) !== -1) score = 80;
            else if (name.indexOf(needle) !== -1) score = 60;
            else if (generic.indexOf(needle) !== -1) score = 40;
            else if (keywords.indexOf(needle) !== -1) score = 30;
            if (score > 0) scored.push({ score: score - name.length * 0.1, entry: a });
        }
        scored.sort((x, y) => y.score - x.score);
        return scored.slice(0, maxResults).map(s => ({
            kind: "app",
            title: s.entry.name,
            subtitle: s.entry.genericName || s.entry.comment || "Застосунок",
            icon: s.entry.icon,
            entry: s.entry
        }));
    }

    // reveal: true — показати файл у теці замість відкриття (Shift + Enter)
    function activate(index, reveal) {
        const r = results[index];
        if (!r) return;
        if (r.kind === "app") r.entry.execute();
        else if (r.kind === "file") Quickshell.execDetached(reveal ? ["nautilus", "--select", r.payload] : ["xdg-open", r.payload]);
        else if (r.kind === "calc") Quickshell.execDetached(["wl-copy", r.title]);
        else if (r.kind === "cmd") Quickshell.execDetached(["kitty", "--hold", "sh", "-c", r.payload]);
        else if (r.kind === "web") Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(r.payload)]);
        Panels.spotlightOpen = false;
    }

    onVisibleChanged: {
        if (visible) {
            input.text = "";
            current = 0;
            input.forceActiveFocus();
        }
    }
    onResultsChanged: current = 0

    // Затемнення фону; клік повз панель закриває Spotlight
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(6 / 255, 6 / 255, 7 / 255, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.spotlightOpen = false
        }
    }

    Rectangle {
        id: card
        width: 780
        x: (parent.width - width) / 2
        y: parent.height * 0.18
        height: column.implicitHeight
        radius: Theme.radiusOverlay
        color: Theme.glassStrong
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        clip: true

        // Поява: проявлення + підйом на 12 px за 150 мс
        opacity: spotlight.visible ? 1 : 0
        transform: Translate { y: spotlight.visible ? 0 : 12 }
        Behavior on opacity { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

        // Поглинаємо кліки, щоб вони не закривали Spotlight
        MouseArea { anchors.fill: parent }

        Column {
            id: column
            width: parent.width

            // Рядок пошуку
            Item {
                width: parent.width
                height: 72

                Text {
                    id: searchGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Theme.emerald
                    font.family: Theme.mono
                    font.pixelSize: 20
                }

                TextInput {
                    id: input
                    anchors.left: searchGlyph.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Theme.accentBorder
                    font.family: Theme.font
                    font.pixelSize: 24
                    clip: true
                    onTextChanged: spotlight.query = text

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            Panels.spotlightOpen = false;
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                            spotlight.current = Math.min(spotlight.current + 1, spotlight.results.length - 1);
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                            spotlight.current = Math.max(spotlight.current - 1, 0);
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            spotlight.activate(spotlight.current, (event.modifiers & Qt.ShiftModifier) !== 0);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0
                        text: "Застосунки і файли, / лише файли, = обчислити"
                        color: Theme.textSubtle
                        font: input.font
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
                visible: spotlight.results.length > 0
            }

            // Результати
            ListView {
                id: list
                width: parent.width
                height: contentHeight + (count > 0 ? 16 : 0)
                topMargin: 8
                bottomMargin: 8
                interactive: false
                model: spotlight.results
                currentIndex: spotlight.current

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === spotlight.current

                    width: ListView.view.width
                    height: 56

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        radius: 12
                        color: row.selected ? Theme.accentSoft : (hover.containsMouse ? Theme.hover : "transparent")
                        border.width: 1
                        border.color: row.selected ? Theme.accentBorder : "transparent"

                        Rectangle {
                            id: iconTile
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 38
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: Theme.hairline

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 26
                                visible: row.modelData.kind === "app" || row.modelData.kind === "file"
                                source: row.modelData.kind === "app"
                                    ? Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                                    : row.modelData.kind === "file" ? Quickshell.iconPath(row.modelData.icon, "text-x-generic") : ""
                                asynchronous: true
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: row.modelData.kind !== "app" && row.modelData.kind !== "file"
                                text: row.modelData.glyph ?? ""
                                color: Theme.cyan
                                font.family: Theme.mono
                                font.pixelSize: 17
                            }
                        }

                        Column {
                            anchors.left: iconTile.right
                            anchors.leftMargin: 14
                            anchors.right: enterHint.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.modelData.title
                                color: Theme.text
                                font.family: row.modelData.kind === "cmd" ? Theme.mono : Theme.font
                                font.pixelSize: 15
                                font.weight: row.selected ? Font.DemiBold : Font.Normal
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.modelData.subtitle
                                color: Theme.textMuted
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                        }

                        Text {
                            id: enterHint
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.selected
                            text: "⏎"
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: spotlight.current = row.index
                            onClicked: mouse => spotlight.activate(row.index, (mouse.modifiers & Qt.ShiftModifier) !== 0)
                        }
                    }
                }
            }

            // Підказки клавіш
            Rectangle {
                width: parent.width
                height: 44
                color: Qt.rgba(1, 1, 1, 0.02)

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.07)
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: spotlight.results[spotlight.current]?.kind === "file"
                        ? "↑↓ вибір    ⏎ відкрити    ⇧⏎ показати в теці"
                        : "↑↓ вибір    ⏎ відкрити    Esc закрити"
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: "/ файли   = обчислити   > команда   ? веб"
                    color: Theme.textSubtle
                    font.family: Theme.mono
                    font.pixelSize: 12
                }
            }
        }
    }
}
