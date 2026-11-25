import QtQuick
import QtQuick.Layouts

// Живлення: коли приглушувати екран, блокувати і засинати (hypridle), що робити з кришкою.
SetPage {
    id: page

    title: Tr.t("set.power")
    subtitle: Tr.t("powerset.subtitle")

    property string error: ""

    function minutes(sec) {
        if (sec === 0) return Tr.t("powerset.never");
        if (sec >= 3600) return Tr.t("unit.hour", sec / 3600);
        return Tr.t("unit.min", sec / 60);
    }
    function opts(list) {
        return list.map(v => ({ value: v, label: minutes(v) }));
    }

    RootAction {
        id: lidAction
        onFinished: ok => page.error = ok ? "" : Tr.t("set.rootFailed")
    }

    Text {
        visible: page.error.length > 0
        text: page.error
        color: Theme.error
        font.family: Theme.font
        font.pixelSize: 13
    }

    SetCard {
        label: Tr.t("powerset.idleEyebrow")

        SetRow {
            divider: false
            stacked: true
            label: Tr.t("powerset.dim")
            Segmented {
                options: page.opts([60, 150, 300, 0])
                current: Settings.data.dimAfter
                onPicked: v => Settings.set("dimAfter", v)
            }
        }
        SetRow {
            stacked: true
            label: Tr.t("powerset.lock")
            hint: Tr.t("powerset.lockHint")
            Segmented {
                options: page.opts([120, 300, 900, 0])
                current: Settings.data.lockAfter
                onPicked: v => Settings.set("lockAfter", v)
            }
        }
        SetRow {
            stacked: true
            label: Tr.t("powerset.sleep")
            Segmented {
                options: page.opts([600, 1200, 3600, 0])
                current: Settings.data.sleepAfter
                onPicked: v => Settings.set("sleepAfter", v)
            }
        }
    }

    SetCard {
        label: Tr.t("powerset.lidEyebrow")

        SetRow {
            divider: false
            label: Tr.t("powerset.lid")
            hint: Tr.t("powerset.lidHint")
            VSelect {
                width: 220
                options: [
                    { value: "suspend", label: Tr.t("power.sleep") },
                    { value: "lock", label: Tr.t("powerset.lidLock") },
                    { value: "ignore", label: Tr.t("powerset.lidIgnore") }
                ]
                current: Settings.data.lid
                onPicked: v => { Settings.set("lid", v); lidAction.run(["lid", v]); }
            }
        }
    }
}
