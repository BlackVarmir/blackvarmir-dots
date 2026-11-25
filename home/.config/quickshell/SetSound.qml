import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Звук: пристрої виводу і вводу (PipeWire), гучність, мікрофон.
SetPage {
    id: page

    title: Tr.t("set.sound")
    subtitle: Tr.t("sound.subtitle")

    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var outputs: devices.filter(n => n.isSink)
    readonly property var inputs: devices.filter(n => !n.isSink)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker { objects: [page.sink, page.source] }

    function nameOf(n) {
        return n.nickname || n.description || n.name;
    }

    SetCard {
        label: Tr.t("sound.output")

        Repeater {
            model: page.outputs
            SoundDeviceRow {
                required property var modelData
                required property int index
                divider: index > 0
                node: modelData
                title: page.nameOf(modelData)
                active: modelData === page.sink
                onChosen: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
        SetRow {
            visible: page.sink !== null
            label: Tr.t("sound.volume")
            hint: Math.round((page.sink?.audio?.volume ?? 0) * 100) + "%"
            VSlider {
                width: 320
                value: page.sink?.audio?.volume ?? 0
                onMoved: v => { if (page.sink?.audio) page.sink.audio.volume = v; }
            }
        }
    }

    SetCard {
        label: Tr.t("sound.input")

        Repeater {
            model: page.inputs
            SoundDeviceRow {
                required property var modelData
                required property int index
                divider: index > 0
                node: modelData
                title: page.nameOf(modelData)
                active: modelData === page.source
                onChosen: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
        SetRow {
            visible: page.source !== null
            label: Tr.t("sound.micLevel")
            hint: Math.round((page.source?.audio?.volume ?? 0) * 100) + "%"
            VSlider {
                width: 320
                value: page.source?.audio?.volume ?? 0
                onMoved: v => { if (page.source?.audio) page.source.audio.volume = v; }
            }
        }
        SetRow {
            visible: page.source !== null
            label: Tr.t("sound.micOn")
            Toggle {
                checked: !(page.source?.audio?.muted ?? true)
                onToggled: v => { if (page.source?.audio) page.source.audio.muted = !v; }
            }
        }
    }
}
