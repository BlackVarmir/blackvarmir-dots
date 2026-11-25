import QtQuick

// Скляний «острівець» панелі: напівпрозорий фон, тонка рамка, заокруглення 12.
// Розмиття під ним робить Hyprland (layer_rule «varmir-glass» у rules.lua).
Rectangle {
    id: root

    default property alias content: row.data
    property int padding: 14
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.radiusIsland
    color: Theme.glass
    border.width: 1
    border.color: Theme.hairline

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: root.padding
        spacing: 14
    }
}
