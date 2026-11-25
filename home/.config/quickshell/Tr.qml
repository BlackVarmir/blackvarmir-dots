pragma Singleton

import QtQuick
import Quickshell

// Переклад оболонки. Рядки лежать у Strings.qml (uk, en).
// Використання: Tr.t("cc.dnd") або з підстановкою Tr.t("time.hm", 3, 12) → «3 год 12 хв».
// Мова: з налаштувань («Як у системі» — за змінною LANG сеансу).
// Щоб додати мову: новий словник у Strings.qml і назва в languages нижче.
Singleton {
    id: tr

    readonly property var languages: ["uk", "en"]
    readonly property string systemLang: {
        const sys = String(Quickshell.env("LANG") || Qt.locale().name).slice(0, 2);
        return languages.indexOf(sys) !== -1 ? sys : "en";
    }
    readonly property string lang: languages.indexOf(Settings.shellLang) !== -1 ? Settings.shellLang : systemLang
    readonly property var locale: Qt.locale(lang === "uk" ? "uk_UA" : "en_US")

    function t(key, ...args) {
        const dict = Strings[lang] || Strings.uk;
        let s = dict[key];
        if (s === undefined) s = Strings.uk[key];
        if (s === undefined) return key;
        for (let i = 0; i < args.length; i++)
            s = s.split("{" + i + "}").join(String(args[i]));
        return s;
    }

    // Множина: «1 вікно / 2 вікна / 5 вікон», англійською «1 window / 2 windows»
    function plural(n, key) {
        const forms = t(key).split("|");
        if (lang === "uk") {
            const m10 = n % 10, m100 = n % 100;
            const i = m10 === 1 && m100 !== 11 ? 0
                : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? 1 : 2;
            return n + " " + (forms[i] ?? forms[forms.length - 1]);
        }
        return n + " " + (n === 1 ? forms[0] : (forms[1] ?? forms[0]));
    }
}
