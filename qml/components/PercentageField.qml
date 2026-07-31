import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
    id: control

    property real value: 0.0

    placeholderText: "% 0.00"
    color: Theme.textColor
    horizontalAlignment: Text.AlignRight
    inputMethodHints: Qt.ImhFormattedNumbersOnly

    text: Number(value).toFixed(2) + " %"

    background: Rectangle {
        color: Theme.inputBg
        radius: 6
        border.color: control.activeFocus ? Theme.accentColor : Theme.borderColor
        border.width: 1
    }

    validator: DoubleValidator {
        locale: "C"
        bottom: 0.0
        top: 100.0
        notation: DoubleValidator.StandardNotation
    }

    onEditingFinished: {
        var rawText = text.replace("%", "").trim()
        var val = parseFloat(rawText)
        if (!isNaN(val)) {
            value = val
            text = Number(val).toFixed(2) + " %"
        } else {
            text = Number(value).toFixed(2) + " %"
        }
    }
}
