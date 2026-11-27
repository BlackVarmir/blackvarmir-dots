import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Про систему: залізо, версії, оновлення, звіт.
SetPage {
    id: page

    title: Tr.t("set.about")
    subtitle: Tr.t("about.subtitle")

    property var info: ({})
    readonly property int updates: Updates.checkedAt > 0 ? Updates.count : -1
    property bool copied: false

    readonly property var rows: [
        ["about.device", info.device],
        ["about.cpu", info.cpu],
        ["about.memory", info.memory],
        ["about.gpu", info.gpu],
        ["about.disk", info.disk],
        ["about.kernel", info.kernel],
        ["about.hyprland", info.hyprland],
        ["about.quickshell", info.quickshell],
        ["about.uptime", Sys.uptimeText]
    ]

    function report() {
        let out = "BlackVarmir Arch\n";
        for (const r of rows) out += Tr.t(r[0]) + ": " + (r[1] || "—") + "\n";
        return out;
    }

    // Рядок стану і пояснення для картки «Оновлення BlackVarmir»
    readonly property var dots: DotsUpdate.info
    readonly property string dotsStatus: {
        if (DotsUpdate.checkedAt === 0) return DotsUpdate.busy ? Tr.t("about.checking") : Tr.t("dots.notChecked");
        if (dots.error === "offline") return Tr.t("dots.offline");
        if (dots.error === "not-git") return Tr.t("dots.notGit");
        if (dots.result === "updated") return Tr.t("dots.updated", dots.current);
        if (dots.result === "rolled-back") return Tr.t("dots.rolledBack", dots.current);
        if (dots.behind > 0) return Tr.plural(dots.behind, "plural.changes") + " · " + Tr.t("dots.available");
        return Tr.t("dots.upToDate", dots.current);
    }
    readonly property string dotsHint: {
        if (dots.error === "dirty") return Tr.t("dots.hintDirty");
        if (dots.error === "branch") return Tr.t("dots.hintBranch");
        if (dots.error === "ahead") return Tr.t("dots.hintAhead");
        if (dots.error === "no-rollback" || dots.error === "reset-failed" || dots.error === "parse") return Tr.t("dots.hintFailed");
        if (dots.needsInstall && dots.behind > 0) return Tr.t("dots.hintNeedsInstall");
        if (dots.behind > 0) return dots.commits.slice(0, 4).map(c => "• " + c.subject).join("\n");
        return Tr.t("dots.hint");
    }

    Component.onCompleted: { probe.running = true; Updates.check(); DotsUpdate.check(); }

    Process {
        id: probe
        command: ["sh", "-c",
            "echo \"$(hostname)\"; " +
            "echo \"$(cat /sys/class/dmi/id/product_name 2>/dev/null)\"; " +
            "echo \"$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//') · $(nproc)\"; " +
            "echo \"$(free -h --si | awk '/^Mem:/{print $2}')\"; " +
            "echo \"$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | sed 's/^[^:]*: [^:]*: //' | paste -sd '|')\"; " +
            "echo \"$(df -h --output=used,size / | tail -1 | awk '{print $1\" / \"$2}')\"; " +
            "echo \"$(uname -r)\"; " +
            "echo \"$(hyprctl version 2>/dev/null | head -1 | awk '{print $2}')\"; " +
            "echo \"$(qs --version 2>/dev/null | head -1 | awk '{print $2}')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").map(s => s.trim());
                page.info = {
                    device: [l[0], l[1]].filter(s => s).join(" · "),
                    cpu: l[2],
                    memory: l[3],
                    gpu: (l[4] || "").split("|").join("\n"),
                    disk: l[5],
                    kernel: l[6],
                    hyprland: l[7],
                    quickshell: l[8]
                };
            }
        }
    }

    Process {
        id: copier
        command: ["wl-copy", page.report()]
        onExited: { page.copied = true; copiedReset.restart(); }
    }
    Timer { id: copiedReset; interval: 2000; onTriggered: page.copied = false }

    // Шапка: логотип і назва
    RowLayout {
        spacing: 18
        Rectangle {
            implicitWidth: 64
            implicitHeight: 64
            radius: 16
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.emerald }
                GradientStop { position: 1; color: Theme.cyan }
            }
            Text {
                anchors.centerIn: parent
                text: "V"
                color: Theme.textOnAccent
                font.family: Theme.font
                font.pixelSize: 30
                font.weight: Font.Bold
            }
        }
        ColumnLayout {
            spacing: 4
            Text {
                text: "BlackVarmir Arch"
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
            Text {
                text: "Arch Linux · Hyprland · Quickshell"
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
            }
        }
    }

    SetCard {
        label: Tr.t("about.eyebrow")
        Repeater {
            model: page.rows
            SetRow {
                required property var modelData
                required property int index
                divider: index > 0
                label: Tr.t(modelData[0])
                Text {
                    text: modelData[1] || "—"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight
                    Layout.maximumWidth: 420
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    SetCard {
        label: Tr.t("about.updatesEyebrow")
        SetRow {
            divider: false
            label: page.updates < 0 ? Tr.t("about.checking")
                : page.updates === 0 ? Tr.t("about.upToDate")
                : Tr.plural(page.updates, "plural.updates")
            hint: Tr.t("about.updatesHint")
            VButton {
                text: Tr.t("about.update")
                variant: page.updates > 0 ? "primary" : "secondary"
                onClicked: Updates.upgrade()
            }
        }
    }

    // Оновлення самого BlackVarmir з GitHub (main)
    SetCard {
        label: Tr.t("about.dotsEyebrow")
        SetRow {
            divider: false
            label: page.dotsStatus
            hint: page.dotsHint
            Row {
                spacing: 8
                VButton {
                    variant: "secondary"
                    enabled: !DotsUpdate.busy
                    text: Tr.t("dots.check")
                    onClicked: DotsUpdate.check()
                }
                VButton {
                    visible: DotsUpdate.available
                    variant: "primary"
                    enabled: !DotsUpdate.busy
                    text: DotsUpdate.info.needsInstall ? Tr.t("dots.updateSystem") : Tr.t("dots.update")
                    onClicked: DotsUpdate.update()
                }
            }
        }
        SetRow {
            label: Tr.t("dots.auto")
            hint: Tr.t("dots.autoHint")
            Toggle { checked: DotsUpdate.auto; onToggled: v => Settings.set("autoUpdate", v) }
        }
        SetRow {
            visible: DotsUpdate.info.canRollback
            label: Tr.t("dots.rollback")
            hint: Tr.t("dots.rollbackHint")
            VButton {
                variant: "ghost"
                enabled: !DotsUpdate.busy
                text: Tr.t("dots.rollbackButton")
                onClicked: DotsUpdate.rollback()
            }
        }
    }

    RowLayout {
        spacing: 10
        VButton {
            variant: "secondary"
            text: page.copied ? Tr.t("about.copied") : Tr.t("about.copy")
            onClicked: copier.running = true
        }
        VButton {
            variant: "ghost"
            text: Tr.t("about.repo")
            onClicked: Qt.openUrlExternally("https://github.com/BlackVarmir/blackvarmir-dots")
        }
    }
}
