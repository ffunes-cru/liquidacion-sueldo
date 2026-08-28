import QtQuick 2.15
import QtQuick.Controls 2.15

SpinBox {
    id: control

    font.pixelSize: 13
    implicitHeight: 36
    implicitWidth: 140

    textFromValue: function(value, locale) {
        return Number(value).toString()
    }
    valueFromText: function(text, locale) {
        return parseInt(text) || 0
    }

    contentItem: TextInput {
        text: control.textFromValue(control.value, control.locale)
        font: control.font
        color: Theme.textColor
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhDigitsOnly
    }

    up.indicator: Rectangle {
        x: control.mirrored ? 0 : parent.width - width
        height: parent.height
        implicitWidth: 32
        implicitHeight: 36
        radius: 6
        color: control.up.pressed ? Theme.hoverBg : (control.up.hovered ? Theme.cardBg : Theme.inputBg)
        border.color: Theme.borderColor
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            text: "+"
            font.pixelSize: 15
            font.bold: true
            color: Theme.textColor
            anchors.centerIn: parent
        }
    }

    down.indicator: Rectangle {
        x: control.mirrored ? parent.width - width : 0
        height: parent.height
        implicitWidth: 32
        implicitHeight: 36
        radius: 6
        color: control.down.pressed ? Theme.hoverBg : (control.down.hovered ? Theme.cardBg : Theme.inputBg)
        border.color: Theme.borderColor
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            text: "−"
            font.pixelSize: 15
            font.bold: true
            color: Theme.textColor
            anchors.centerIn: parent
        }
    }

    background: Rectangle {
        implicitWidth: 140
        implicitHeight: 36
        radius: 6
        color: Theme.inputBg
        border.color: control.activeFocus ? Theme.accentColor : Theme.borderColor
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
}
