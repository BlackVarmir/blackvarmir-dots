pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Спільний стан оверлеїв (що відкрито зараз) + керування з терміналу:
//   qs ipc call spotlight toggle
// Саме цю команду викликає Super + Space у ~/.config/hypr/modules/binds.lua.
Singleton {
    id: panels

    property bool spotlightOpen: false

    function toggleSpotlight() { spotlightOpen = !spotlightOpen; }
    function closeAll() { spotlightOpen = false; }

    IpcHandler {
        target: "spotlight"

        function toggle(): void { panels.toggleSpotlight(); }
        function open(): void { panels.spotlightOpen = true; }
        function close(): void { panels.spotlightOpen = false; }
    }
}
