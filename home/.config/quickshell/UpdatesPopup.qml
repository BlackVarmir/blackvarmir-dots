import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Список оновлень під значком на панелі. Esc або клік повз — закрити.
PanelWindow {
    id: pop

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Panels.updatesOpen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "varmir-updates"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property bool showAll: false
    onVisibleChanged: if (visible) { showAll = false; keys.forceActiveFocus(); }

    Item { id: keys; anchors.fill: parent; focus: true; Keys.onEscapePressed: Panels.updatesOpen = false }
    MouseArea { anchors.fill: parent; onClicked: Panels.updatesOpen = false }

    component PkgRow: Item {
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: 32
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.05) }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 18
            width: parent.width - ver.implicitWidth - 48
            elide: Text.ElideRight
            text: modelData.name
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }
        Text {
            id: ver
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 18
            textFormat: Text.StyledText
            text: `<font color="${Theme.textSubtle}">${modelData.from} →</font> ${modelData.to}`
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: 12
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: Theme.edge
        y: Theme.barMargin + Theme.barHeight + 8
        width: 460
        height: Math.min(col.implicitHeight + 8, pop.height - y - 20)
        radius: Theme.radiusOverlay
        color: Theme.glassStrong
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        clip: true
        MouseArea { anchors.fill: parent }

        Flickable {
            anchors.fill: parent
            contentHeight: col.implicitHeight + 8
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 18
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: Updates.count > 0 ? Tr.plural(Updates.count, "plural.updates") : Tr.t("about.upToDate")
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: Tr.t("upd.checked", Qt.formatTime(new Date(Updates.checkedAt), Settings.clock24 ? "HH:mm" : "h:mm AP"))
                                + (Updates.downloadBytes > 0 ? " · " + Updates.sizeText() : "")
                            color: Theme.textSubtle
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                    VButton {
                        visible: Updates.count > 0
                        text: Updates.news.length > 0 ? Tr.t("upd.readFirst") : Tr.t("about.update")
                        onClicked: {
                            if (Updates.news.length > 0) {
                                Qt.openUrlExternally(Updates.news[0].link);
                                Updates.markNewsRead();
                            } else {
                                Updates.upgrade();
                            }
                        }
                    }
                }

                // Новини Arch після останнього оновлення
                Repeater {
                    model: Updates.news
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.bottomMargin: 10
                        implicitHeight: newsCol.implicitHeight + 22
                        radius: 12
                        color: Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.1)
                        border.width: 1
                        border.color: Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.3)
                        ColumnLayout {
                            id: newsCol
                            x: 14
                            y: 11
                            width: parent.width - 28
                            spacing: 4
                            Text {
                                text: Tr.t("upd.news") + " · " + new Date(modelData.date).toLocaleDateString(Tr.locale, "d MMMM")
                                color: Theme.warning
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: modelData.title
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                            Text {
                                text: Tr.t("upd.read")
                                color: Theme.emeraldLight
                                font.family: Theme.font
                                font.pixelSize: 12
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally(modelData.link)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: Updates.repo.length > 0
                    Layout.leftMargin: 18
                    Layout.bottomMargin: 6
                    text: "ARCH · " + Updates.repo.length
                    color: Theme.textSubtle
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                }
                Repeater {
                    model: pop.showAll ? Updates.repo : Updates.repo.slice(0, 6)
                    PkgRow {}
                }
                Text {
                    visible: !pop.showAll && Updates.repo.length > 6
                    Layout.leftMargin: 18
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    text: Tr.t("upd.more", Updates.repo.length - 6)
                    color: Theme.emeraldLight
                    font.family: Theme.font
                    font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.showAll = true }
                }
                Text {
                    visible: Updates.aur.length > 0
                    Layout.leftMargin: 18
                    Layout.topMargin: 10
                    Layout.bottomMargin: 6
                    text: "AUR · " + Updates.aur.length
                    color: Theme.textSubtle
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                }
                Repeater {
                    model: Updates.aur
                    PkgRow {}
                }
                Item { implicitHeight: 10 }
            }
        }
    }
}
