import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Користувач: аватар (~/.face.icon + екран входу), повне ім'я, пароль.
SetPage {
    id: page

    title: Tr.t("set.user")
    subtitle: Tr.t("user.subtitle")

    property string error: ""
    property string nameDraft: Sys.realName

    RootAction {
        id: avatarAction
        onFinished: ok => page.error = ok ? "" : Tr.t("user.avatarLoginFailed")
    }
    RootAction {
        id: nameAction
        onFinished: ok => { page.error = ok ? "" : Tr.t("set.rootFailed"); Sys.refresh(); }
    }

    // Вибрати фото: zenity → ~/.face.icon, потім копія для екрана входу (pkexec)
    Process {
        id: picker
        command: ["sh", "-c",
            "f=$(zenity --file-selection --title=\"" + Tr.t("user.pickTitle") + "\" --file-filter='*.png *.jpg *.jpeg *.webp') || exit 1; " +
            "cp \"$f\" \"$HOME/.face.icon\" && echo ok"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "ok") return;
                Sys.avatarRev += 1;
                avatarAction.run(["avatar", Sys.avatarPath]);
            }
        }
    }

    Text {
        visible: page.error.length > 0
        text: page.error
        color: Theme.error
        font.family: Theme.font
        font.pixelSize: 13
    }

    SetCard {
        label: Tr.t("user.eyebrow")

        SetRow {
            divider: false
            label: Tr.t("user.avatar")
            hint: Tr.t("user.avatarHint")
            RowLayout {
                spacing: 16
                Avatar { size: 64 }
                VButton { variant: "secondary"; text: Tr.t("user.pick"); onClicked: picker.running = true }
            }
        }

        SetRow {
            label: Tr.t("user.realName")
            RowLayout {
                spacing: 8
                Rectangle {
                    implicitWidth: 220
                    implicitHeight: 36
                    radius: 8
                    color: Theme.inset
                    border.width: 1
                    border.color: nameInput.activeFocus ? Theme.accentBorder : Theme.hairline
                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        text: page.nameDraft
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 14
                        maximumLength: 64
                        onTextEdited: page.nameDraft = text
                        onAccepted: saveName.clicked()
                    }
                }
                VButton {
                    id: saveName
                    variant: "secondary"
                    text: Tr.t("common.save")
                    visible: page.nameDraft.trim() !== Sys.realName && page.nameDraft.trim().length > 0
                    onClicked: nameAction.run(["realname", page.nameDraft.trim()])
                }
            }
        }

        SetRow {
            label: Tr.t("user.account")
            Text {
                text: Quickshell.env("USER") || ""
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: 13
            }
        }

        SetRow {
            label: Tr.t("user.password")
            hint: Tr.t("user.passwordHint")
            VButton {
                variant: "ghost"
                text: Tr.t("user.change")
                onClicked: Quickshell.execDetached(["kitty", "--class", "kitty-float", "-e", "passwd"])
            }
        }
    }
}
