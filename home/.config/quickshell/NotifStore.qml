pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Сервер сповіщень і їхня історія.
// Кожне сповіщення лишається в історії центру керування, доки його не закрити.
// Спливаюча картка — окремий стан: вона зникає через 5 с, а запис в історії лишається.
Singleton {
    id: store

    // «Не турбувати»: картки не спливають, але все потрапляє в історію
    property bool dnd: false
    // Скільки сповіщень прийшло, поки панель була закрита, а DND увімкнено
    property int hiddenCount: 0
    // id сповіщень, що зараз показуються спливаючими картками
    property var popupIds: []

    readonly property var list: server.trackedNotifications.values
    readonly property int count: list.length

    function hidePopup(id) {
        popupIds = popupIds.filter(x => x !== id);
    }

    function dismiss(n) {
        hidePopup(n.id);
        n.dismiss();
    }

    function clearAll() {
        const all = list.slice();
        for (let i = 0; i < all.length; i++) all[i].dismiss();
        popupIds = [];
        hiddenCount = 0;
    }

    onDndChanged: if (!dnd) hiddenCount = 0

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: false
        actionsSupported: false

        onNotification: n => {
            n.tracked = true;
            const critical = n.urgency === NotificationUrgency.Critical;
            if (store.dnd && !critical) {
                store.hiddenCount += 1;
            } else {
                store.popupIds = store.popupIds.concat([n.id]);
            }
        }
    }
}
