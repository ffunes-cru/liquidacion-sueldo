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
        for (var i = 0; i < formFields.length; i++) {
            var field = formFields[i]
            var repeaterItem = fieldRepeater.itemAt(i)
            if (repeaterItem && values[field.key] !== undefined) {
                repeaterItem.value = values[field.key].toString()
            }
        }
    }

    // Helper to clear all fields (for new mode)
    function openNew() {
        itemId = -1
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
        if (data.id !== undefined) itemId = data.id
        else if (data.itemId !== undefined) itemId = data.itemId
        setFieldValues(data)
        open()
    }

    contentItem: ScrollView {
        clip: true

        ColumnLayout {
            width: root.width - 40
            spacing: 12

            // Auto-generated form fields
            Repeater {
                id: fieldRepeater
                model: root.formFields

                FormField {
                    Layout.fillWidth: true
                    label: modelData.label || ""
                    type: modelData.type || "text"
                    placeholder: modelData.placeholder || ""
                    comboModel: modelData.comboModel || []
                    esquemaCodigo: modelData.esquemaCodigo || ""
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
