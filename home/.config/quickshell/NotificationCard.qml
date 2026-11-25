import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Картка сповіщення: однакова для спливаючих і для історії в центрі керування.
Rectangle {
    id: card

    required property var notification
    property bool compact: false
    signal closeRequested()

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical

    implicitHeight: content.implicitHeight + 28
    radius: Theme.radiusTile
    color: compact ? Qt.rgba(1, 1, 1, 0.04) : Theme.glassStrong
    border.width: 1
    border.color: critical ? Theme.error : Theme.hairline

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: card.closeRequested()
    }

    Row {
        id: content
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 12

        Rectangle {
            width: 34
            height: 34
            radius: 9
            color: card.critical ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.12) : Theme.accentSoft

            IconImage {
                anchors.centerIn: parent
                implicitSize: 20
                asynchronous: true
                source: Quickshell.iconPath(card.notification.appIcon || "dialog-information", "dialog-information")
            }
        }

        Column {
            width: parent.width - 46
            spacing: 2

            Item {
                width: parent.width
                height: appName.implicitHeight

                Text {
                    id: appName
                    width: parent.width - 24
                    elide: Text.ElideRight
                    text: (card.notification.appName || Tr.t("notif.default")).toUpperCase()
                    color: Theme.textSubtle
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
                Text {
                    anchors.right: parent.right
                    visible: hover.containsMouse
                    text: "×"
                    color: Theme.textMuted
                    font.pixelSize: 16
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: card.notification.summary
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                visible: text.length > 0
                wrapMode: Text.Wrap
                maximumLineCount: card.compact ? 2 : 3
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: card.notification.body
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 13
            }
        }
    }
}
