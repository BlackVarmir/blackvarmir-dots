import QtQuick
import QtQuick.Layouts

// Сторінка налаштувань: заголовок, підзаголовок і прокручуваний вміст.
Flickable {
    id: page

    property string title: ""
    property string subtitle: ""
    default property alias content: body.data

    clip: true
    contentHeight: column.implicitHeight + 64
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        x: 40
        y: 32
        width: page.width - 80
        spacing: 20

        ColumnLayout {
            spacing: 4
            Text {
                text: page.title
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 26
                font.weight: Font.Bold
                font.letterSpacing: -0.5
            }
            Text {
                visible: page.subtitle.length > 0
                text: page.subtitle
                color: Theme.textMuted
                font.family: Theme.font
                font.pixelSize: 14
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 20
        }
    }
}
