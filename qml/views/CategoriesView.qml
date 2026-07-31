import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

CrudView {
    id: root

    title: "Categorías Jornaleras"
    newButtonText: "+ Nueva Categoría"
    model: AppController.categoryModel
    counterSuffix: "categorías"
    emptyStateText: "No hay categorías jornaleras registradas"
    emptyStateIcon: "🏷️"

    onCreateRequested: categoryDialog.openNew()

    delegateComponent: Component {
        CrudDelegate {
            primaryText: model.name
            secondaryText: "Doble clic para editar"
            badgeText: "#" + model.catId
            badgeCircular: true
            valueText: "$ " + Number(model.valorHora).toFixed(2) + " / hora"
            valueColor: Theme.successColor
            itemId: model.catId
            itemData: ({ catId: model.catId, name: model.name, valorHora: model.valorHora })

            onEditRequested: function(data) {
                categoryDialog.openEdit(data)
            }
            onDeleteRequested: function(id) {
                AppController.categoryModel.removeCategory(id)
            }
        }
    }

    FormDialog {
        id: categoryDialog
        entityName: "Categoría"
        dialogWidth: 420

        formFields: [
            { key: "name",      label: "Nombre:",           placeholder: "Ej: Maestranza A Jornal", type: "text" },
            { key: "valorHora", label: "Valor por Hora ($):", placeholder: "5540.61",                type: "number" }
        ]

        onFormAccepted: function(values) {
            var val = parseFloat(values.valorHora) || 0.0
            AppController.categoryModel.saveCategory(
                categoryDialog.itemId > 0 ? categoryDialog.itemId : 0,
                values.name.trim(),
                val
            )
        }
    }
}
