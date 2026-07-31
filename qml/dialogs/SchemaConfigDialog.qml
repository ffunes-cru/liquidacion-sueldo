import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

AppDialog {
    id: root

    property string esquemaCodigo: "MENSUAL"

    title: "Configurar Esquema de Cálculo: " + esquemaCodigo
    dialogWidth: 600
    dialogHeight: 500
    standardButtons: Dialog.Close

    onOpened: refreshFieldsList()

    function refreshFieldsList() {
        fieldsListView.model = AppController.listSchemaFields(root.esquemaCodigo)
    }

    contentItem: ColumnLayout {
        spacing: 12

        Label {
            text: "Campos de Entrada requeridos para empleados de este Esquema:"
            font.bold: true
            color: Theme.textColor
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: fieldsListView
                spacing: 6

                delegate: CrudDelegate {
                    height: 48
                    primaryText: modelData.field_label + " (" + modelData.field_code + ")"
                    secondaryText: "Tipo: " + modelData.field_type + " | Valor por defecto: " + modelData.default_value
                    showAdminActions: true
                    itemId: modelData.id

                    onDeleteRequested: function(id) {
                        AppController.removeSchemaField(id)
                        root.refreshFieldsList()
                    }
                    onEditRequested: function(data) { /* read-only */ }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.borderColor
        }

        Label {
            text: "Agregar Nuevo Campo al Esquema:"
            font.bold: true
            color: Theme.accentColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledTextField {
                id: txtFieldCode
                placeholderText: "Cód (ej: inasistencias)"
                Layout.preferredWidth: 140
            }

            StyledTextField {
                id: txtFieldLabel
                placeholderText: "Etiqueta (ej: Inasistencias)"
                Layout.fillWidth: true
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
