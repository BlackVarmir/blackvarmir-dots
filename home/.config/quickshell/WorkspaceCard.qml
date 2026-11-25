import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Картка одного робочого стола в огляді: підпис, мініатюри вікон у реальних пропорціях,
// наведення (підйом і «×»), приймання перетягнутих вікон.
Item {
    id: card

    required property int wsId
    required property var overview

    readonly property var ws: Workspaces.find(wsId)
    readonly property var windows: overview.allWindows.filter(t => t.workspace?.id === wsId)
    readonly property bool isActive: overview.monitor?.activeWorkspace?.id === wsId
    readonly property bool isSelected: overview.selectedWs === wsId
    readonly property bool hovered: cardArea.containsMouse
    readonly property bool isDropTarget: drop.containsDrag

    // Порожній стіл наприкінці: картка «＋ Новий стіл»
    readonly property bool isNew: Workspaces.trailing === wsId && !isActive
    readonly property string title: isNew ? Tr.t("ws.new") : Workspaces.name(wsId)

    height: label.height + 10 + overview.cardH

    // Підпис
    Row {
        id: label
        spacing: 10
        Text {
            text: card.wsId
            color: card.isActive || card.isSelected ? Theme.emerald : Theme.textSubtle
            font.family: Theme.mono
            font.pixelSize: 15
        }
        Text {
            text: card.isDropTarget ? Tr.t("overview.dropTarget", card.title) : card.title
            color: card.isDropTarget ? Theme.emeraldLight : (card.isNew ? Theme.textSubtle : Theme.text)
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Text {
            visible: !card.isNew
            text: card.windows.length === 0 ? Tr.t("overview.empty") : Plural.windows(card.windows.length)
            color: Theme.textSubtle
            font.family: Theme.font
            font.pixelSize: 13
        }
    }

    // Рамка вибору клавіатурою / активного стола: фірмовий градієнт
    Rectangle {
        id: frame
        y: label.height + 10
        width: parent.width
        height: overview.cardH
        radius: 14
        visible: card.isSelected || card.isActive
        opacity: card.isSelected ? 1 : 0.55
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.emerald }
            GradientStop { position: 1; color: Theme.cyan }
        }
    }

    Rectangle {
        id: surface
        y: label.height + 10
        width: parent.width
        height: overview.cardH
        radius: 14
        clip: true
        color: card.isDropTarget ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.1) : (card.isNew ? "transparent" : "#0d0d0f")
        border.width: card.isNew ? 0 : (frame.visible ? 2 : 1)
        border.color: frame.visible ? "transparent" : (card.hovered ? Qt.rgba(1, 1, 1, 0.28) : Theme.hairline)

        // Наведення: підйом і легке збільшення
        transform: [
            Scale {
                origin.x: surface.width / 2
                origin.y: surface.height / 2
                xScale: card.hovered && !card.isDropTarget ? 1.03 : 1
                yScale: xScale
                Behavior on xScale { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            },
            Translate {
                y: card.hovered ? -6 : 0
                Behavior on y { NumberAnimation { duration: Theme.base; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
            }
        ]

        // Шпалери-аура в мініатюрі
        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: "file://" + Quickshell.env("HOME") + "/.local/share/blackvarmir/wallpapers/varmir-aura.png"
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 540
            asynchronous: true
            opacity: 0.9
            visible: !card.isNew
        }

        // Пунктирна рамка картки «Новий стіл»
        Shape {
            anchors.fill: parent
            visible: card.isNew
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: card.hovered ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.22)
                strokeWidth: 1.5
                strokeStyle: ShapePath.DashLine
                dashPattern: [4, 4]
                startX: 14; startY: 1
                PathLine { x: surface.width - 14; y: 1 }
                PathArc { x: surface.width - 1; y: 14; radiusX: 13; radiusY: 13 }
                PathLine { x: surface.width - 1; y: surface.height - 14 }
                PathArc { x: surface.width - 14; y: surface.height - 1; radiusX: 13; radiusY: 13 }
                PathLine { x: 14; y: surface.height - 1 }
                PathArc { x: 1; y: surface.height - 14; radiusX: 13; radiusY: 13 }
                PathLine { x: 1; y: 14 }
                PathArc { x: 14; y: 1; radiusX: 13; radiusY: 13 }
            }
        }

        // Пунктирна підсвітка цілі перетягування
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "transparent"
            visible: card.isDropTarget
            border.width: 2
            border.color: Theme.emerald
        }

        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.overview.goToWorkspace(card.wsId)
        }

        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["varmir-window"]
            onDropped: d => {
                const addr = d.source.addr;
                const from = card.overview.allWindows.find(t => t.address === addr)?.workspace?.id;
                if (addr && from !== card.wsId) card.overview.moveWindow(addr, card.wsId);
            }
        }

        // Мініатюри вікон у реальних пропорціях
        Repeater {
            model: card.windows

            WindowThumb {
                required property var modelData
                toplevel: modelData
                overview: card.overview
                k: surface.width / card.overview.monW
            }
        }

        Text {
            anchors.centerIn: parent
            visible: card.windows.length === 0
            text: card.isDropTarget ? Tr.t("overview.dropHere") : "+"
            color: Theme.textSubtle
            font.family: Theme.font
            font.pixelSize: card.isDropTarget ? 14 : 26
        }
    }
}
