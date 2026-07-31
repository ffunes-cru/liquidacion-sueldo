import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

MasterDetailView {
    id: root

    masterWidth: 380
    masterTitle: "Esquemas de Cálculo"
    masterCountSuffix: "esq."
    masterModel: AppController.schemaModel

    property string selectedSchemaCode: ""
    property var schemaFieldsList: []

    function loadSchema(code, name, tipo) {
        var c = code || ""
        var n = name || ""
        var t = tipo || "mensual"
        selectedSchemaCode = c
        txtCode.value = c
        txtName.value = n
        cbTipoLiq.value = (t === "jornal") ? "Jornalero" : "Mensual"
        refreshSchemaFields()
    }

    function clearForm() {
        selectedSchemaCode = ""
        txtCode.value = ""
        txtName.value = ""
        cbTipoLiq.value = "Mensual"
        schemaFieldsList = []
    }

    function refreshSchemaFields() {
        if (selectedSchemaCode !== "") {
            schemaFieldsList = AppController.listSchemaFields(selectedSchemaCode)
        } else {
            schemaFieldsList = []
        }
    }

    // ── Master Delegate ──────────────────────────────────────────
    masterDelegate: Component {
        CrudDelegate {
            height: 52

            primaryText: model.code || model.codigo || ""
            secondaryText: model.name || model.nombre || ""
            valueText: ""
            showAdminActions: false

            middleContent: Component {
                BadgePill {
                    text: (model.tipoLiquidacion || model.tipo_liquidacion) === "jornal" ? "Jornal" : "Mensual"
                    badgeColor: (model.tipoLiquidacion || model.tipo_liquidacion) === "jornal" ? Theme.warningColor : Theme.infoColor
                    fontSize: 11
                }
            }

            // Override to highlight selected
            color: root.selectedSchemaCode === (model.code || model.codigo) ? Theme.selectedBg :
                   (mouseArea.containsMouse ? Theme.hoverBg : Theme.cardBg)
            border.color: root.selectedSchemaCode === (model.code || model.codigo) ? Theme.accentColor : Theme.borderColor

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.loadSchema(model.code || model.codigo, model.name || model.nombre, model.tipoLiquidacion || model.tipo_liquidacion)
            }
        }
    }

    // ── Master Footer ────────────────────────────────────────────
    masterFooter: RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Button {
            Layout.fillWidth: true
            text: "Nuevo Esquema"
            onClicked: {
                root.clearForm()
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Eliminar"
            enabled: root.selectedSchemaCode !== "" && root.selectedSchemaCode !== "MENSUAL"
            onClicked: {
                if (root.selectedSchemaCode !== "") {
                    AppController.schemaModel.removeSchema(root.selectedSchemaCode)
                    root.clearForm()
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // DETAIL CONTENT (Right Panel)
    // ══════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: 15

        Label {
            text: root.selectedSchemaCode !== ""
                  ? "Configurar Esquema: " + root.selectedSchemaCode
                  : "Nuevo Esquema de Cálculo"
            font.pixelSize: 18
            font.bold: true
            color: Theme.textColor
        }

        // ── Schema Basic Fields ─────────────────────────────────
        SectionPanel {
            padding: 12

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 12
                columnSpacing: 15

                Label { text: "Código:"; color: Theme.textColor; font.pixelSize: 13 }
                StyledTextField {
                    id: _txtCode
                    placeholderText: "Ej: COMERCIO"
                    Layout.fillWidth: true
                    text: txtCode.value
                    onTextChanged: txtCode.value = text
                }

                Label { text: "Nombre Descriptivo:"; color: Theme.textColor; font.pixelSize: 13 }
                StyledTextField {
                    id: _txtName
                    placeholderText: "Ej: Comercio CCT 130/75"
                    Layout.fillWidth: true
                    text: txtName.value
                    onTextChanged: txtName.value = text
                }

                Label { text: "Tipo Liquidación:"; color: Theme.textColor; font.pixelSize: 13 }
                ComboBox {
                    id: _cbTipoLiq
                    Layout.fillWidth: true
                    model: ["Mensual", "Jornalero"]
                    currentIndex: cbTipoLiq.value === "Jornalero" ? 1 : 0
                    onCurrentTextChanged: cbTipoLiq.value = currentText
                }

                Item { Layout.columnSpan: 2 }
            }
        }

        // Hidden state holders for FormField-like binding
        QtObject {
            id: txtCode
            property string value: ""
        }
        QtObject {
            id: txtName
            property string value: ""
        }
        QtObject {
            id: cbTipoLiq
            property string value: "Mensual"
        }

        // ── Input Fields Model (schema_fields) ─────────────────
        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Modelo de Variables de Entrada:"
                font.pixelSize: 14
                font.bold: true
                color: Theme.accentColor
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Agregar Variable"
                enabled: root.selectedSchemaCode !== ""
                onClicked: addFieldDialog.open()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.cardBg
            radius: 6
            border.color: Theme.borderColor

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true

                ListView {
                    id: fieldsListView
                    model: root.schemaFieldsList
                    spacing: 6

                    delegate: CrudDelegate {
                        height: 44
                        primaryText: modelData.field_label + " (" + modelData.field_code + ")"
                        secondaryText: "Tipo: " + modelData.field_type + " | Default: " + modelData.default_value
                        showAdminActions: true
                        showDuplicate: false
                        itemId: modelData.id

                        onDeleteRequested: function(id) {
                            AppController.removeSchemaField(id)
                            root.refreshSchemaFields()
                        }
                        onEditRequested: function(data) { /* not editable inline */ }
                    }
                }
            }
        }

        // ── Save Button ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            Button {
                text: "Guardar Esquema"
                highlighted: true
                onClicked: {
                    if (txtCode.value.trim() !== "" && txtName.value.trim() !== "") {
                        AppController.schemaModel.saveSchema(
                            root.selectedSchemaCode,
                            txtCode.value.trim().toUpperCase(),
                            txtName.value.trim(),
                            _cbTipoLiq.currentIndex === 1 ? "jornal" : "mensual"
                        )
                        root.clearForm()
                    }
                }
            }
        }
    }

    // ── Dialog to add field ───────────────────────────────────────
    FormDialog {
        id: addFieldDialog
        entityName: "Variable de Esquema"
        dialogWidth: 420

        formFields: [
            { key: "field_code",    label: "Código Variable:", placeholder: "Ej: horas_extras_50", type: "text" },
            { key: "field_label",   label: "Etiqueta:",        placeholder: "Ej: Horas Extras 50%", type: "text" },
            { key: "field_type",    label: "Tipo de Dato:",    type: "combo", comboModel: ["number", "bool", "string"] },
            { key: "default_value", label: "Valor por Defecto:", placeholder: "0", type: "text" }
        ]

        onFormAccepted: function(values) {
            if (values.field_code.trim() !== "" && values.field_label.trim() !== "") {
                AppController.addSchemaField(
                    root.selectedSchemaCode,
                    values.field_code.trim().toLowerCase(),
                    values.field_label.trim(),
                    values.field_type || "number",
                    values.default_value.trim() || "0",
                    10
                )
                root.refreshSchemaFields()
            }
        }
    }
}
