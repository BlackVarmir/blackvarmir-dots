import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Огляд робочих столів: Super + Tab.
// Сітка столів (динамічна, до 10) з мініатюрами вікон, пошук, перетягування вікон між столами, док.
// Увесь вміст створюється лише на час показу (Loader), тож у закритому стані огляд нічого не коштує.
PanelWindow {
    id: overview

    visible: Panels.overviewOpen
    screen: {
        const name = Hyprland.focusedMonitor?.name ?? "";
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === name) return list[i];
        return list.length > 0 ? list[0] : null;
    }
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "varmir-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (visible) {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    Loader {
        anchors.fill: parent
        active: overview.visible
        sourceComponent: OverviewContent {
            monitor: Hyprland.focusedMonitor
        }
    }
}
