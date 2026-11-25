pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Закріплені в доці застосунки. Зберігаються в ~/.local/state/blackvarmir/dock.json
// (каталог задає «//@ pragma StateDir» у shell.qml), тож переживають перезапуск.
// Перший запуск бере список за замовчуванням з Theme.pinnedApps.
Singleton {
    id: store

    readonly property var pinned: adapter.pinned

    function isPinned(id) {
        return adapter.pinned.indexOf(id) !== -1;
    }

    function pin(id) {
        if (!isPinned(id)) adapter.pinned = adapter.pinned.concat([id]);
    }

    function unpin(id) {
        adapter.pinned = adapter.pinned.filter(x => x !== id);
    }

    // step: -1 — ліворуч, +1 — праворуч
    function move(id, step) {
        const list = adapter.pinned.slice();
        const i = list.indexOf(id);
        const j = i + step;
        if (i < 0 || j < 0 || j >= list.length) return;
        list[i] = list[j];
        list[j] = id;
        adapter.pinned = list;
    }

    FileView {
        path: Quickshell.statePath("dock.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // Файлу ще немає — створити зі списком за замовчуванням
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property list<string> pinned: Theme.pinnedApps
        }
    }
}
