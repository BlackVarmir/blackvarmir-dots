import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Мова і регіон: мова системи і форматів (через помічник root), мова оболонки,
// 24-годинний час, часовий пояс і синхронізація часу.
SetPage {
    id: page

    title: Tr.t("set.lang")
    subtitle: Tr.t("lang.subtitle")

    readonly property var locales: [
        { value: "uk_UA.UTF-8", label: "Українська" },
        { value: "en_US.UTF-8", label: "English (US)" },
        { value: "en_GB.UTF-8", label: "English (UK)" },
        { value: "pl_PL.UTF-8", label: "Polski" },
        { value: "de_DE.UTF-8", label: "Deutsch" }
    ]
    readonly property var regions: [
        { value: "uk_UA.UTF-8", label: Tr.t("region.ua") },
        { value: "en_US.UTF-8", label: Tr.t("region.us") },
        { value: "en_GB.UTF-8", label: Tr.t("region.gb") },
        { value: "pl_PL.UTF-8", label: Tr.t("region.pl") },
        { value: "de_DE.UTF-8", label: Tr.t("region.de") }
    ]

    // Поточні значення з сеансу; змінюються після успішного застосування
    property string sysLang: Quickshell.env("LANG") || "en_US.UTF-8"
    property string region: Quickshell.env("LC_TIME") || sysLang
    property string timezone: ""
    property var timezones: []
    property bool ntp: true
    property bool relogNeeded: false
    property string error: ""

    readonly property var previewLocale: Qt.locale(region.split(".")[0])
    readonly property date now: new Date()

    RootAction {
        id: localeAction
        onFinished: ok => { if (ok) page.relogNeeded = true; else page.error = Tr.t("set.rootFailed"); }
    }
    RootAction {
        id: timeAction
        onFinished: ok => { if (!ok) page.error = Tr.t("set.rootFailed"); timeProbe.running = true; }
    }

    // Часовий пояс, NTP і список поясів
    Process {
        id: timeProbe
        running: true
        command: ["sh", "-c", "timedatectl show -p Timezone --value; timedatectl show -p NTP --value; timedatectl list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.length > 0);
                page.timezone = lines[0] || "";
                page.ntp = lines[1] === "yes";
                page.timezones = lines.slice(2).map(z => ({ value: z, label: z.replace(/_/g, " ") }));
            }
        }
    }

    function applyLocale(lang, formats) {
        error = "";
        sysLang = lang;
        region = formats;
        localeAction.run(["locale", lang, formats]);
    }

    Text {
        visible: page.error.length > 0
        Layout.fillWidth: true
        text: page.error
        color: Theme.error
        font.family: Theme.font
        font.pixelSize: 13
    }

    GridLayout {
        Layout.fillWidth: true
        columns: page.width > 1100 ? 2 : 1
        columnSpacing: 20
        rowSpacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 20

            SetCard {
                label: Tr.t("lang.eyebrow")

                SetRow {
                    divider: false
                    label: Tr.t("lang.system")
                    hint: Tr.t("lang.systemHint")
                    VSelect {
                        width: 190
                        options: page.locales
                        current: page.sysLang
                        onPicked: v => page.applyLocale(v, page.region)
                    }
                }
                SetRow {
                    stacked: true
                    label: Tr.t("lang.shell")
                    hint: Tr.t("lang.shellHint")
                    Segmented {
                        options: [
                            { value: "system", label: Tr.t("lang.followSystem") },
                            { value: "uk", label: "Українська" },
                            { value: "en", label: "English" }
                        ]
                        current: Settings.shellLang
                        onPicked: v => Settings.set("shellLang", v)
                    }
                }

                // Після зміни мови системи — запропонувати перезайти
                Rectangle {
                    visible: page.relogNeeded
                    Layout.fillWidth: true
                    implicitHeight: relogRow.implicitHeight + 24
                    color: Qt.rgba(34 / 255, 211 / 255, 238 / 255, 0.07)
                    radius: Theme.radiusTile

                    RowLayout {
                        id: relogRow
                        x: 18
                        y: 12
                        width: parent.width - 36
                        spacing: 12
                        Text {
                            text: ""
                            color: Theme.cyan
                            font.family: Theme.mono
                            font.pixelSize: 15
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: Tr.t("lang.relogHint")
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                        VButton {
                            variant: "secondary"
                            text: Tr.t("lang.relog")
                            onClicked: Quickshell.execDetached(["sh", "-c", "command -v hyprshutdown >/dev/null && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"])
                        }
                    }
                }
            }

            SetCard {
                label: Tr.t("time.eyebrow")

                SetRow {
                    divider: false
                    label: Tr.t("time.zone")
                    hint: Qt.formatTime(page.now, Settings.clock24 ? "HH:mm" : "h:mm AP")
                    VSelect {
                        width: 240
                        searchable: true
                        options: page.timezones
                        current: page.timezone
                        onPicked: v => { page.timezone = v; timeAction.run(["timezone", v]); }
                    }
                }
                SetRow {
                    label: Tr.t("time.ntp")
                    hint: Tr.t("time.ntpHint")
                    Toggle {
                        checked: page.ntp
                        onToggled: v => { page.ntp = v; timeAction.run(["ntp", v ? "true" : "false"]); }
                    }
                }
            }

            WeatherCard {}
        }

        SetCard {
            Layout.alignment: Qt.AlignTop
            label: Tr.t("formats.eyebrow")

            SetRow {
                divider: false
                label: Tr.t("formats.region")
                hint: Tr.t("formats.regionHint")
                VSelect {
                    width: 190
                    options: page.regions
                    current: page.region
                    onPicked: v => page.applyLocale(page.sysLang, v)
                }
            }
            SetRow {
                label: Tr.t("formats.clock24")
                Toggle {
                    checked: Settings.clock24
                    onToggled: v => Settings.set("clock24", v)
                }
            }
            SetRow {
                stacked: true
                label: Tr.t("formats.preview")

                GridLayout {
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 8

                    Repeater {
                        model: [
                            [Tr.t("formats.date"), page.now.toLocaleDateString(page.previewLocale, Locale.LongFormat)],
                            [Tr.t("formats.time"), page.now.toLocaleTimeString(page.previewLocale, Settings.clock24 ? "HH:mm" : "h:mm AP")],
                            [Tr.t("formats.number"), Number(1234.56).toLocaleString(page.previewLocale, "f", 2)],
                            [Tr.t("formats.currency"), Number(1234.56).toLocaleCurrencyString(page.previewLocale)]
                        ]
                        Item {
                            required property var modelData
                            required property int index
                            Layout.row: index
                            Layout.column: 0
                            implicitWidth: k.implicitWidth
                            implicitHeight: k.implicitHeight
                            Text { id: k; text: modelData[0]; color: Theme.textMuted; font.family: Theme.font; font.pixelSize: 13 }
                        }
                    }
                    Repeater {
                        model: [
                            page.now.toLocaleDateString(page.previewLocale, Locale.LongFormat),
                            page.now.toLocaleTimeString(page.previewLocale, Settings.clock24 ? "HH:mm" : "h:mm AP"),
                            Number(1234.56).toLocaleString(page.previewLocale, "f", 2),
                            Number(1234.56).toLocaleCurrencyString(page.previewLocale)
                        ]
                        Text {
                            required property var modelData
                            required property int index
                            Layout.row: index
                            Layout.column: 1
                            text: modelData
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
