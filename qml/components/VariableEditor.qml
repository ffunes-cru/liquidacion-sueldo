import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Rectangle {
    id: root

    property string fieldCode: ""
    property string fieldLabel: ""
    property string fieldType: "number"
    property string value: ""
    property bool readOnly: false
    signal valueSaved(string newValue)

    readonly property string typeNormalized: (fieldType || "number").toString().toLowerCase().trim()
    readonly property bool isBoolType: typeNormalized === "bool" || typeNormalized === "boolean"
    readonly property bool isNumType: typeNormalized === "number" || typeNormalized === "int" || typeNormalized === "float" || typeNormalized === "double" || typeNormalized === "num" || typeNormalized === "decimal"

    readonly property var arLocale: Qt.locale("es_AR")

    function formatForDisplay(strVal) {
        if (!strVal || strVal === "true" || strVal === "false" || strVal === "True" || strVal === "False") return "0";
        var num = Number(strVal);
        if (isNaN(num)) {
            num = Number.fromLocaleString(arLocale, strVal.toString());
        }
        if (isNaN(num)) return strVal;
        
        // Determine precision (max 4, min 0)
        var str = num.toString();
        var decCount = 0;
        if (str.indexOf('.') !== -1) {
            decCount = Math.min(4, str.split('.')[1].length);
        }
        return num.toLocaleString(arLocale, 'f', decCount);
    }

    function parseForStorage(strVal) {
        if (!strVal) return "0";
        var cleaned = strVal.toString().trim();
        // First try native locale parsing (1.234,56 -> 1234.56)
        var num = Number.fromLocaleString(arLocale, cleaned);
        if (isNaN(num)) {
            // Fallback for standard dot decimal
            num = parseFloat(cleaned.replace(",", "."));
        }
        return isNaN(num) ? "0" : num.toString();
    }

    implicitHeight: 44
    color: root.readOnly ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.02) : Qt.rgba(0, 0, 0, 0.02)) : Theme.panelBg
    radius: 6
    border.color: Theme.borderColor

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 12

        BadgePill {
            text: root.isBoolType ? "BOOL" : (root.isNumType ? "NUM" : "TXT")
            badgeColor: root.isBoolType ? Theme.warningColor : (root.isNumType ? Theme.accentColor : Theme.infoColor)
            fontSize: 10
            implicitWidth: 42
        }

        Label {
            text: root.fieldLabel + " (" + root.fieldCode + ")"
            font.pixelSize: 13
            font.bold: true
            color: root.readOnly ? Theme.subtextColor : Theme.textColor
            Layout.preferredWidth: 200
            elide: Text.ElideRight
        }

        Item { Layout.fillWidth: true }

        // 1. Boolean Switch Control
        RowLayout {
            visible: root.isBoolType
            spacing: 6

            Label {
                text: (root.value.toString().toLowerCase() === "true" || root.value === "1") ? "Sí" : "No"
                font.pixelSize: 12
                color: (root.value.toString().toLowerCase() === "true" || root.value === "1") ? Theme.successColor : Theme.subtextColor
            }

            Switch {
                enabled: !root.readOnly
                checked: root.value.toString().toLowerCase() === "true" || root.value === "1"
                onToggled: {
                    if (!root.readOnly) {
                        root.valueSaved(checked ? "true" : "false")
                    }
                }
            }
        }

        // 2. Numeric Input Control (Displays 1.234,56 using Qt native es_AR locale)
        StyledTextField {
            id: numField
            visible: root.isNumType
            readOnly: root.readOnly
            text: root.formatForDisplay(root.value)
            Layout.preferredWidth: 170
            horizontalAlignment: Text.AlignRight
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            validator: DoubleValidator {
                locale: "es_AR"
                bottom: 0
                decimals: 4
                notation: DoubleValidator.StandardNotation
            }
            onEditingFinished: {
                if (!root.readOnly) {
                    var safeVal = root.parseForStorage(text);
                    root.valueSaved(safeVal);
                    text = root.formatForDisplay(safeVal);
                }
            }
        }

        // 3. String / Fallback Text Control
        StyledTextField {
            visible: !root.isBoolType && !root.isNumType
            readOnly: root.readOnly
            text: root.value
            Layout.preferredWidth: 170
            onEditingFinished: {
                if (!root.readOnly) {
                    root.valueSaved(text)
                }
            }
        }
    }
}
