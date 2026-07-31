import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Dialog {
    id: root

    property int catId: -1
    property alias nombre: txtNombre.text
    property alias valorHora: txtValorHora.text

    signal categorySaved()

    title: catId > 0 ? "Editar Categoría #" + catId : "Nueva Categoría Jornalera"
    modal: true
    anchors.centerIn: parent
    width: 420
    implicitHeight: 280
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
        var val = parseFloat(txtValorHora.text) || 0.0
        if (txtNombre.text.trim() !== "") {
            AppController.categoryModel.saveCategory(
                catId > 0 ? catId : 0,
                txtNombre.text.trim(),
                val
            )
            categorySaved()
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

            Label { text: "Nombre:"; color: window.textColor; font.pixelSize: 13 }
            TextField {
                id: txtNombre
                placeholderText: "Ej: Maestranza A Jornal"
                Layout.fillWidth: true
                color: window.textColor
                background: Rectangle {
                    color: window.inputBg
                    radius: 6
                    border.color: parent.activeFocus ? window.accentColor : window.borderColor
                }
            }

            Label { text: "Valor por Hora ($):"; color: window.textColor; font.pixelSize: 13 }
            TextField {
                id: txtValorHora
                placeholderText: "5540.61"
                Layout.fillWidth: true
                color: window.textColor
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: Rectangle {
                    color: window.inputBg
                    radius: 6
                    border.color: parent.activeFocus ? window.accentColor : window.borderColor
                }
            }
        }
    }
}
