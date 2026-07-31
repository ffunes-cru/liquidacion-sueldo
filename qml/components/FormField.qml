import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: root

    property string label: ""
    property string type: "text"          // "text", "number", "combo", "checkbox", "formula"
    property alias value: loader.fieldValue
    property string placeholder: ""
    property var comboModel: []
    property int comboCurrentIndex: 0
    property string esquemaCodigo: ""     // Only for type === "formula"
    property bool readOnly: false

    // Access the internal control
    property alias control: loader.item

    Layout.fillWidth: true
    spacing: 15

    Label {
        text: root.label
        color: Theme.textColor
        font.pixelSize: 13
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: root.label !== "" ? implicitWidth : 0
        visible: root.label !== ""
    }

    Loader {
        id: loader
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter

        property string fieldValue: ""

        sourceComponent: {
            switch(root.type) {
                case "number":  return textComponent
                case "combo":   return comboComponent
                case "checkbox": return checkboxComponent
                case "formula": return formulaComponent
                default:        return textComponent
            }
        }
    }

    Component {
        id: textComponent
        StyledTextField {
            placeholderText: root.placeholder
            text: loader.fieldValue
            readOnly: root.readOnly
            inputMethodHints: root.type === "number" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
            onTextChanged: loader.fieldValue = text
        }
    }

    Component {
        id: comboComponent
        ComboBox {
            model: root.comboModel
            currentIndex: root.comboCurrentIndex
            onCurrentTextChanged: loader.fieldValue = currentText
            onCurrentIndexChanged: root.comboCurrentIndex = currentIndex
        }
    }

    Component {
        id: checkboxComponent
        CheckBox {
            text: root.placeholder
            checked: loader.fieldValue === "true" || loader.fieldValue === "1"
            onCheckedChanged: loader.fieldValue = checked ? "true" : "false"
        }
    }

    Component {
        id: formulaComponent
        FormulaInput {
            esquemaCodigo: root.esquemaCodigo
            placeholderText: root.placeholder
            text: loader.fieldValue
            onTextChanged: loader.fieldValue = text
        }
    }
}
