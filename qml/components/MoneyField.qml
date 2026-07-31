import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

TextField {
    id: control

    property real value: 0.0

    placeholderText: "$ 0.00"
    color: window.textColor
    horizontalAlignment: Text.AlignRight
    inputMethodHints: Qt.ImhFormattedNumbersOnly

    text: "$ " + Number(value).toFixed(2)

    background: Rectangle {
        color: window.inputBg
        radius: 6
        border.color: control.activeFocus ? window.accentColor : window.borderColor
        border.width: 1
    }

    validator: DoubleValidator {
        locale: "C"
        notation: DoubleValidator.StandardNotation
    }

    onEditingFinished: {
        var rawText = text.replace("$", "").trim()
        var val = parseFloat(rawText)
        if (!isNaN(val)) {
            value = val
            text = "$ " + Number(val).toFixed(2)
        } else {
            text = "$ " + Number(value).toFixed(2)
        }
    }
}
