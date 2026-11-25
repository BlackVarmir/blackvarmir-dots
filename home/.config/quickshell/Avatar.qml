import QtQuick
import Quickshell
import Quickshell.Widgets

// Аватар користувача: ~/.face.icon, а якщо його немає — ініціали на фірмовому градієнті.
Item {
    id: avatar

    property int size: 44
    implicitWidth: size
    implicitHeight: size

    readonly property string initials: {
        const n = (Sys.realName || Quickshell.env("USER") || "?").trim();
        const parts = n.split(/\s+/);
        return (parts.length > 1 ? parts[0].charAt(0) + parts[1].charAt(0) : n.slice(0, 2)).toUpperCase();
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: face.status !== Image.Ready
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.emerald }
            GradientStop { position: 1; color: Theme.cyan }
        }
        Text {
            anchors.centerIn: parent
            text: avatar.initials
            color: Theme.textOnAccent
            font.family: Theme.font
            font.pixelSize: avatar.size * 0.34
            font.weight: Font.Bold
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        visible: face.status === Image.Ready

        Image {
            id: face
            anchors.fill: parent
            source: "file://" + Sys.avatarPath + "?rev=" + Sys.avatarRev
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: avatar.size * 2
            sourceSize.height: avatar.size * 2
            cache: false
            asynchronous: true
        }
    }
}
