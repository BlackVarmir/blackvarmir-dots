import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Сервер сповіщень (замість mako/dunst) і спливаючі картки праворуч під панеллю.
// Картка зникає через 5 с (або як просить застосунок), клік по ній — закрити.
PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barMargin + Theme.barHeight + 10
        right: Theme.edge
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    visible: server.trackedNotifications.values.length > 0

    WlrLayershell.namespace: "varmir-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: false
        actionsSupported: false

        onNotification: notification => {
            notification.tracked = true;
        }
    }

    Column {
        id: stack
        width: parent.width
        spacing: 10

        Repeater {
            model: server.trackedNotifications

            Rectangle {
                id: card
                required property var modelData
                readonly property var n: modelData

                width: stack.width
                height: content.implicitHeight + 28
                radius: Theme.radiusTile
                color: Theme.glassStrong
                border.width: 1
                border.color: n.urgency === NotificationUrgency.Critical ? Theme.error : Theme.hairline

                Timer {
                    running: card.n.urgency !== NotificationUrgency.Critical
                    interval: card.n.expireTimeout > 0 ? card.n.expireTimeout : 5000
                    onTriggered: card.n.expire()
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: card.n.dismiss()
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
                        color: Theme.accentSoft

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 20
                            source: card.n.appIcon !== ""
                                ? Quickshell.iconPath(card.n.appIcon, "dialog-information")
                                : Quickshell.iconPath("dialog-information")
                        }
                    }

                    Column {
                        width: parent.width - 46
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: card.n.appName.toUpperCase()
                            color: Theme.textSubtle
                            font.family: Theme.mono
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: card.n.summary
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            text: card.n.body
                            color: Theme.textMuted
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
