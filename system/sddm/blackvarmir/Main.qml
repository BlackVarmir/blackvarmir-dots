import QtQuick

// Екран входу BlackVarmir (тема SDDM, Qt 6).
// SDDM передає в тему: sddm (вхід, живлення), userModel, sessionModel, keyboard, config.
// Перевірити без виходу з системи: sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/blackvarmir
Rectangle {
    id: root

    width: 1920
    height: 1080
    color: "#070708"

    readonly property color emerald: "#10b981"
    readonly property color cyan: "#22d3ee"
    readonly property color textColor: "#fafafa"
    readonly property color muted: "#a1a1aa"
    readonly property color subtle: "#71717a"
    readonly property color errorColor: "#ef4444"
    readonly property string font: config.font || "Geist"
    readonly property string mono: config.monoFont || "Geist Mono"

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool failed: false
    property bool busy: false

    // Англійська за замовчуванням; українська, лише якщо мова системи українська
    readonly property bool uk: Qt.locale().name.indexOf("uk") === 0
    function tr(en, ua) { return uk ? ua : en; }

    readonly property string userName: users.currentItem ? users.currentItem.login : ""

    function doLogin() {
        if (busy || password.text.length === 0) return;
        busy = true;
        failed = false;
        sddm.login(userName, password.text, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.failed = true;
            shake.restart();
            password.selectAll();
            password.forceActiveFocus();
        }
        function onLoginSucceeded() {
            root.busy = false;
        }
    }

    // ───────────── Фон ─────────────
    Image {
        anchors.fill: parent
        source: config.background ? Qt.resolvedUrl(config.background) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // Клік по фону закриває список сеансів
    MouseArea {
        anchors.fill: parent
        onClicked: { sessionMenu.visible = false; password.forceActiveFocus(); }
    }

    // ───────────── Хост ─────────────
    Row {
        x: 48
        y: 40
        spacing: 10
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: [16, 11, 6, 11, 16]
                Rectangle {
                    required property int modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: modelData
                    radius: 1.5
                    gradient: Gradient {
                        GradientStop { position: 0; color: root.emerald }
                        GradientStop { position: 1; color: root.cyan }
                    }
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: sddm.hostName
            color: root.muted
            font.family: root.mono
            font.pixelSize: 13
        }
    }

    // ───────────── Годинник ─────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.14
        spacing: 4

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.emerald
            font.family: root.mono
            font.pixelSize: 13
            font.letterSpacing: 1.6
        }
        Text {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.textColor
            font.family: root.font
            font.pixelSize: Math.min(200, root.height * 0.18)
            font.weight: Font.DemiBold
            font.letterSpacing: -6
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                const now = new Date();
                clockText.text = Qt.formatTime(now, "HH:mm");
                dateText.text = now.toLocaleDateString(Qt.locale(root.uk ? "uk_UA" : "en_US"), "dddd · d MMMM").toUpperCase();
            }
        }
    }

    // ───────────── Користувач і пароль ─────────────
    Column {
        id: form
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.54
        spacing: 16

        // Користувачі: поточний великий, інші менші й тьмяні (← → або клік)
        ListView {
            id: users
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.width - 200, count * 120)
            height: 124
            orientation: ListView.Horizontal
            interactive: false
            model: userModel
            currentIndex: root.userIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - 60
            preferredHighlightEnd: width / 2 + 60
            highlightMoveDuration: 250

            delegate: Item {
                id: userItem
                readonly property string login: model.name
                readonly property bool current: ListView.isCurrentItem
                width: 120
                height: 124
                opacity: current ? 1 : 0.5

                Rectangle {
                    id: avatar
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: userItem.current ? 0 : 18
                    width: userItem.current ? 84 : 52
                    height: width
                    radius: width / 2
                    clip: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.emerald }
                        GradientStop { position: 1; color: root.cyan }
                    }
                    Behavior on width { NumberAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        text: String(model.realName || model.name).split(" ").map(p => p.charAt(0)).join("").slice(0, 2).toUpperCase()
                        color: "#04130d"
                        font.family: root.font
                        font.pixelSize: avatar.width * 0.34
                        font.weight: Font.Bold
                    }
                    Image {
                        id: face
                        anchors.fill: parent
                        source: model.icon || ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: avatar.bottom
                    anchors.topMargin: 12
                    text: model.realName || model.name
                    color: userItem.current ? root.textColor : root.muted
                    font.family: root.font
                    font.pixelSize: userItem.current ? 20 : 13
                    font.weight: userItem.current ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.userIndex = index; password.forceActiveFocus(); }
                }
            }
        }

        // Поле пароля
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340
            height: 48
            radius: 24
            color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.6)
            border.width: 1
            border.color: root.failed ? root.errorColor : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.4)

            Rectangle {
                anchors.fill: parent
                anchors.margins: -5
                radius: height / 2
                color: "transparent"
                border.width: 4
                border.color: root.failed ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.15) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.12)
            }

            transform: Translate { id: shakeShift; x: 0 }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeShift; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: shakeShift; property: "x"; to: 10; duration: 50 }
                NumberAnimation { target: shakeShift; property: "x"; to: -8; duration: 50 }
                NumberAnimation { target: shakeShift; property: "x"; to: 8; duration: 50 }
                NumberAnimation { target: shakeShift; property: "x"; to: -4; duration: 50 }
                NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: 50 }
            }

            TextInput {
                id: password
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.right: submit.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: root.textColor
                selectionColor: Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.5)
                font.family: root.font
                font.pixelSize: 18
                font.letterSpacing: 2
                focus: true
                clip: true
                enabled: !root.busy
                onTextChanged: root.failed = false
                onAccepted: root.doLogin()
                Component.onCompleted: forceActiveFocus()

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left && password.text.length === 0) {
                        root.userIndex = Math.max(0, root.userIndex - 1); event.accepted = true;
                    } else if (event.key === Qt.Key_Right && password.text.length === 0) {
                        root.userIndex = Math.min(users.count - 1, root.userIndex + 1); event.accepted = true;
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: password.text.length === 0
                    text: root.tr("Password", "Пароль")
                    color: root.subtle
                    font.family: root.font
                    font.pixelSize: 16
                }
            }

            Rectangle {
                id: submit
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: 18
                opacity: root.busy ? 0.5 : 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.emerald }
                    GradientStop { position: 1; color: root.cyan }
                }
                Text {
                    anchors.centerIn: parent
                    text: "→"
                    color: "#04130d"
                    font.family: root.font
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogin()
                }
            }
        }

        // Повідомлення під полем: помилка або Caps Lock
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 18
            text: root.failed ? root.tr("Wrong password. Try again", "Невірний пароль. Спробуйте ще раз")
                : keyboard.capsLock ? root.tr("Caps Lock is on", "Увімкнено Caps Lock") : ""
            color: root.failed ? root.errorColor : root.muted
            font.family: root.font
            font.pixelSize: 13
        }

        // Вибір сеансу
        Rectangle {
            id: sessionButton
            anchors.horizontalCenter: parent.horizontalCenter
            width: sessionLabel.implicitWidth + 44
            height: 36
            radius: 10
            color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.55)
            border.width: 1
            border.color: sessionMenu.visible ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.4) : Qt.rgba(1, 1, 1, 0.1)

            Text {
                id: sessionLabel
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                text: (sessions.currentItem ? sessions.currentItem.sname : root.tr("Session", "Сеанс")) + "  ▾"
                color: "#d4d4d8"
                font.family: root.font
                font.pixelSize: 13
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sessionMenu.visible = !sessionMenu.visible
            }

            // Список сеансів (над кнопкою)
            Rectangle {
                id: sessionMenu
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 10
                width: 260
                height: Math.min(sessions.contentHeight, 280) + 12
                radius: 14
                color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.96)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                ListView {
                    id: sessions
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: sessionModel
                    currentIndex: root.sessionIndex

                    delegate: Rectangle {
                        readonly property string sname: model.name
                        width: ListView.view.width
                        height: 34
                        radius: 8
                        color: ListView.isCurrentItem ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.12)
                            : sessArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12
                            text: (parent.ListView.isCurrentItem ? "✓  " : "    ") + model.name
                            color: root.textColor
                            font.family: root.font
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: sessArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.sessionIndex = index;
                                sessionMenu.visible = false;
                                password.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }

    // ───────────── Розкладка ─────────────
    Rectangle {
        x: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        visible: keyboard.layouts.length > 1
        width: layoutText.implicitWidth + 24
        height: 36
        radius: 10
        color: Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)

        Text {
            id: layoutText
            anchors.centerIn: parent
            text: keyboard.layouts.length > 0 ? String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase() : ""
            color: "#d4d4d8"
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 1
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
    }

    // ───────────── Живлення ─────────────
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        spacing: 10

        Repeater {
            model: [
                { glyph: "", tip: root.tr("Sleep", "Сон"), ok: sddm.canSuspend, act: "suspend" },
                { glyph: "", tip: root.tr("Restart", "Перезавантажити"), ok: sddm.canReboot, act: "reboot" },
                { glyph: "", tip: root.tr("Shut down", "Вимкнути"), ok: sddm.canPowerOff, act: "poweroff" }
            ]

            Rectangle {
                id: powerButton
                required property var modelData
                visible: modelData.ok
                width: 44
                height: 44
                radius: 12
                color: powerArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(17 / 255, 17 / 255, 19 / 255, 0.55)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)

                Text {
                    anchors.centerIn: parent
                    text: powerButton.modelData.glyph
                    color: "#d4d4d8"
                    font.family: "GeistMono Nerd Font"
                    font.pixelSize: 16
                }
                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const a = powerButton.modelData.act;
                        if (a === "suspend") sddm.suspend();
                        else if (a === "reboot") sddm.reboot();
                        else sddm.powerOff();
                    }
                }
            }
        }
    }
}
