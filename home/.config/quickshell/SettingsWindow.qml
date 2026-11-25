import QtQuick
import QtQuick.Layouts
import Quickshell

// Застосунок «Налаштування»: Super + , або зі Spotlight / центру керування.
// Звичайне вікно (Hyprland робить його плаваючим за правилом у rules.lua).
// Створюється лише поки відкрите, тож у закритому стані нічого не коштує.
LazyLoader {
    active: Panels.settingsOpen

    FloatingWindow {
        id: win

        title: Tr.t("set.title")
        implicitWidth: 1280
        implicitHeight: 820
        minimumSize: Qt.size(960, 640)
        color: "#0f0f11"

        onClosed: Panels.settingsOpen = false
        Component.onCompleted: Sys.refresh()

        Component { id: cLang; SetLanguage {} }
        Component { id: cKeyboard; SetKeyboard {} }
        Component { id: cDisplay; SetDisplay {} }
        Component { id: cAppearance; SetAppearance {} }
        Component { id: cSound; SetSound {} }
        Component { id: cPower; SetPower {} }
        Component { id: cUser; SetUser {} }
        Component { id: cSnapshots; SetSnapshots {} }
        Component { id: cAbout; SetAbout {} }

        readonly property var sections: [
            { id: "lang", glyph: "", label: Tr.t("set.lang") },
            { id: "keyboard", glyph: "", label: Tr.t("set.keyboard") },
            { id: "display", glyph: "", label: Tr.t("set.display") },
            { id: "appearance", glyph: "", label: Tr.t("set.appearance") },
            { id: "sound", glyph: "", label: Tr.t("set.sound") },
            { id: "power", glyph: "", label: Tr.t("set.power") },
            { id: "snapshots", glyph: "\uf1da", label: Tr.t("set.snapshots") },
            { id: "user", glyph: "", label: Tr.t("set.user") },
            { id: "about", glyph: "", label: Tr.t("set.about") }
        ]
        property string query: ""
        readonly property var visibleSections: query.length === 0 ? sections
            : sections.filter(s => s.label.toLowerCase().indexOf(query.toLowerCase()) !== -1)

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Panels.settingsOpen = false

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ───────────── Бічне меню ─────────────
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 260
                    color: Qt.rgba(1, 1, 1, 0.025)

                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: Qt.rgba(1, 1, 1, 0.07)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        anchors.topMargin: 20
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 14
                            implicitHeight: 38
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: search.activeFocus ? Theme.accentBorder : Theme.hairline

                            Text {
                                id: searchGlyph
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                color: Theme.textSubtle
                                font.family: Theme.mono
                                font.pixelSize: 13
                            }
                            TextInput {
                                id: search
                                anchors.left: searchGlyph.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 13
                                onTextChanged: win.query = text
                                onAccepted: if (win.visibleSections.length > 0) Panels.settingsSection = win.visibleSections[0].id
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: search.text.length === 0
                                    text: Tr.t("set.searchSettings")
                                    color: Theme.textSubtle
                                    font: search.font
                                }
                            }
                        }

                        Repeater {
                            model: win.visibleSections

                            Rectangle {
                                id: navItem
                                required property var modelData
                                readonly property bool on: Panels.settingsSection === modelData.id

                                Layout.fillWidth: true
                                implicitHeight: 38
                                radius: 10
                                color: on ? Theme.accentSoft : (navArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                border.width: on ? 1 : 0
                                border.color: Theme.accentBorder

                                Row {
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    Text {
                                        width: 18
                                        horizontalAlignment: Text.AlignHCenter
                                        text: navItem.modelData.glyph
                                        color: navItem.on ? Theme.emeraldLight : Theme.textMuted
                                        font.family: Theme.mono
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        text: navItem.modelData.label
                                        color: navItem.on ? Theme.emeraldLight : "#d4d4d8"
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        font.weight: navItem.on ? Font.DemiBold : Font.Normal
                                    }
                                }
                                MouseArea {
                                    id: navArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Panels.settingsSection = navItem.modelData.id
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Користувач унизу
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.07)
                        }
                        RowLayout {
                            Layout.topMargin: 8
                            spacing: 10
                            Avatar { size: 34 }
                            ColumnLayout {
                                spacing: 0
                                Text {
                                    text: Sys.realName || Quickshell.env("USER") || ""
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: Quickshell.env("USER") || ""
                                    color: Theme.textSubtle
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                // ───────────── Розділ ─────────────
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: {
                        switch (Panels.settingsSection) {
                        case "keyboard": return cKeyboard;
                        case "display": return cDisplay;
                        case "appearance": return cAppearance;
                        case "sound": return cSound;
                        case "power": return cPower;
                        case "user": return cUser;
                        case "snapshots": return cSnapshots;
                        case "about": return cAbout;
                        default: return cLang;
                        }
                    }
                }
            }
        }
    }
}
