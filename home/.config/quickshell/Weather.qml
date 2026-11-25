pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Погода (Open-Meteo, без ключів) для панелі і календаря. Оновлення — раз на 30 хв.
// Де ми: 1) точка, задана в «Налаштування → Мова і регіон»;
//        2) інакше — за сусідніми Wi-Fi мережами (nmcli → beaconDB, або Google, якщо вказано ключ);
//        3) якщо мереж база не знає — за IP, з позначкою «приблизно».
// Останній прогноз кешується, тож без інтернету видно останнє відоме значення.
Singleton {
    id: w

    property real lat: NaN
    property real lon: NaN
    property string place: ""
    property string source: ""          // manual · wifi · ip
    property bool approximate: false

    property var current: null          // { temp, feels, code, wind, humidity, isDay }
    property var hourly: []             // [{ hour, temp, code }]
    property var daily: []              // [{ date, max, min, code }]
    property real updatedAt: 0
    property bool stale: false
    readonly property bool ready: current !== null

    readonly property bool manual: Settings.data.weatherMode === "manual" && Settings.data.weatherName !== ""
    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/blackvarmir/weather.json"

    // Одиниці з регіону: США — °F і mph
    readonly property var region: Qt.locale((Quickshell.env("LC_MEASUREMENT") || Quickshell.env("LC_TIME") || Quickshell.env("LANG") || "uk_UA").split(".")[0])
    readonly property bool imperial: region.measurementSystem === Locale.ImperialUSSystem

    function refresh() {
        if (manual) {
            lat = Settings.data.weatherLat;
            lon = Settings.data.weatherLon;
            place = Settings.data.weatherName;
            source = "manual";
            approximate = false;
            fetch();
        } else {
            locateScan.running = true;
        }
    }

    Connections {
        target: Settings.data
        function onWeatherModeChanged() { w.refresh(); }
        function onWeatherLatChanged() { w.refresh(); }
    }

    Timer { interval: 30 * 60 * 1000; repeat: true; running: true; onTriggered: w.refresh() }
    Timer { interval: 4000; running: true; onTriggered: w.refresh() }   // після старту, коли мережа вже є

    // Кеш
    FileView {
        path: w.cachePath
        onLoaded: {
            try {
                const c = JSON.parse(text());
                w.lat = c.lat; w.lon = c.lon; w.place = c.place; w.source = c.source;
                w.approximate = c.approximate; w.current = c.current; w.hourly = c.hourly;
                w.daily = c.daily; w.updatedAt = c.updatedAt;
                w.stale = Date.now() - c.updatedAt > 3 * 3600 * 1000;
            } catch (e) {}
        }
    }
    function saveCache() {
        const c = { lat: lat, lon: lon, place: place, source: source, approximate: approximate,
            current: current, hourly: hourly, daily: daily, updatedAt: updatedAt };
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "weather", cachePath, JSON.stringify(c)]);
    }

    // 1. Сусідні Wi-Fi мережі (без підключення до них)
    Process {
        id: locateScan
        command: ["nmcli", "-t", "-f", "BSSID,SIGNAL,FREQ", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const aps = [];
                for (const line of text.split("\n")) {
                    const parts = line.replace(/\\:/g, "-").split(":");
                    if (parts.length < 3) continue;
                    aps.push({ macAddress: parts[0].replace(/-/g, ":").toLowerCase(),
                        signalStrength: Math.round(parseInt(parts[1]) / 2 - 100),
                        frequency: parseInt(parts[2]) });
                }
                const key = Settings.data.geoKey;
                const url = key ? "https://www.googleapis.com/geolocation/v1/geolocate?key=" + encodeURIComponent(key)
                    : "https://api.beacondb.net/v1/geolocate";
                // considerIp: якщо мереж база не знає, сервіс відповість місцем за IP (з великою похибкою)
                locateAsk.command = ["curl", "-fsS", "--max-time", "15", "-H", "Content-Type: application/json",
                    "-A", "BlackVarmir/1.0", "-d", JSON.stringify({ considerIp: true, wifiAccessPoints: aps }), url];
                locateAsk.running = true;
            }
        }
        onExited: code => { if (code !== 0) w.fetch(); }   // без NetworkManager — прогноз для останньої точки
    }

    Process {
        id: locateAsk
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    const nlat = r.location.lat, nlon = r.location.lng;
                    const moved = isNaN(w.lat) || Math.abs(nlat - w.lat) + Math.abs(nlon - w.lon) > 0.02;
                    w.lat = nlat;
                    w.lon = nlon;
                    // Похибка понад 3 км — це вже не Wi-Fi, а IP
                    w.approximate = (r.accuracy ?? 99999) > 3000;
                    w.source = w.approximate ? "ip" : "wifi";
                    if (moved || !w.place) reverse.ask();
                } catch (e) {}
                w.fetch();
            }
        }
    }

    // Назва місця (OpenStreetMap Nominatim), лише коли точка змінилась
    Process {
        id: reverse
        function ask() {
            command = ["curl", "-fsS", "--max-time", "10", "-A", "BlackVarmir/1.0 (github.com/BlackVarmir/blackvarmir-dots)",
                `https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=10&lat=${w.lat}&lon=${w.lon}&accept-language=${Tr.lang}`];
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    const a = r.address ?? {};
                    w.place = a.city || a.town || a.village || a.municipality || a.county || r.name || "";
                    w.saveCache();
                } catch (e) {}
            }
        }
    }

    // 2. Прогноз
    function fetch() {
        if (isNaN(lat)) return;
        const params = [
            `latitude=${lat.toFixed(4)}`, `longitude=${lon.toFixed(4)}`,
            "current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day",
            "hourly=temperature_2m,weather_code",
            "daily=weather_code,temperature_2m_max,temperature_2m_min",
            "timezone=auto", "forecast_days=4", "forecast_hours=6",
            imperial ? "temperature_unit=fahrenheit&wind_speed_unit=mph" : "wind_speed_unit=ms"
        ].join("&");
        forecast.command = ["curl", "-fsS", "--max-time", "15", "https://api.open-meteo.com/v1/forecast?" + params];
        forecast.running = true;
    }

    Process {
        id: forecast
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    const c = r.current;
                    w.current = { temp: c.temperature_2m, feels: c.apparent_temperature, code: c.weather_code,
                        wind: c.wind_speed_10m, humidity: c.relative_humidity_2m, isDay: c.is_day === 1 };
                    const h = [];
                    for (let i = 1; i < r.hourly.time.length && h.length < 5; i++)
                        h.push({ hour: parseInt(r.hourly.time[i].slice(11, 13)), temp: r.hourly.temperature_2m[i], code: r.hourly.weather_code[i] });
                    w.hourly = h;
                    const d = [];
                    for (let i = 1; i < r.daily.time.length; i++)
                        d.push({ date: r.daily.time[i], max: r.daily.temperature_2m_max[i], min: r.daily.temperature_2m_min[i], code: r.daily.weather_code[i] });
                    w.daily = d;
                    w.updatedAt = Date.now();
                    w.stale = false;
                    w.saveCache();
                } catch (e) {
                    w.stale = w.ready;
                }
            }
        }
        onExited: code => { if (code !== 0) w.stale = w.ready; }
    }

    // ───── Коди погоди WMO → значок (Nerd Font weather) і ключ опису ─────
    function glyph(code, isDay) {
        if (code === 0) return isDay === false ? "" : "";
        if (code <= 2) return isDay === false ? "" : "";
        if (code === 3) return "";
        if (code === 45 || code === 48) return "";
        if (code >= 51 && code <= 67) return code >= 61 ? "" : "";
        if (code >= 71 && code <= 77) return "";
        if (code >= 80 && code <= 82) return "";
        if (code >= 85 && code <= 86) return "";
        if (code >= 95) return "";
        return "";
    }
    function describe(code) {
        if (code === 0) return Tr.t("wx.clear");
        if (code <= 2) return Tr.t("wx.partly");
        if (code === 3) return Tr.t("wx.cloudy");
        if (code === 45 || code === 48) return Tr.t("wx.fog");
        if (code >= 51 && code <= 57) return Tr.t("wx.drizzle");
        if (code >= 61 && code <= 67) return Tr.t("wx.rain");
        if (code >= 71 && code <= 77) return Tr.t("wx.snow");
        if (code >= 80 && code <= 82) return Tr.t("wx.showers");
        if (code >= 85 && code <= 86) return Tr.t("wx.snow");
        if (code >= 95) return Tr.t("wx.storm");
        return Tr.t("wx.cloudy");
    }
    function deg(v) { return Math.round(v) + "°"; }
}
