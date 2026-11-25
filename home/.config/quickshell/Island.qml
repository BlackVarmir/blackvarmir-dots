import QtQuick

// Скляний «острівець» панелі: напівпрозорий фон, тонка рамка, заокруглення 12.
// Розмиття під ним робить Hyprland (layer_rule «varmir-glass» у rules.lua).
// clickable: true — увесь острівець стає кнопкою (сигнал clicked).
Rectangle {
    id: root

    default property alias content: row.data
    property int padding: 14
    property alias spacing: row.spacing
    property bool clickable: false
    property bool highlighted: false
    signal clicked()

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.radiusIsland
    color: highlighted ? Theme.accentSoft
        : clickable && islandArea.containsMouse ? Qt.rgba(28 / 255, 28 / 255, 31 / 255, 0.72) : Theme.glass
    border.width: 1
    border.color: highlighted ? Theme.accentBorder : Theme.hairline

    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: islandArea
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: root.padding
        spacing: 14
    }
}
