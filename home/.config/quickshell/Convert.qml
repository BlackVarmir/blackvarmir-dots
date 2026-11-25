pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Перетворення для Spotlight: «100 usd в грн», «5 km in mi», «20 c в f», «3 gb в mb».
// Курси валют — офіційні курси НБУ (до гривні), раз на день, кеш у ~/.cache/blackvarmir/nbu.json.
Singleton {
    id: conv

    // Одиниці: множник до базової одиниці групи
    readonly property var units: ({
        length: { mm: 0.001, cm: 0.01, m: 1, km: 1000, in: 0.0254, ft: 0.3048, yd: 0.9144, mi: 1609.344 },
        mass: { mg: 1e-6, g: 0.001, kg: 1, t: 1000, oz: 0.028349523125, lb: 0.45359237 },
        data: { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 },
        volume: { ml: 0.001, l: 1, gal: 3.785411784, floz: 0.0295735295625, cup: 0.2365882365 },
        speed: { kmh: 1 / 3.6, ms: 1, mph: 0.44704, kn: 0.514444 },
        time: { ms_: 0.001, s: 1, min: 60, h: 3600, d: 86400, wk: 604800 },
        area: { m2: 1, km2: 1e6, ha: 1e4, ft2: 0.09290304, ac: 4046.8564224 },
        temp: { c: 1, f: 1, k: 1 }
    })

    // Псевдоніми (укр. і англ.) → канонічна назва
    readonly property var aliases: ({
        "мм": "mm", "см": "cm", "м": "m", "метр": "m", "метрів": "m", "км": "km", "кілометр": "km", "кілометрів": "km",
        "дюйм": "in", "дюймів": "in", "inch": "in", "inches": "in", "фут": "ft", "футів": "ft", "feet": "ft", "foot": "ft",
        "ярд": "yd", "миля": "mi", "милі": "mi", "миль": "mi", "mile": "mi", "miles": "mi",
        "мг": "mg", "г": "g", "гр": "g", "грам": "g", "кг": "kg", "т": "t", "тонна": "t", "унція": "oz", "lbs": "lb", "pound": "lb", "pounds": "lb",
        "б": "b", "байт": "b", "кб": "kb", "мб": "mb", "гб": "gb", "тб": "tb",
        "мл": "ml", "л": "l", "літр": "l", "літрів": "l", "галон": "gal", "gallon": "gal",
        "км/год": "kmh", "km/h": "kmh", "kph": "kmh", "м/с": "ms", "m/s": "ms", "миль/год": "mph", "вузол": "kn", "knots": "kn",
        "мс": "ms_", "с": "s", "сек": "s", "sec": "s", "хв": "min", "хвилин": "min", "год": "h", "hr": "h", "hours": "h", "дн": "d", "днів": "d", "days": "d", "тиж": "wk",
        "м2": "m2", "м²": "m2", "км2": "km2", "км²": "km2", "га": "ha",
        "°c": "c", "℃": "c", "°f": "f", "℉": "f", "°k": "k", "цельсій": "c", "фаренгейт": "f", "celsius": "c", "fahrenheit": "f", "kelvin": "k"
    })

    readonly property var currencyAliases: ({
        "грн": "UAH", "гривня": "UAH", "гривень": "UAH", "гривні": "UAH", "₴": "UAH", "uah": "UAH",
        "$": "USD", "долар": "USD", "доларів": "USD", "долари": "USD", "usd": "USD", "dollar": "USD", "dollars": "USD",
        "€": "EUR", "євро": "EUR", "eur": "EUR", "euro": "EUR",
        "zł": "PLN", "злотий": "PLN", "злотих": "PLN", "pln": "PLN",
        "£": "GBP", "gbp": "GBP", "фунтів стерлінгів": "GBP",
        "чеських крон": "CZK", "czk": "CZK", "франк": "CHF", "chf": "CHF", "єна": "JPY", "jpy": "JPY"
    })

    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/blackvarmir/nbu.json"
    property var rates: ({})        // код → гривень за 1 одиницю
    property string ratesDate: ""
    property bool ratesStale: false

    function unitOf(word) {
        const w = word.toLowerCase();
        const c = aliases[w] ?? w;
        for (const g in units) if (units[g][c] !== undefined) return { group: g, unit: c };
        return null;
    }

    function currencyOf(word) {
        const w = word.toLowerCase();
        if (currencyAliases[w]) return currencyAliases[w];
        const up = word.toUpperCase();
        return /^[A-Z]{3}$/.test(up) && (rates[up] !== undefined || up === "UAH") ? up : null;
    }

    function temp(v, from, to) {
        const c = from === "c" ? v : from === "f" ? (v - 32) * 5 / 9 : v - 273.15;
        return to === "c" ? c : to === "f" ? c * 9 / 5 + 32 : c + 273.15;
    }

    function fmt(v, digits) {
        const d = digits ?? (Math.abs(v) >= 100 ? 2 : Math.abs(v) >= 1 ? 3 : 6);
        const n = Number(v.toFixed(d));
        const str = String(n);
        const dec = str.indexOf(".") === -1 || str.indexOf("e") !== -1 ? 0 : str.length - str.indexOf(".") - 1;
        return n.toLocaleString(Tr.locale, "f", digits !== undefined ? digits : Math.min(dec, 6));
    }

    // Розібрати запит. Повертає { value, from, to, result, kind } або null.
    function parse(q) {
        const m = q.trim().replace(",", ".").match(/^(-?\d+(?:\.\d+)?)\s*(.+?)\s+(?:в|у|to|in|->|=)\s+(.+)$/i);
        if (!m) return null;
        const value = parseFloat(m[1]);
        const a = m[2].trim(), b = m[3].trim();

        const ca = currencyOf(a), cb = currencyOf(b);
        if (ca && cb) {
            wantRates();
            const ra = ca === "UAH" ? 1 : rates[ca], rb = cb === "UAH" ? 1 : rates[cb];
            if (ra === undefined || rb === undefined) return { kind: "currency", pending: true, from: ca, to: cb, value: value };
            return { kind: "currency", value: value, from: ca, to: cb, result: value * ra / rb, rate: ra / rb };
        }

        const ua = unitOf(a), ub = unitOf(b);
        if (!ua || !ub || ua.group !== ub.group) return null;
        const result = ua.group === "temp" ? temp(value, ua.unit, ub.unit)
            : value * units[ua.group][ua.unit] / units[ub.group][ub.unit];
        return { kind: "unit", value: value, from: a, to: b, result: result };
    }

    // ───── Курси НБУ ─────
    property bool ratesWanted: false
    function wantRates() {
        if (ratesWanted) return;
        ratesWanted = true;
        cache.reload();
    }

    function today() { return Qt.formatDate(new Date(), "yyyyMMdd"); }

    FileView {
        id: cache
        path: conv.ratesWanted ? conv.cachePath : ""
        onLoaded: {
            try {
                const c = JSON.parse(text());
                conv.rates = c.rates;
                conv.ratesDate = c.date;
            } catch (e) {}
            if (conv.ratesDate !== conv.today()) fetcher.running = true;
        }
        onLoadFailed: fetcher.running = true
    }

    Process {
        id: fetcher
        command: ["curl", "-fsS", "--max-time", "10", "https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    const r = {};
                    for (const x of list) r[x.cc] = x.rate;
                    conv.rates = r;
                    conv.ratesDate = conv.today();
                    conv.ratesStale = false;
                    Quickshell.execDetached(["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "nbu", conv.cachePath,
                        JSON.stringify({ date: conv.ratesDate, rates: r })]);
                } catch (e) {
                    conv.ratesStale = Object.keys(conv.rates).length > 0;
                }
            }
        }
        onExited: code => { if (code !== 0) conv.ratesStale = Object.keys(conv.rates).length > 0; }
    }
}
