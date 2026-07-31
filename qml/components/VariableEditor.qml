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
    signal valueSaved(string newValue)

    readonly property string typeNormalized: (fieldType || "number").toString().toLowerCase().trim()
    readonly property bool isBoolType: typeNormalized === "bool" || typeNormalized === "boolean"
    readonly property bool isNumType: typeNormalized === "number" || typeNormalized === "int" || typeNormalized === "float" || typeNormalized === "double" || typeNormalized === "num" || typeNormalized === "decimal"

    function getSafeNumString(strVal) {
        if (strVal === "true" || strVal === "false" || strVal === "True" || strVal === "False") return "0";
        var parsed = parseFloat(strVal);
        return isNaN(parsed) ? "0" : parsed.toString();
    }

    implicitHeight: 44
    color: Theme.panelBg
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
            color: Theme.textColor
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
                checked: root.value.toString().toLowerCase() === "true" || root.value === "1"
                onToggled: {
                    root.valueSaved(checked ? "true" : "false")
                }
            }
        }

        // 2. Numeric Input Control (No text allowed)
        StyledTextField {
            id: numField
            visible: root.isNumType
            text: root.getSafeNumString(root.value)
            Layout.preferredWidth: 170
            horizontalAlignment: Text.AlignRight
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            validator: DoubleValidator { bottom: 0; decimals: 4; notation: DoubleValidator.StandardNotation }
            onEditingFinished: {
                var parsed = parseFloat(text || "0");
                var safeVal = isNaN(parsed) ? "0" : parsed.toString();
                root.valueSaved(safeVal);
            }
        }

        // 3. String / Fallback Text Control
        StyledTextField {
            visible: !root.isBoolType && !root.isNumType
            text: root.value
            Layout.preferredWidth: 170
            onEditingFinished: {
                root.valueSaved(text)
            }
        }
    }
}
