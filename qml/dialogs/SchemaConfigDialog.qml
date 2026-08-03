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

    property int editingFieldId: -1

    onOpened: {
        editingFieldId = -1
        txtFieldCode.text = ""
        txtFieldLabel.text = ""
        refreshFieldsList()
    }

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
                    primaryText: (modelData.field_label || "") + " (" + (modelData.field_code || "") + ")"
                    secondaryText: "Tipo: " + (modelData.field_type || "number") + " | Valor por defecto: " + (modelData.default_value || "0")
                    showAdminActions: true
                    itemId: modelData.id
                    itemData: modelData

                    onDeleteRequested: function(id) {
                        AppController.removeSchemaField(id)
                        if (root.editingFieldId === id) {
                            root.editingFieldId = -1
                            txtFieldCode.text = ""
                            txtFieldLabel.text = ""
                        }
                        root.refreshFieldsList()
                    }
                    onEditRequested: function(data) {
                        root.editingFieldId = data.id || itemId
                        txtFieldCode.text = data.field_code || ""
                        txtFieldLabel.text = data.field_label || ""
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.borderColor
        }

        Label {
            text: root.editingFieldId > 0 ? "Editar Campo del Esquema:" : "Agregar Nuevo Campo al Esquema:"
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

            StyledComboBox {
                id: cbFieldType
                model: ["number", "bool", "string"]
                Layout.preferredWidth: 100
                visible: root.editingFieldId <= 0
            }

            StyledButton {
                variant: "primary"
                text: root.editingFieldId > 0 ? "Guardar" : "Agregar"
                onClicked: {
                    if (txtFieldCode.text.trim() !== "") {
                        if (root.editingFieldId > 0) {
                            AppController.renameSchemaField(root.editingFieldId, txtFieldCode.text.trim(), txtFieldLabel.text.trim())
                            root.editingFieldId = -1
                        } else {
                            AppController.addSchemaField(
                                root.esquemaCodigo,
                                txtFieldCode.text.trim(),
                                txtFieldLabel.text.trim(),
                                cbFieldType.currentText || "number",
                                "0",
                                100
                            )
                        }
                        txtFieldCode.text = ""
                        txtFieldLabel.text = ""
                        root.refreshFieldsList()
                    }
                }
            }

            StyledButton {
                variant: "secondary"
                text: "Cancelar"
                visible: root.editingFieldId > 0
                onClicked: {
                    root.editingFieldId = -1
                    txtFieldCode.text = ""
                    txtFieldLabel.text = ""
                }
            }
        }
    }
}
