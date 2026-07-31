import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

MasterDetailView {
    id: root

    masterWidth: 380
    masterTitle: "Nómina de Empleados"
    masterCountSuffix: "empleados"
    masterModel: AppController.employeeModel

    property int selectedEmployeeId: -1
    property var selectedEmployeeData: null
    property string currentQuincena: "Q1"

    Component.onCompleted: {
        if (AppController.employeeModel.count > 0) {
            selectEmployeeAtRow(0)
        }
    }

    function selectEmployeeAtRow(row) {
        if (row >= 0 && row < AppController.employeeModel.count) {
            selectedIndex = row
            var data = AppController.employeeModel.get(row)
            selectedEmployeeData = data
            selectedEmployeeId = data.employeeId || data.id || AppController.employeeModel.idAtRow(row)
            AppController.employeeVarsModel.employeeId = selectedEmployeeId
            AppController.employeeVarsModel.quincena = currentQuincena
            refreshQuincenasList()
        }
    }

    function refreshQuincenasList() {
        if (selectedEmployeeId > 0) {
            var list = AppController.listEmployeeQuincenas(selectedEmployeeId)
            cbQuincenas.model = (list && list.length > 0) ? list : ["Q1", "Q2"]
            if (cbQuincenas.currentIndex < 0 || cbQuincenas.currentIndex >= cbQuincenas.count) {
                cbQuincenas.currentIndex = 0
            }
            currentQuincena = cbQuincenas.currentText || "Q1"
            AppController.employeeVarsModel.quincena = currentQuincena
        }
    }

    // ── Master Delegate ─────────────────────────────────────────
    masterDelegate: Component {
        CrudDelegate {
            height: 60
            primaryText: model.nombre
            secondaryText: "Legajo: " + model.legajo + (model.cuil ? " | CUIL: " + model.cuil : "")
            badgeText: model.esquema || "MENSUAL"
            badgeColor: model.tipoLiquidacion === "jornal" ? Theme.warningColor : Theme.infoColor
            showAdminActions: true
            showDuplicate: true
            itemId: model.employeeId || model.id || AppController.employeeModel.idAtRow(index)
            itemData: ({
                employeeId: model.employeeId || model.id || AppController.employeeModel.idAtRow(index),
                legajo: model.legajo,
                nombre: model.nombre,
                tipoLiquidacion: model.tipoLiquidacion,
                esquema: model.esquema,
                categoriaId: model.categoriaId,
                categoriaNombre: model.categoriaNombre,
                fechaIngreso: model.fechaIngreso,
                cuil: model.cuil
            })

            color: root.selectedIndex === index ? Theme.selectedBg :
                   (mouseArea.containsMouse ? Theme.hoverBg : Theme.cardBg)
            border.color: root.selectedIndex === index ? Theme.accentColor : Theme.borderColor

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.selectEmployeeAtRow(index)
            }

            onEditRequested: function(data) {
                employeeDialog.openEdit({
                    employeeId: data.employeeId,
                    legajo: data.legajo,
                    nombre: data.nombre,
                    tipoLiq: data.tipoLiquidacion,
                    esquema: data.esquema,
                    categoriaId: data.categoriaId,
                    fechaIngreso: data.fechaIngreso,
                    cuil: data.cuil
                })
            }
            onDeleteRequested: function(id) {
                AppController.employeeModel.removeEmployee(id)
                if (AppController.employeeModel.count > 0) root.selectEmployeeAtRow(0)
                else { root.selectedEmployeeId = -1; root.selectedEmployeeData = null }
            }
            onDuplicateRequested: function(data) {
                AppController.employeeModel.duplicateEmployee(data.employeeId)
            }
        }
    }

    // ── Master Footer ───────────────────────────────────────────
    masterFooter: ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        StyledTextField {
            Layout.fillWidth: true
            placeholderText: "🔍 Buscar legajo, nombre..."
            onTextChanged: AppController.employeeModel.filterText = text
        }

        Button {
            Layout.fillWidth: true
            text: "+ Nuevo Empleado"
            highlighted: true
            visible: AppController.currentRole === "admin"
            onClicked: employeeDialog.openNew()
        }
    }

    // ══════════════════════════════════════════════════════════════
    // DETAIL CONTENT (Right Panel)
    // ══════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: 15

        // Employee Info Card
        SectionPanel {
            visible: root.selectedEmployeeId > 0
            title: root.selectedEmployeeData ? root.selectedEmployeeData.nombre : "Empleado Seleccionado"

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 8
                        columnSpacing: 15

                        Label { text: "Legajo:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                        Label { text: root.selectedEmployeeData ? root.selectedEmployeeData.legajo : "-"; color: Theme.textColor; font.pixelSize: 13 }

                        Label { text: "CUIL:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                        Label { text: root.selectedEmployeeData ? (root.selectedEmployeeData.cuil || "N/A") : "-"; color: Theme.textColor; font.pixelSize: 13 }

                        Label { text: "Esquema:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                        Label { text: root.selectedEmployeeData ? root.selectedEmployeeData.esquema : "-"; color: Theme.accentColor; font.bold: true; font.pixelSize: 13 }

                        Label { text: "Categoría:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                        Label { text: root.selectedEmployeeData ? (root.selectedEmployeeData.categoriaNombre || "General") : "-"; color: Theme.textColor; font.pixelSize: 13 }

                        Label { text: "Tipo Liquidación:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                        Label { text: root.selectedEmployeeData ? root.selectedEmployeeData.tipoLiquidacion : "-"; color: Theme.textColor; font.pixelSize: 13 }

                        Label { text: "Fecha Ingreso:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                        Label { text: root.selectedEmployeeData ? (root.selectedEmployeeData.fechaIngreso || "N/A") : "-"; color: Theme.textColor; font.pixelSize: 13 }
                    }

                    Button {
                        text: "✏️ Editar Ficha"
                        visible: AppController.currentRole === "admin"
                        onClicked: {
                            if (root.selectedEmployeeData) {
                                employeeDialog.openEdit({
                                    employeeId: root.selectedEmployeeId,
                                    legajo: root.selectedEmployeeData.legajo,
                                    nombre: root.selectedEmployeeData.nombre,
                                    tipoLiq: root.selectedEmployeeData.tipoLiquidacion,
                                    esquema: root.selectedEmployeeData.esquema,
                                    categoriaId: root.selectedEmployeeData.categoriaId,
                                    fechaIngreso: root.selectedEmployeeData.fechaIngreso,
                                    cuil: root.selectedEmployeeData.cuil
                                })
                            }
                        }
                    }
                }
            }
        }

        // Quincena Selector Bar
        RowLayout {
            visible: root.selectedEmployeeId > 0
            Layout.fillWidth: true
            spacing: 12

            Label {
                text: "Variables de Liquidación para:"
                font.bold: true
                font.pixelSize: 14
                color: Theme.accentColor
            }

            ComboBox {
                id: cbQuincenas
                Layout.preferredWidth: 120
                onCurrentTextChanged: {
                    if (currentText && currentText !== "") {
                        root.currentQuincena = currentText
                        AppController.employeeVarsModel.quincena = currentText
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "+ Agregar Quincena"
                visible: AppController.currentRole === "admin"
                onClicked: {
                    var nextQ = "Q" + (cbQuincenas.count + 1)
                    AppController.addQuincena(root.selectedEmployeeId, nextQ)
                    root.refreshQuincenasList()
                }
            }
        }

        // Dynamic Field Variables Editor
        Rectangle {
            visible: root.selectedEmployeeId > 0
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
                    id: varsListView
                    model: AppController.employeeVarsModel
                    spacing: 6

                    delegate: VariableEditor {
                        width: varsListView.width - 20
                        fieldCode: model.fieldCode
                        fieldLabel: model.fieldLabel
                        fieldType: model.fieldType
                        value: model.value || model.defaultValue
                        onValueSaved: function(newValue) {
                            AppController.employeeVarsModel.setValue(index, newValue)
                        }
                    }
                }
            }
        }

        // Empty state when no employee is selected
        Label {
            visible: root.selectedEmployeeId <= 0
            text: "Seleccione un empleado de la nómina para ver y editar sus variables de liquidación."
            color: Theme.subtextColor
            font.italic: true
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: 40
        }
    }

    // ── Form Dialog for Creating / Editing Employee ─────────────
    FormDialog {
        id: employeeDialog
        entityName: "Empleado"
        dialogWidth: 500

        formFields: [
            { key: "legajo",       label: "Legajo N°:",        placeholder: "Ej: 1001", type: "text" },
            { key: "nombre",       label: "Nombre Completo:", placeholder: "Ej: Juan Pérez", type: "text" },
            { key: "cuil",         label: "CUIL:",            placeholder: "Ej: 20-12345678-9", type: "text" },
            { key: "tipoLiq",      label: "Tipo Liquidación:", type: "combo", comboModel: ["mensual", "jornal"] },
            { key: "esquema",      label: "Esquema de Cálculo:", type: "combo", comboModel: ["MENSUAL", "JORNAL"] },
            { key: "fechaIngreso", label: "Fecha Ingreso:",   placeholder: "YYYY-MM-DD", type: "text" }
        ]

        onFormAccepted: function(values) {
            var empId = employeeDialog.itemId
            var legajo = values.legajo ? values.legajo.trim() : ""
            var nombre = values.nombre ? values.nombre.trim() : ""
            var cuil = values.cuil ? values.cuil.trim() : ""
            var tipoLiq = values.tipoLiq || "mensual"
            var esquema = values.esquema || "MENSUAL"
            var fechaIngreso = values.fechaIngreso ? values.fechaIngreso.trim() : ""
            var catId = 1

            if (legajo !== "" && nombre !== "") {
                if (empId > 0) {
                    AppController.employeeModel.saveEmployee(empId, legajo, nombre, tipoLiq, esquema, catId, fechaIngreso, cuil)
                } else {
                    var newId = AppController.employeeModel.addEmployee(legajo, nombre, tipoLiq, esquema, catId, fechaIngreso, cuil)
                    if (newId > 0) {
                        AppController.employeeModel.refresh()
                    }
                }
                root.selectEmployeeAtRow(root.selectedIndex >= 0 ? root.selectedIndex : 0)
            }
        }
    }
}
