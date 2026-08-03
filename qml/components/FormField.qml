import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: root

    property string label: ""
    property string type: "text"          // "text", "number", "combo", "checkbox", "formula", "date"
    property alias value: loader.fieldValue
    property string placeholder: ""
    property var comboModel: []
    property int comboCurrentIndex: 0
    property string esquemaCodigo: ""     // Only for type === "formula"
    property bool readOnly: false

    signal userFieldValueChanged(var newValue)

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
        onFieldValueChanged: root.userFieldValueChanged(fieldValue)

        sourceComponent: {
            switch(root.type) {
                case "number":   return textComponent
                case "combo":    return comboComponent
                case "checkbox": return checkboxComponent
                case "formula":  return formulaComponent
                case "date":     return dateComponent
                default:         return textComponent
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
        id: dateComponent
        RowLayout {
            spacing: 6
            StyledTextField {
                Layout.fillWidth: true
                placeholderText: root.placeholder !== "" ? root.placeholder : "AAAA-MM-DD"
                text: loader.fieldValue
                readOnly: root.readOnly
                inputMethodHints: Qt.ImhDate
                onTextChanged: loader.fieldValue = text
            }
            Button {
                text: "📅 Hoy"
                flat: true
                onClicked: loader.fieldValue = Qt.formatDate(new Date(), "yyyy-MM-dd")
            }
        }
    }

    Component {
        id: comboComponent
        StyledComboBox {
            model: root.comboModel
            textRole: (model && model.length > 0 && typeof model[0] === "object" && model[0].text !== undefined) ? "text" : ""
            currentIndex: root.comboCurrentIndex

            Connections {
                target: loader
                function onFieldValueChanged() {
                    if (!root.comboModel || root.comboModel.length === 0) return;
                    for (var i = 0; i < root.comboModel.length; i++) {
                        var item = root.comboModel[i];
                        var valToMatch = "";
                        if (typeof item === "object") {
                            valToMatch = (item.id !== undefined) ? item.id.toString() : ((item.value !== undefined) ? item.value.toString() : (item.text !== undefined ? item.text.toString() : ""));
                        } else {
                            valToMatch = item.toString();
                        }
                        if (valToMatch === loader.fieldValue.toString()) {
                            root.comboCurrentIndex = i;
                            break;
                        }
                    }
                }
            }

            onCurrentIndexChanged: {
                root.comboCurrentIndex = currentIndex
                if (model && model[currentIndex] !== undefined) {
                    if (typeof model[currentIndex] === "object" && model[currentIndex].id !== undefined) {
                        loader.fieldValue = model[currentIndex].id.toString()
                    } else if (typeof model[currentIndex] === "object" && model[currentIndex].value !== undefined) {
                        loader.fieldValue = model[currentIndex].value.toString()
                    } else {
                        loader.fieldValue = currentText
                    }
                }
            }
            onCurrentTextChanged: {
                if (!model || model.length === 0 || typeof model[0] !== "object") {
                    loader.fieldValue = currentText
                }
            }
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
