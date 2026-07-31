import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

AppDialog {
    id: root

    property int itemId: -1

    // Declarative form model: array of field descriptors
    // Each: { key: "fieldName", label: "Label:", type: "text"|"number"|"combo"|"checkbox"|"formula",
    //          placeholder: "...", comboModel: [...], esquemaCodigo: "...", defaultValue: "..." }
    property var formFields: []

    // Custom content below the generated form (for complex cases)
    property alias extraContent: extraContentContainer.data

    // Title auto-generation
    property string entityName: ""
    title: {
        if (entityName !== "")
            return itemId > 0 ? ("Editar " + entityName + " #" + itemId) : ("Nuevo/a " + entityName)
        return itemId > 0 ? ("Editar #" + itemId) : "Nuevo Registro"
    }

    standardButtons: Dialog.Save | Dialog.Cancel

    signal formAccepted(var values)
    signal fieldValueChanged(string key, var value)

    // Helper to dynamically update a field's combo model
    function setComboModel(key, newModel) {
        if (!formFields) return
        for (var i = 0; i < formFields.length; i++) {
            if (formFields[i].key === key) {
                var repeaterItem = fieldRepeater.itemAt(i)
                if (repeaterItem) {
                    repeaterItem.comboModel = newModel
                    if (repeaterItem.comboCurrentIndex >= newModel.length) {
                        repeaterItem.comboCurrentIndex = 0
                    }
                }
                break
            }
        }
    }

    // Helper to dynamically toggle a field's visibility
    function setFieldVisible(key, isVisible) {
        if (!formFields) return
        for (var i = 0; i < formFields.length; i++) {
            if (formFields[i].key === key) {
                var repeaterItem = fieldRepeater.itemAt(i)
                if (repeaterItem) {
                    repeaterItem.visible = isVisible
                }
                break
            }
        }
    }

    // Collect all field values into an object and emit
    onAccepted: {
        var values = {}
        for (var i = 0; i < formFields.length; i++) {
            var field = formFields[i]
            var repeaterItem = fieldRepeater.itemAt(i)
            if (repeaterItem) {
                values[field.key] = repeaterItem.value
            }
        }
        root.formAccepted(values)
    }

    // Populate fields when dialog opens
    onOpened: {
        for (var i = 0; i < formFields.length; i++) {
            var field = formFields[i]
            var repeaterItem = fieldRepeater.itemAt(i)
            if (repeaterItem && field.defaultValue !== undefined) {
                repeaterItem.value = field.defaultValue.toString()
            }
        }
    }

    // Helper to set values programmatically (for edit mode)
    function setFieldValues(values) {
        if (!formFields || !values) return
        for (var i = 0; i < formFields.length; i++) {
            var field = formFields[i]
            var repeaterItem = fieldRepeater.itemAt(i)
            if (repeaterItem) {
                var val = values[field.key]
                if (val === undefined) {
                    if (field.key === "nombre" && values["nombre_completo"] !== undefined) val = values["nombre_completo"]
                    else if (field.key === "tipoLiq" && (values["tipoLiquidacion"] !== undefined || values["tipo_liquidacion"] !== undefined)) val = values["tipoLiquidacion"] || values["tipo_liquidacion"]
                    else if (field.key === "esquema" && (values["esquema_codigo"] !== undefined || values["esquema"] !== undefined)) val = values["esquema_codigo"] || values["esquema"]
                    else if (field.key === "categoriaId" && (values["categoria_jornal_id"] !== undefined || values["categoriaId"] !== undefined)) val = values["categoria_jornal_id"] || values["categoriaId"]
                    else if (field.key === "fechaIngreso" && (values["fecha_ingreso"] !== undefined || values["fechaIngreso"] !== undefined)) val = values["fecha_ingreso"] || values["fechaIngreso"]
                }
                if (val !== undefined) {
                    repeaterItem.value = val.toString()
                }
            }
        }
    }

    // Helper to clear all fields (for new mode)
    function openNew() {
        itemId = -1
        if (!formFields) return
        for (var i = 0; i < formFields.length; i++) {
            var field = formFields[i]
            var repeaterItem = fieldRepeater.itemAt(i)
            if (repeaterItem) {
                repeaterItem.value = (field.defaultValue !== undefined) ? field.defaultValue.toString() : ""
            }
        }
        open()
    }

    // Helper to open in edit mode with data
    function openEdit(data) {
        if (!data) return
        if (data.id !== undefined && data.id > 0) itemId = data.id
        else if (data.itemId !== undefined && data.itemId > 0) itemId = data.itemId
        else if (data.employeeId !== undefined && data.employeeId > 0) itemId = data.employeeId
        else if (data.catId !== undefined && data.catId > 0) itemId = data.catId
        else if (data.varId !== undefined && data.varId > 0) itemId = data.varId
        else if (data.cellId !== undefined && data.cellId > 0) itemId = data.cellId
        else if (data.receiptId !== undefined && data.receiptId > 0) itemId = data.receiptId
        else itemId = -1

        setFieldValues(data)
        open()
    }

    contentItem: ScrollView {
        id: scrollView
        clip: true

        ColumnLayout {
            width: scrollView.availableWidth > 0 ? scrollView.availableWidth : root.width - 40
            spacing: 12

            // Auto-generated form fields
            Repeater {
                id: fieldRepeater
                model: root.formFields

                FormField {
                    Layout.fillWidth: true
                    visible: modelData.visible !== undefined ? modelData.visible : true
                    label: modelData.label || ""
                    type: modelData.type || "text"
                    placeholder: modelData.placeholder || ""
                    comboModel: modelData.comboModel || []
                    esquemaCodigo: modelData.esquemaCodigo || ""
                    onUserFieldValueChanged: function(val) {
                        if (modelData && modelData.key) {
                            root.fieldValueChanged(modelData.key, val)
                        }
                    }
                }
            }

            // Slot for extra custom content below the form
            Item {
                id: extraContentContainer
                Layout.fillWidth: true
                implicitHeight: childrenRect.height
                visible: children.length > 0
            }
        }
    }
}
