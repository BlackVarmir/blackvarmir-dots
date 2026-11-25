import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Екран блокування через ext-session-lock: якщо оболонка впаде, екран лишиться
// заблокованим (Hyprland покаже суцільний колір), а не відкриється.
// Блокує hypridle: lock_cmd = qs ipc call lock lock (запасний варіант — hyprlock).
Scope {
    id: root

    property bool locked: false
    property string password: ""
    property bool checking: false
    property int failures: 0
    property string error: ""
    property bool capsLock: false
    signal failed()

    function lock() {
        if (locked) return;
        Panels.closeAll();
        password = "";
        error = "";
        locked = true;
    }

    function submit() {
        if (checking || password.length === 0) return;
        checking = true;
        error = "";
        if (!pam.start()) {
            checking = false;
            error = Tr.t("lock.pamError");
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function isLocked(): bool { return root.locked; }
    }

    PamContext {
        id: pam
        // /etc/pam.d/login — той самий стек, що й у hyprlock (pam_faillock теж працює)
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                root.locked = false;
                root.failures = 0;
                root.password = "";
                return;
            }
            root.failures += 1;
            root.password = "";
            if (!root.error)
                root.error = result === PamResult.MaxTries ? Tr.t("lock.maxTries") : Tr.t("lock.wrong", root.failures);
            root.failed();
        }
        onPamMessage: {
            if (responseRequired) {
                respond(root.password);
                return;
            }
            // Наприклад, pam_faillock: «обліковий запис заблоковано на 10 хв»
            if (messageIsError) root.error = message;
        }
    }

    // Caps Lock: Hyprland знає стан основної клавіатури
    Process {
        id: capsProbe
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards ?? [];
                    const main = kb.find(k => k.main) ?? kb[0];
                    root.capsLock = main?.capsLock ?? false;
                } catch (e) {}
            }
        }
    }
    function checkCaps() { if (!capsProbe.running) capsProbe.running = true; }

    WlSessionLock {
        locked: root.locked

        WlSessionLockSurface {
            color: Theme.canvas
            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }
}
