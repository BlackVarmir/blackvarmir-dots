import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Спливаючі картки праворуч під панеллю.
// Самі сповіщення живуть у NotifStore; тут лише ті, що зараз «спливли».
PanelWindow {
    id: root

    readonly property var popups: NotifStore.list.filter(n => NotifStore.popupIds.indexOf(n.id) !== -1)

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
    // Коли відкритий центр керування, сповіщення вже видно там
    visible: popups.length > 0 && !Panels.controlOpen

    WlrLayershell.namespace: "varmir-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: stack
        width: parent.width
        spacing: 10

        Repeater {
            model: root.popups

            NotificationCard {
                id: card
                required property var modelData
                notification: modelData
                width: stack.width
                onCloseRequested: NotifStore.dismiss(modelData)

                // Картка ховається, але сповіщення лишається в історії
                Timer {
                    running: !card.critical
                    interval: card.notification.expireTimeout > 0 ? card.notification.expireTimeout : 5000
                    onTriggered: NotifStore.hidePopup(card.notification.id)
                }
            }
        }
    }
}
