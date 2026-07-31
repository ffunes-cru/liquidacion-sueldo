import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
    id: control

    color: Theme.textColor
    placeholderTextColor: Qt.alpha(Theme.subtextColor, 0.6)
    selectionColor: Qt.alpha(Theme.accentColor, 0.4)
    selectedTextColor: Theme.textColor
    font.pixelSize: 13

    background: Rectangle {
        color: Theme.inputBg
        radius: 6
        border.color: control.activeFocus ? Theme.accentColor : Theme.borderColor
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
    }
}
