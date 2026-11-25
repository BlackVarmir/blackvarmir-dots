pragma Singleton

import QtQuick
import Quickshell

// Кількість вікон з правильною формою слова для поточної мови оболонки.
Singleton {
    function windows(n) {
        return Tr.plural(n, "plural.windows");
    }
}
