pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Емодзі для Spotlight (префікс «:»). Дані — data/emoji.tsv: символ, назва англійською,
// назва українською, ключові слова обома мовами (з Unicode CLDR).
// Файл читається лише при першому пошуку емодзі.
Singleton {
    id: emoji

    property var entries: []
    property bool wanted: false

    FileView {
        path: emoji.wanted ? Quickshell.shellDir + "/data/emoji.tsv" : ""
        onLoaded: {
            const out = [];
            for (const line of text().split("\n")) {
                if (line.length === 0 || line.startsWith("#")) continue;
                const f = line.split("\t");
                out.push({ char: f[0], en: f[1] ?? "", uk: f[2] ?? "", words: ((f[1] ?? "") + " | " + (f[2] ?? "") + " | " + (f[3] ?? "")).toLowerCase() });
            }
            emoji.entries = out;
        }
    }

    function search(q, limit) {
        wanted = true;
        const needle = q.trim().toLowerCase();
        if (needle.length === 0 || entries.length === 0) return [];
        const scored = [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            const uk = e.uk.toLowerCase(), en = e.en.toLowerCase();
            let score = 0;
            if (uk === needle || en === needle) score = 120;
            else if (uk.startsWith(needle) || en.startsWith(needle)) score = 100;
            else if (e.words.indexOf("| " + needle) !== -1 || e.words.indexOf(" " + needle) !== -1) score = 70;
            else if (e.words.indexOf(needle) !== -1) score = 40;
            // Раніші в стандарті — уживаніші
            if (score > 0) scored.push({ score: score - i / 1000, e: e });
        }
        scored.sort((a, b) => b.score - a.score);
        return scored.slice(0, limit).map(s => s.e);
    }
}
