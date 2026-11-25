pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Спільний стан оверлеїв: одночасно відкритий лише один.
// Керування з терміналу або гарячих клавіш (~/.config/hypr/modules/binds.lua):
//   qs ipc call spotlight toggle   — Super + Space
//   qs ipc call overview toggle    — Super + Tab
//   qs ipc call control toggle     — Super + N
Singleton {
    id: panels

    property bool spotlightOpen: false
    property bool overviewOpen: false
    property bool controlOpen: false

    function closeAll() {
        spotlightOpen = false;
        overviewOpen = false;
        controlOpen = false;
    }

    function toggleSpotlight() { const v = !spotlightOpen; closeAll(); spotlightOpen = v; }
    function toggleOverview()  { const v = !overviewOpen;  closeAll(); overviewOpen = v; }
    function toggleControl()   { const v = !controlOpen;   closeAll(); controlOpen = v; }

    IpcHandler {
        target: "spotlight"
        function toggle(): void { panels.toggleSpotlight(); }
        function open(): void { panels.closeAll(); panels.spotlightOpen = true; }
        function close(): void { panels.spotlightOpen = false; }
    }

    IpcHandler {
        target: "overview"
        function toggle(): void { panels.toggleOverview(); }
        function open(): void { panels.closeAll(); panels.overviewOpen = true; }
        function close(): void { panels.overviewOpen = false; }
    }

    IpcHandler {
        target: "control"
        function toggle(): void { panels.toggleControl(); }
        function open(): void { panels.closeAll(); panels.controlOpen = true; }
        function close(): void { panels.controlOpen = false; }
    }
}
