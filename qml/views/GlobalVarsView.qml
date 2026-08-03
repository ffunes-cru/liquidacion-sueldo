import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

CrudView {
    id: root

    title: "Variables Globales del Sistema"
    newButtonText: "+ Nueva Variable Global"
    model: AppController.globalVarsModel
    counterSuffix: "variables"
    emptyStateText: "No hay variables globales registradas"
    emptyStateIcon: "🌐"

    onCreateRequested: globalVarDialog.openNew()

    delegateComponent: Component {
        CrudDelegate {
            primaryText: model.description || "Sin descripción"
            secondaryText: "Doble clic para editar"
            valueText: model.value
            valueColor: Theme.successColor
            itemId: model.varId
            itemData: ({ varId: model.varId, code: model.code, value: model.value, description: model.description })

            middleContent: Component {
                BadgePill {
                    text: model.code
                    badgeColor: Theme.accentColor
                }
            }

            onEditRequested: function(data) {
                globalVarDialog.openEdit(data)
            }
            onDeleteRequested: function(id) {
                confirmDeleteGlobalVarDialog.targetId = id
                confirmDeleteGlobalVarDialog.open()
            }
        }
    }

    FormDialog {
        id: globalVarDialog
        entityName: "Variable Global"
        dialogWidth: 460

        formFields: [
            { key: "code",        label: "Código de Variable:", placeholder: "Ej: TOPE_JUBILATORIO", type: "text" },
            { key: "value",       label: "Valor:",             placeholder: "Ej: 150000.00",         type: "text" },
            { key: "description", label: "Descripción:",       placeholder: "Descripción o tope...", type: "text" }
        ]

        onFormAccepted: function(values) {
            AppController.globalVarsModel.saveVariable(
                globalVarDialog.itemId > 0 ? globalVarDialog.itemId : 0,
                values.code.trim(),
                values.value.trim(),
                values.description.trim()
            )
        }
    }

    ConfirmDialog {
        id: confirmDeleteGlobalVarDialog
        property int targetId: -1
        title: "🗑️ Eliminar Variable Global"
        message: "¿Está seguro de eliminar esta variable global del sistema?"
        confirmButtonText: "Sí, Eliminar"
        confirmButtonVariant: "danger"
        onConfirmed: {
            if (targetId > 0) AppController.globalVarsModel.removeVariable(targetId)
        }
    }
}
