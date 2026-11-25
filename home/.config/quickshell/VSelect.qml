import QtQuick
import QtQuick.Layouts

// Випадний список у стилі Varmir. options — [{ value, label }].
// searchable: true — поле пошуку над списком (для довгих списків, як часові пояси).
Item {
    id: sel

    property var options: []
    property var current
    property bool searchable: false
    // Текст, коли значення не вибране (наприклад, «+ Додати»)
    property string placeholder: ""
    property int popupHeight: 300
    signal picked(var value)

    property bool open: false
    property string filter: ""

    readonly property string currentLabel: {
        for (let i = 0; i < options.length; i++)
            if (options[i].value === current) return options[i].label;
        return placeholder || String(current ?? "");
    }
    readonly property var shown: filter.length === 0 ? options
        : options.filter(o => o.label.toLowerCase().indexOf(filter.toLowerCase()) !== -1)

    implicitWidth: 220
    implicitHeight: 36

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.inset
        border.width: 1
        border.color: sel.open ? Theme.accentBorder : (area.containsMouse ? Theme.hairlineStrong : Theme.hairline)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chevron.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: sel.currentLabel
            color: sel.placeholder && sel.currentLabel === sel.placeholder ? Theme.textMuted : Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }
        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: sel.open ? "" : ""
            color: Theme.textSubtle
            font.family: Theme.mono
            font.pixelSize: 10
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                sel.filter = "";
                if (!sel.open) {
                    // Список малюється поверх усього вікна, щоб його не перекривали нижні рядки
                    const p = sel.mapToItem(popup.parent, 0, sel.height + 6);
                    popup.x = Math.min(p.x, popup.parent.width - popup.width - 12);
                    popup.y = p.y + popup.height > popup.parent.height - 12 ? p.y - popup.height - sel.height - 12 : p.y;
                }
                sel.open = !sel.open;
                if (sel.open && sel.searchable) search.forceActiveFocus();
            }
        }
    }

    // Клік повз відкритий список закриває його
    MouseArea {
        parent: sel.Window.contentItem
        anchors.fill: parent
        visible: sel.open
        z: 999
        onClicked: sel.open = false
    }

    Rectangle {
        id: popup
        parent: sel.Window.contentItem
        visible: sel.open
        z: 1000
        width: Math.max(sel.width, 240)
        height: Math.min(sel.popupHeight, list.contentHeight + (sel.searchable ? 46 : 0) + 12)
        radius: 12
        color: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.99)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 6

            Rectangle {
                visible: sel.searchable
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 8
                color: Theme.inset
                border.width: 1
                border.color: Theme.hairline
                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    onTextChanged: sel.filter = text
                    Keys.onEscapePressed: sel.open = false
                    onAccepted: if (sel.shown.length > 0) { sel.picked(sel.shown[0].value); sel.open = false; }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length === 0
                        text: Tr.t("set.search")
                        color: Theme.textSubtle
                        font: search.font
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: sel.shown
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: item
                    required property var modelData
                    readonly property bool on: modelData.value === sel.current
                    width: ListView.view.width
                    height: 32
                    radius: 7
                    color: on ? Theme.accentSoft : (itemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: item.modelData.label
                        color: item.on ? Theme.emeraldLight : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { sel.picked(item.modelData.value); sel.open = false; }
                    }
                }
            }
        }
    }
}
