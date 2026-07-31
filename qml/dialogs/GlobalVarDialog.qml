import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Dialog {
    id: root

    property int varId: -1
    property alias code: txtCode.text
    property alias value: txtValue.text
    property alias description: txtDescription.text

    signal variableSaved()

    title: varId > 0 ? "Editar Variable Global #" + varId : "Nueva Variable Global"
    modal: true
    anchors.centerIn: parent
    width: 460
    implicitHeight: 320
    standardButtons: Dialog.Save | Dialog.Cancel

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    background: Rectangle {
        color: window.panelBg
        radius: 10
        border.color: window.borderColor
        border.width: 1
    }

    enter: Transition {
        NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: 200; easing.type: Easing.OutBack }
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 180 }
    }
    exit: Transition {
        NumberAnimation { property: "scale"; from: 1.0; to: 0.85; duration: 150; easing.type: Easing.InQuad }
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150 }
    }

    onAccepted: {
        if (txtCode.text.trim() !== "") {
            AppController.globalVarsModel.saveVariable(
                varId > 0 ? varId : 0,
                txtCode.text.trim(),
                txtValue.text.trim(),
                txtDescription.text.trim()
            )
            variableSaved()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 15

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 15
            columnSpacing: 15

            Label { text: "Código de Variable:"; color: window.textColor; font.pixelSize: 13 }
            TextField {
                id: txtCode
                placeholderText: "Ej: TOPE_JUBILATORIO"
                Layout.fillWidth: true
                color: window.textColor
                background: Rectangle {
                    color: window.inputBg
                    radius: 6
                    border.color: parent.activeFocus ? window.accentColor : window.borderColor
                }
            }

            Label { text: "Valor:"; color: window.textColor; font.pixelSize: 13 }
            TextField {
                id: txtValue
                placeholderText: "Ej: 150000.00"
                Layout.fillWidth: true
                color: window.textColor
                background: Rectangle {
                    color: window.inputBg
                    radius: 6
                    border.color: parent.activeFocus ? window.accentColor : window.borderColor
                }
            }

            Label { text: "Descripción:"; color: window.textColor; font.pixelSize: 13 }
            TextField {
                id: txtDescription
                placeholderText: "Descripción o tope de base imponible..."
                Layout.fillWidth: true
                color: window.textColor
                background: Rectangle {
                    color: window.inputBg
                    radius: 6
                    border.color: parent.activeFocus ? window.accentColor : window.borderColor
                }
            }
        }
    }
}
