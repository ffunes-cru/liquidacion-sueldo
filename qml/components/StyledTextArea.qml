import QtQuick 2.15
import QtQuick.Controls 2.15

ScrollView {
    id: root

    property alias text: textArea.text
    property alias placeholderText: textArea.placeholderText
    property alias readOnly: textArea.readOnly
    property alias textFont: textArea.font
    property alias wrapMode: textArea.wrapMode
    property alias textArea: textArea

    clip: true

    TextArea {
        id: textArea
        font.pixelSize: 13
        font.family: "Monospace"
        color: Theme.textColor
        placeholderTextColor: Theme.subtextColor
        selectByMouse: true
        padding: 10

        background: Rectangle {
            color: Theme.inputBg
            border.color: textArea.activeFocus ? Theme.accentColor : Theme.borderColor
            border.width: 1
            radius: 6

            Behavior on border.color { ColorAnimation { duration: 150 } }
        }
    }
}
