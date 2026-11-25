import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

// Spotlight: Super + Space.
// Без префікса шукає застосунки, команди системи («перез», «wifi»), перетворення
// («100 usd в грн», «5 km в mi»), а з 3 літер — ще й файли в домашній теці. Префікси:
//   :  емодзі («:вогонь»), Enter вставляє
//   #  історія буфера обміну (відкриває її вікно)
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
    // Емодзі (префікс «:») показуються сіткою 8 × 4, як у дизайні
    readonly property bool emojiMode: query.trim().startsWith(":")
    readonly property int emojiColumns: 8
    readonly property string home: Quickshell.env("HOME") || ""

    // Файли з plocate: приходять асинхронно, трохи пізніше за застосунки
    property var fileResults: []
    property string fileQuery: ""

    // Які слова шукати у файлах (порожньо — файли не потрібні)
    readonly property string fileTerms: {
        const q = query.trim();
        if (q.startsWith("/")) return q.slice(1).trim();
        if (/^[=>?:#]/.test(q)) return "";
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
                kind: "calc", title: value, subtitle: Tr.t("sp.calcResult"), glyph: "="
            }];
        }
        if (q.startsWith(">")) {
            const cmd = q.slice(1).trim();
            return cmd.length === 0 ? [] : [{
                kind: "cmd", title: cmd, subtitle: Tr.t("sp.runCmd"), glyph: "", payload: cmd
            }];
        }
        if (q.startsWith("/")) {
            return fileResults.slice(0, maxResults);
        }
        if (q.startsWith(":")) {
            return Emoji.search(q.slice(1), emojiColumns * 4).map(e => ({
                kind: "emoji", title: Tr.lang === "uk" && e.uk ? e.uk : e.en, subtitle: Tr.lang === "uk" ? e.en : e.uk,
                glyph: e.char, payload: e.char
            }));
        }
        if (q.startsWith("?")) {
            const text = q.slice(1).trim();
            return text.length === 0 ? [] : [{
                kind: "web", title: text, subtitle: Tr.t("sp.web"), glyph: "", payload: text
            }];
        }
        const conv = convertResult(q);
        const apps = conv.concat(searchSystem(q), searchSettings(q), searchApps(q));
        // Без префікса: розділи налаштувань і застосунки першими, під ними до 3 файлів
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

    // ───── Перетворення одиниць і валют ─────
    function convertResult(q) {
        const r = Convert.parse(q);
        if (!r) return [];
        if (r.pending) return [{ kind: "info", title: Tr.t("sp.ratesLoading"), subtitle: r.from + " → " + r.to, glyph: "₴" }];
        if (r.kind === "currency") {
            const sub = Tr.t("sp.rateNbu", "1 " + r.from + " = " + Convert.fmt(r.rate, 4) + " " + r.to, Convert.ratesDate.slice(6, 8) + "." + Convert.ratesDate.slice(4, 6))
                + (Convert.ratesStale ? " · " + Tr.t("sp.ratesStale") : "");
            return [{ kind: "calc", title: Convert.fmt(r.result, 2) + " " + r.to, subtitle: sub, glyph: "₴", copy: r.result.toFixed(2) }];
        }
        return [{ kind: "calc", title: Convert.fmt(r.result) + " " + r.to, subtitle: Convert.fmt(r.value) + " " + r.from + " · " + Tr.t("sp.calcResult"), glyph: "⇄", copy: String(Number(r.result.toFixed(6))) }];
    }

    // ───── Команди системи ─────
    readonly property var systemCommands: [
        { id: "poweroff", glyph: "\uf011", words: "вимкнути вимкнення shutdown power off poweroff" },
        { id: "reboot", glyph: "\uf01e", words: "перезавантажити перезавантаження restart reboot" },
        { id: "suspend", glyph: "\uf186", words: "сон заснути призупинити sleep suspend" },
        { id: "logout", glyph: "\uf08b", words: "вийти вихід log out logout sign out" },
        { id: "lock", glyph: "\uf023", words: "заблокувати блокування lock" },
        { id: "wifi", glyph: "\uf1eb", words: "wi-fi wifi вайфай мережа network" },
        { id: "bluetooth", glyph: "\uf293", words: "bluetooth блютуз" },
        { id: "dnd", glyph: "\uf1f6", words: "не турбувати do not disturb dnd сповіщення" },
        { id: "night", glyph: "\uf186", words: "нічне світло night light" },
        { id: "screenshot", glyph: "\uf030", words: "знімок екрана скріншот screenshot screen capture" },
        { id: "record", glyph: "\uf03d", words: "запис екрана записати record screen recording" }
    ]
    function systemTitle(id) {
        if (id === "wifi") return Tr.t("sys.wifi") + ": " + (Networking.wifiEnabled ? Tr.t("sys.turnOff") : Tr.t("sys.turnOn"));
        if (id === "bluetooth") return "Bluetooth: " + (Bluetooth.defaultAdapter?.enabled ? Tr.t("sys.turnOff") : Tr.t("sys.turnOn"));
        if (id === "dnd") return Tr.t("cc.dnd") + ": " + (NotifStore.dnd ? Tr.t("sys.turnOff") : Tr.t("sys.turnOn"));
        if (id === "night") return Tr.t("cc.nightLight") + ": " + (Sys.nightLight ? Tr.t("sys.turnOff") : Tr.t("sys.turnOn"));
        return Tr.t("sys." + id);
    }
    function searchSystem(q) {
        const needle = q.toLowerCase();
        if (needle.length < 3) return [];
        return systemCommands
            .filter(c => c.words.split(" ").some(w => w.startsWith(needle)) || c.words.indexOf(needle) !== -1)
            .slice(0, 3)
            .map(c => ({ kind: "system", title: systemTitle(c.id), subtitle: Tr.t("sys.label"), glyph: c.glyph, payload: c.id }));
    }
    function runSystem(id) {
        if (id === "poweroff" || id === "reboot") { Panels.openPower(id); return true; }
        if (id === "suspend") Quickshell.execDetached(["systemctl", "suspend"]);
        else if (id === "logout") Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]);
        else if (id === "lock") Quickshell.execDetached(["loginctl", "lock-session"]);
        else if (id === "wifi") Networking.wifiEnabled = !Networking.wifiEnabled;
        else if (id === "bluetooth") { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled; }
        else if (id === "dnd") NotifStore.dnd = !NotifStore.dnd;
        else if (id === "night") Sys.nightLight = !Sys.nightLight;
        else if (id === "screenshot") { Capture.action = "shot"; Capture.open(); return true; }
        else if (id === "record") { Capture.action = "record"; Capture.open(); return true; }
        return false;
    }

    // Розділи «Налаштувань»: шукаємо за назвою розділу обома мовами і за словом «налаштування»
    readonly property var settingsSections: ["lang", "keyboard", "display", "appearance", "sound", "power", "snapshots", "user", "about"]
    function searchSettings(q) {
        const needle = q.toLowerCase();
        const words = [Strings.uk["set.title"], Strings.en["set.title"]].map(w => w.toLowerCase());
        const all = words.some(w => w.startsWith(needle));
        const found = [];
        for (const id of settingsSections) {
            const names = [Strings.uk["set." + id], Strings.en["set." + id]].map(w => w.toLowerCase());
            if (all || names.some(n => n.startsWith(needle) || n.indexOf(" " + needle) !== -1))
                found.push({ kind: "setting", title: Tr.t("set." + id), subtitle: Tr.t("sp.settings"), glyph: "\uf013", payload: id });
        }
        // «нал…» без уточнення — один пункт, а не вісім
        if (all && found.length > 1)
            return [{ kind: "setting", title: Tr.t("set.title"), subtitle: Tr.t("sp.settings"), glyph: "\uf013", payload: "" }];
        return found.slice(0, 3);
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
            subtitle: s.entry.genericName || s.entry.comment || Tr.t("sp.app"),
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
        else if (r.kind === "calc") Quickshell.execDetached(["wl-copy", r.copy ?? r.title]);
        else if (r.kind === "info") return;
        else if (r.kind === "system") { if (runSystem(r.payload)) return; }
        else if (r.kind === "emoji") {
            Quickshell.execDetached(["wl-copy", r.payload]);
            Panels.spotlightOpen = false;
            emojiPaste.text = r.payload;
            emojiPaste.start();
            return;
        }
        else if (r.kind === "cmd") Quickshell.execDetached(["kitty", "--hold", "sh", "-c", r.payload]);
        else if (r.kind === "setting") { Panels.openSettings(r.payload); return; }
        else if (r.kind === "web") Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(r.payload)]);
        Panels.spotlightOpen = false;
    }

    // Емодзі вводимо, коли фокус уже повернувся у вікно
    Timer {
        id: emojiPaste
        property string text: ""
        interval: 180
        onTriggered: Quickshell.execDetached(["wtype", "--", text])
    }

    // «#» — перейти до історії буфера обміну
    onQueryChanged: if (query.startsWith("#")) { Panels.closeAll(); Panels.clipboardOpen = true; }

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
                        } else if (spotlight.emojiMode && (event.key === Qt.Key_Left || event.key === Qt.Key_Right) && spotlight.results.length > 0) {
                            spotlight.current = Math.max(0, Math.min(spotlight.results.length - 1, spotlight.current + (event.key === Qt.Key_Right ? 1 : -1)));
                        } else if (spotlight.emojiMode && (event.key === Qt.Key_Down || event.key === Qt.Key_Up) && spotlight.results.length > 0) {
                            spotlight.current = Math.max(0, Math.min(spotlight.results.length - 1, spotlight.current + (event.key === Qt.Key_Down ? 1 : -1) * spotlight.emojiColumns));
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
                        text: Tr.t("sp.placeholder")
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

            // Емодзі: сітка, під нею назва вибраного
            Item {
                visible: spotlight.emojiMode && spotlight.results.length > 0
                width: parent.width
                height: visible ? emojiGrid.height + emojiName.height + 28 : 0

                Grid {
                    id: emojiGrid
                    x: 18
                    y: 14
                    columns: spotlight.emojiColumns
                    spacing: 6
                    readonly property real cell: (parent.width - 36 - spacing * (columns - 1)) / columns

                    Repeater {
                        model: spotlight.emojiMode ? spotlight.results : []
                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool selected: index === spotlight.current
                            width: emojiGrid.cell
                            height: 52
                            radius: 12
                            color: selected ? Theme.accentSoft : emojiArea.containsMouse ? Theme.hover : "transparent"
                            border.width: selected ? 2 : 0
                            border.color: Theme.emerald
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.glyph
                                font.pixelSize: 28
                            }
                            MouseArea {
                                id: emojiArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: spotlight.current = parent.index
                                onClicked: spotlight.activate(parent.index, false)
                            }
                        }
                    }
                }
                Text {
                    id: emojiName
                    x: 22
                    anchors.top: emojiGrid.bottom
                    anchors.topMargin: 10
                    width: parent.width - 44
                    elide: Text.ElideRight
                    text: {
                        const r = spotlight.results[spotlight.current];
                        return r ? r.title + (r.subtitle ? " · " + r.subtitle : "") + "    ⏎ " + Tr.t("sp.emojiInsert") : "";
                    }
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            // Результати
            ListView {
                id: list
                visible: !spotlight.emojiMode
                width: parent.width
                height: visible ? contentHeight + (count > 0 ? 16 : 0) : 0
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
                        ? Tr.t("sp.hintFile")
                        : Tr.t("sp.hint")
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tr.t("sp.prefixes")
                    color: Theme.textSubtle
                    font.family: Theme.mono
                    font.pixelSize: 12
                }
            }
        }
    }
}
