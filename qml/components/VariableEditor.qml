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

    // ── Dirty (Pending Save) and Saved Confirmation State ─────────────
    property bool isDirty: false
    property bool justSaved: false

    onValueChanged: {
        isDirty = false
        if (isNumType) {
            numField.text = formatForDisplay(root.value)
        } else if (!isBoolType) {
            textField.text = root.value
        }
    }

    Timer {
        id: savedTimer
        interval: 1800
        repeat: false
        onTriggered: root.justSaved = false
    }

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

    function saveCurrentValue() {
        if (root.readOnly) return;
        if (root.isNumType) {
            var safeVal = root.parseForStorage(numField.text);
            root.valueSaved(safeVal);
            numField.text = root.formatForDisplay(safeVal);
        } else if (!root.isBoolType) {
            root.valueSaved(textField.text);
        }
        root.isDirty = false;
        root.justSaved = true;
        savedTimer.restart();
    }

    implicitHeight: 46
    color: root.readOnly ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.02) : Qt.rgba(0, 0, 0, 0.02)) :
           (root.isDirty ? (Theme.isDark ? Qt.rgba(245/255, 158/255, 11/255, 0.10) : Qt.rgba(245/255, 158/255, 11/255, 0.07)) :
           (root.justSaved ? (Theme.isDark ? Qt.rgba(16/255, 185/255, 129/255, 0.10) : Qt.rgba(16/255, 185/255, 129/255, 0.07)) : Theme.panelBg))
    radius: 6
    border.color: root.isDirty ? Theme.warningColor : (root.justSaved ? Theme.successColor : Theme.borderColor)
    border.width: (root.isDirty || root.justSaved) ? 1.5 : 1.0

    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

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
            Layout.preferredWidth: 190
            elide: Text.ElideRight
        }

        Item { Layout.fillWidth: true }

        // ── Unsaved (Dirty) / Just Saved Status Indicator ───────────────
        Rectangle {
            visible: root.isDirty
            implicitHeight: 28
            implicitWidth: dirtyRow.implicitWidth + 14
            radius: 4
            color: Theme.isDark ? Qt.rgba(245/255, 158/255, 11/255, 0.25) : Qt.rgba(245/255, 158/255, 11/255, 0.18)
            border.color: Theme.warningColor
            border.width: 1

            RowLayout {
                id: dirtyRow
                anchors.centerIn: parent
                spacing: 5
                Text { text: "💾"; font.pixelSize: 12 }
                Label {
                    text: "Guardar (Enter ↵)"
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.warningColor
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.saveCurrentValue()
            }
        }

        Rectangle {
            visible: root.justSaved && !root.isDirty
            implicitHeight: 28
            implicitWidth: savedRow.implicitWidth + 14
            radius: 4
            color: Theme.isDark ? Qt.rgba(16/255, 185/255, 129/255, 0.25) : Qt.rgba(16/255, 185/255, 129/255, 0.18)
            border.color: Theme.successColor
            border.width: 1

            RowLayout {
                id: savedRow
                anchors.centerIn: parent
                spacing: 5
                Text { text: "✓"; font.pixelSize: 12; color: Theme.successColor; font.bold: true }
                Label {
                    text: "Guardado"
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.successColor
                }
            }
        }

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
                        root.justSaved = true
                        savedTimer.restart()
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
            Layout.preferredWidth: 150
            horizontalAlignment: Text.AlignRight
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            validator: DoubleValidator {
                locale: "es_AR"
                bottom: 0
                decimals: 4
                notation: DoubleValidator.StandardNotation
            }
            onTextEdited: {
                if (!root.readOnly) {
                    var curFmt = root.formatForDisplay(root.value)
                    root.isDirty = (numField.text !== curFmt)
                    root.justSaved = false
                }
            }
            onAccepted: root.saveCurrentValue()
            onEditingFinished: {
                if (root.isDirty) {
                    root.saveCurrentValue()
                }
            }
        }

        // 3. String / Fallback Text Control
        StyledTextField {
            id: textField
            visible: !root.isBoolType && !root.isNumType
            readOnly: root.readOnly
            text: root.value
            Layout.preferredWidth: 150
            onTextEdited: {
                if (!root.readOnly) {
                    root.isDirty = (textField.text !== root.value)
                    root.justSaved = false
                }
            }
            onAccepted: root.saveCurrentValue()
            onEditingFinished: {
                if (root.isDirty) {
                    root.saveCurrentValue()
                }
            }
        }
    }
}
