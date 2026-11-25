import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Після завантаження зі знімка (меню GRUB / Limine): «Ви в знімку #42 — відновити цей стан?»
PanelWindow {
    id: banner

    property bool dismissed: false

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Snapshots.bootedFrom > 0 && !dismissed
    anchors.top: true
    margins.top: Theme.barMargin + Theme.barHeight + 10
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "varmir-snapshot-banner"

    Rectangle {
        id: card
        width: row.implicitWidth + 36
        height: 60
        radius: 16
        color: Theme.glassStrong
        border.width: 1
        border.color: Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.4)

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 14
            Text {
                text: ""
                color: Theme.warning
                font.family: Theme.mono
                font.pixelSize: 18
            }
            Column {
                Text {
                    text: Tr.t("snap.bannerTitle", Snapshots.bootedFrom)
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Tr.t("snap.bannerBody")
                    color: Theme.textMuted
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
            VButton {
                text: Tr.t("snap.restore")
                onClicked: {
                    banner.dismissed = true;
                    Snapshots.restoreRequest = Snapshots.bootedFrom;
                    Panels.openSettings("snapshots");
                }
            }
            IconButton {
                glyph: ""
                tip: Tr.t("common.close")
                onClicked: banner.dismissed = true
            }
        }
    }
}
