import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Вигляд: шпалери, розмиття, анімації, відступи, заокруглення, рамка активного вікна.
SetPage {
    id: page

    title: Tr.t("set.appearance")
    subtitle: Tr.t("look.subtitle")

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string current: Settings.data.wallpaper || (home + "/.local/share/blackvarmir/wallpapers/varmir-aura.png")
    readonly property var imageFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]

    FolderListModel {
        id: builtIn
        folder: "file://" + page.home + "/.local/share/blackvarmir/wallpapers"
        nameFilters: page.imageFilters
        showDirs: false
    }
    FolderListModel {
        id: own
        folder: "file://" + page.home + "/Pictures/Wallpapers"
        nameFilters: page.imageFilters
        showDirs: false
    }

    // Додати шпалери: вибір файлу (zenity), копія в ~/Pictures/Wallpapers
    Process {
        id: picker
        command: ["sh", "-c",
            "f=$(zenity --file-selection --title=\"" + Tr.t("look.pickTitle") + "\" --file-filter='*.png *.jpg *.jpeg *.webp') || exit 1; " +
            "mkdir -p \"$HOME/Pictures/Wallpapers\"; cp -n \"$f\" \"$HOME/Pictures/Wallpapers/\"; " +
            "echo \"$HOME/Pictures/Wallpapers/$(basename \"$f\")\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p.length > 0) Settings.set("wallpaper", p);
            }
        }
    }

    SetCard {
        label: Tr.t("look.wallpapers")

        SetRow {
            divider: false
            stacked: true
            label: ""
            hint: Tr.t("look.wallpapersHint")

            Flow {
                width: page.width - 116
                spacing: 12

                Repeater {
                    model: builtIn
                    WallpaperThumb {
                        required property string filePath
                        path: filePath
                        selected: filePath === page.current
                        onPicked: Settings.set("wallpaper", filePath)
                    }
                }
                Repeater {
                    model: own
                    WallpaperThumb {
                        required property string filePath
                        path: filePath
                        selected: filePath === page.current
                        onPicked: Settings.set("wallpaper", filePath)
                    }
                }

                Rectangle {
                    width: 170
                    height: 96
                    radius: 10
                    color: addArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    border.width: 1
                    border.color: Theme.hairlineStrong
                    Text {
                        anchors.centerIn: parent
                        text: "+ " + Tr.t("look.add")
                        color: Theme.textMuted
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: addArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.running = true
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: page.width > 1000 ? 2 : 1
        columnSpacing: 20
        rowSpacing: 20

        SetCard {
            Layout.alignment: Qt.AlignTop
            label: Tr.t("look.glassEyebrow")

            SetRow {
                divider: false
                stacked: true
                label: Tr.t("look.blur")
                hint: Tr.t("look.blurHint")
                Segmented {
                    options: [
                        { value: "off", label: Tr.t("common.off") },
                        { value: "light", label: Tr.t("look.light") },
                        { value: "strong", label: Tr.t("look.strong") }
                    ]
                    current: Settings.data.blur
                    onPicked: v => Settings.set("blur", v)
                }
            }
            SetRow {
                stacked: true
                label: Tr.t("look.anim")
                Segmented {
                    options: [
                        { value: "fast", label: Tr.t("look.fast") },
                        { value: "smooth", label: Tr.t("look.smooth") },
                        { value: "off", label: Tr.t("common.off") }
                    ]
                    current: Settings.data.anim
                    onPicked: v => Settings.set("anim", v)
                }
            }
        }

        SetCard {
            Layout.alignment: Qt.AlignTop
            label: Tr.t("look.windowsEyebrow")

            SetRow {
                id: gapsRow
                divider: false
                stacked: true
                property int value: Settings.data.gaps
                label: Tr.t("look.gaps")
                hint: Tr.t("unit.px", value)
                VSlider {
                    width: page.width > 1000 ? 380 : page.width - 116
                    value: gapsRow.value / 30
                    onMoved: v => { gapsRow.value = Math.round(v * 30); gapsApply.restart(); }
                }
                Timer { id: gapsApply; interval: 250; onTriggered: Settings.set("gaps", gapsRow.value) }
            }
            SetRow {
                id: roundRow
                stacked: true
                property int value: Settings.data.rounding
                label: Tr.t("look.rounding")
                hint: Tr.t("unit.px", value)
                VSlider {
                    width: page.width > 1000 ? 380 : page.width - 116
                    value: roundRow.value / 20
                    onMoved: v => { roundRow.value = Math.round(v * 20); roundApply.restart(); }
                }
                Timer { id: roundApply; interval: 250; onTriggered: Settings.set("rounding", roundRow.value) }
            }
            SetRow {
                label: Tr.t("look.gradientBorder")
                Toggle {
                    checked: Settings.data.gradientBorder
                    onToggled: v => Settings.set("gradientBorder", v)
                }
            }
        }
    }
}
