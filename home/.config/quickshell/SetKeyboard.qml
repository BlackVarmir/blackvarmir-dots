import QtQuick
import QtQuick.Layouts

// Клавіатура: розкладки, комбінація перемикання, повтор клавіш.
// Застосовується одразу (hyprctl eval) і зберігається в hyprland-user.lua.
SetPage {
    id: page

    title: Tr.t("set.keyboard")
    subtitle: Tr.t("kb.subtitle")

    readonly property var catalog: Layouts.catalog
    readonly property var layouts: Array.from(Settings.data.kbLayouts)

    function labelOf(code) {
        const f = catalog.find(c => c.value === code);
        return f ? f.label : code;
    }

    SetCard {
        label: Tr.t("kb.layoutsEyebrow")

        SetRow {
            divider: false
            stacked: true
            label: Tr.t("kb.layouts")
            hint: Tr.t("kb.layoutsHint")

            Flow {
                width: parent ? parent.width : 600
                spacing: 8

                Repeater {
                    model: page.layouts

                    Rectangle {
                        id: chip
                        required property string modelData
                        required property int index
                        width: chipRow.implicitWidth + 24
                        height: 34
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Theme.hairlineStrong

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.toUpperCase()
                                color: Theme.emerald
                                font.family: Theme.mono
                                font.pixelSize: 12
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.labelOf(chip.modelData)
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                            // Видалити (останню розкладку видалити не можна)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: page.layouts.length > 1
                                text: "×"
                                color: removeArea.containsMouse ? Theme.error : Theme.textSubtle
                                font.pixelSize: 15
                                MouseArea {
                                    id: removeArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Settings.set("kbLayouts", page.layouts.filter((_, i) => i !== chip.index))
                                }
                            }
                        }
                    }
                }

                VSelect {
                    width: 200
                    visible: options.length > 0
                    options: page.catalog.filter(c => page.layouts.indexOf(c.value) === -1)
                    current: ""
                    placeholder: "+ " + Tr.t("kb.add")
                    onPicked: v => Settings.set("kbLayouts", page.layouts.concat([v]))
                }
            }
        }

        SetRow {
            label: Tr.t("kb.toggle")
            hint: Tr.t("kb.toggleHint")
            VSelect {
                width: 200
                options: [
                    { value: "alt_shift", label: "Alt + Shift" },
                    { value: "ctrl_shift", label: "Ctrl + Shift" },
                    { value: "caps", label: "Caps Lock" }
                ]
                current: Settings.data.kbToggle
                onPicked: v => Settings.set("kbToggle", v)
            }
        }
    }

    SetCard {
        label: Tr.t("kb.repeatEyebrow")

        SetRow {
            divider: false
            label: Tr.t("kb.delay")
            Segmented {
                options: [250, 300, 400, 500].map(v => ({ value: v, label: Tr.t("unit.ms", v) }))
                current: Settings.data.repeatDelay
                onPicked: v => Settings.set("repeatDelay", v)
            }
        }
        SetRow {
            label: Tr.t("kb.rate")
            Segmented {
                options: [25, 30, 40, 50].map(v => ({ value: v, label: Tr.t("unit.perSec", v) }))
                current: Settings.data.repeatRate
                onPicked: v => Settings.set("repeatRate", v)
            }
        }
    }
}
