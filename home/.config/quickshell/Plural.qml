pragma Singleton

import QtQuick
import Quickshell

// Українські форми множини: 1 вікно, 2 вікна, 5 вікон, 21 вікно, 11 вікон.
Singleton {
    function form(n, one, few, many) {
        const mod10 = n % 10;
        const mod100 = n % 100;
        if (mod10 === 1 && mod100 !== 11) return one;
        if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
        return many;
    }

    function windows(n) {
        return n + " " + form(n, "вікно", "вікна", "вікон");
    }
}
