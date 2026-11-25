import QtQuick

// Кнопка Varmir: primary (градієнт), secondary (рамка), ghost (без фону), danger (червона).
Rectangle {
    id: button

    property string text: ""
    property string variant: "primary"
    property bool small: true
    signal clicked()

    readonly property bool hovered: area.containsMouse

    implicitWidth: label.implicitWidth + (small ? 24 : 32)
    implicitHeight: small ? 30 : 38
    radius: 8
    scale: area.pressed ? 0.98 : 1

    color: variant === "danger" ? Theme.error
        : variant === "secondary" ? (hovered ? Theme.hover : "transparent")
        : variant === "ghost" ? (hovered ? Theme.hover : "transparent")
        : Theme.emerald
    gradient: variant === "primary" ? brand : null
    border.width: variant === "secondary" ? 1 : 0
    border.color: hovered ? Theme.accentBorder : Theme.hairlineStrong

    Gradient {
        id: brand
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.emerald }
        GradientStop { position: 1; color: Theme.cyan }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.variant === "primary" ? Theme.textOnAccent
            : button.variant === "danger" ? "#ffffff"
            : Theme.text
        font.family: Theme.font
        font.pixelSize: button.small ? 13 : 14
        font.weight: Font.Medium
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
