import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

TextField {
    id: control

    property real value: 0.0

    placeholderText: "$ 0.00"
    color: Theme.textColor
    horizontalAlignment: Text.AlignRight
    inputMethodHints: Qt.ImhFormattedNumbersOnly

    text: formatVal(value, "$ ")

    function formatVal(val, prefix) {
        if (val === undefined || val === null || isNaN(val)) return (prefix || "") + "0.00";
        var num = Number(val);
        var str = num.toFixed(4);
        if (str.indexOf(".") !== -1) {
            str = str.replace(/\.?0+$/, "");
            if (str.indexOf(".") !== -1) {
                var p = str.split(".");
                if (p[1].length < 2) p[1] = (p[1] + "00").substring(0, 2);
                str = p.join(".");
            }
        }
        return (prefix || "") + str;
    }

    background: Rectangle {
        color: Theme.inputBg
        radius: 6
        border.color: control.activeFocus ? Theme.accentColor : Theme.borderColor
        border.width: 1
    }

    validator: DoubleValidator {
        locale: "C"
        notation: DoubleValidator.StandardNotation
        decimals: 6
    }

    onEditingFinished: {
        var rawText = text.replace("$", "").trim()
        var val = parseFloat(rawText)
        if (!isNaN(val)) {
            value = val
            text = formatVal(val, "$ ")
        } else {
            text = formatVal(value, "$ ")
        }
    }
}
