import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Dialog {
    id: root

    property string esquemaCodigo: "MENSUAL"

    title: "Configurar Esquema de Cálculo: " + esquemaCodigo
    modal: true
    anchors.centerIn: parent
    width: 600
    height: 500
    standardButtons: Dialog.Close

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

    onOpened: {
        refreshFieldsList()
    }

    function refreshFieldsList() {
        fieldsListView.model = AppController.listSchemaFields(root.esquemaCodigo)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            text: "Campos de Entrada requeridos para empleados de este Esquema:"
            font.bold: true
            color: window.textColor
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: fieldsListView
                spacing: 6

                delegate: Rectangle {
                    width: fieldsListView.width
                    height: 48
                    radius: 6
                    color: window.cardBg
                    border.color: window.borderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Label {
                                text: modelData.field_label + " (" + modelData.field_code + ")"
                                font.bold: true
                                font.pixelSize: 13
                                color: window.textColor
                            }

                            Label {
                                text: "Tipo: " + modelData.field_type + " | Valor por defecto: " + modelData.default_value
                                font.pixelSize: 11
                                color: window.subtextColor
                            }
                        }

                        Button {
                            text: "Eliminar"
                            visible: AppController.currentRole === "admin"
                            onClicked: {
                                AppController.removeSchemaField(modelData.id)
                                root.refreshFieldsList()
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: window.borderColor
        }

        Label {
            text: "Agregar Nuevo Campo al Esquema:"
            font.bold: true
            color: window.accentColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: txtFieldCode
                placeholderText: "Cód (ej: inasistencias)"
                Layout.preferredWidth: 140
                color: window.textColor
                background: Rectangle {
                    color: window.inputBg
                    radius: 6
                    border.color: parent.activeFocus ? window.accentColor : window.borderColor
                }
            }

            TextField {
                id: txtFieldLabel
                placeholderText: "Etiqueta (ej: Inasistencias Injustificadas)"
                Layout.fillWidth: true
                color: window.textColor
                background: Rectangle {
                    color: window.inputBg
                    radius: 6
                    border.color: parent.activeFocus ? window.accentColor : window.borderColor
                }
            }

            ComboBox {
                id: cbFieldType
                model: ["number", "bool", "string"]
                Layout.preferredWidth: 90
            }

            Button {
                text: "Agregar"
                highlighted: true
                onClicked: {
                    if (txtFieldCode.text.trim() !== "") {
                        AppController.addSchemaField(
                            root.esquemaCodigo,
                            txtFieldCode.text.trim(),
                            txtFieldLabel.text.trim(),
                            cbFieldType.currentText,
                            "0",
                            100
                        )
                        txtFieldCode.text = ""
                        txtFieldLabel.text = ""
                        root.refreshFieldsList()
                    }
                }
            }
        }
    }
}
