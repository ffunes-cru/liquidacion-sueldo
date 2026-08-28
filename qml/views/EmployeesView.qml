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
            cbQuincenas.model = (list && list.length > 0) ? list : ["Q1"]
            if (cbQuincenas.currentIndex < 0 || cbQuincenas.currentIndex >= cbQuincenas.count) {
                cbQuincenas.currentIndex = 0
            }
            currentQuincena = cbQuincenas.currentText || "Q1"
            AppController.employeeVarsModel.quincena = currentQuincena
        }
    }

    function getCategoriesCombo() {
        var list = []
        var cats = AppController.listCategories()
        for (var i = 0; i < cats.length; i++) {
            var c = cats[i]
            list.push({ id: c.id, text: (c.nombre || "Cat " + c.id) + " ($" + (c.valor_hora || c.valorHora || 0) + "/hs)" })
        }
        return list.length > 0 ? list : [{ id: 1, text: "General ($0/hs)" }]
    }

    function getSchemasCombo(tipoLiq) {
        var list = []
        var schemas = AppController.listSchemas()
        var targetType = (tipoLiq || "mensual").toLowerCase()
        for (var i = 0; i < schemas.length; i++) {
            var s = schemas[i]
            var sType = (s.tipo_liquidacion || s.tipoLiquidacion || "mensual").toLowerCase()
            if (sType === targetType) {
                list.push(s.codigo || s.code)
            }
        }
        return list.length > 0 ? list : (targetType === "jornal" ? ["JORNAL"] : ["MENSUAL"])
    }

    // ── Master Delegate ─────────────────────────────────────────
    masterDelegate: Component {
        CrudDelegate {
            height: 60
            primaryText: model.nombre || ""
            secondaryText: "Legajo: " + (model.legajo || "-") + (model.cuil ? " | CUIL: " + model.cuil : "")
            badgeText: model.esquema || "MENSUAL"
            badgeColor: model.tipoLiquidacion === "jornal" ? Theme.warningColor : Theme.infoColor
            showAdminActions: AppController.currentRole === "admin" && !AppController.isCurrentPeriodClosed
            showDuplicate: AppController.currentRole === "admin" && !AppController.isCurrentPeriodClosed
            itemId: model.employeeId || model.id || AppController.employeeModel.idAtRow(index)
            itemData: ({
                employeeId: model.employeeId || model.id || AppController.employeeModel.idAtRow(index),
                legajo: model.legajo || "",
                nombre: model.nombre || "",
                tipoLiquidacion: model.tipoLiquidacion || "mensual",
                esquema: model.esquema || "MENSUAL",
                categoriaId: model.categoriaId || model.categoria_jornal_id || 1,
                categoriaNombre: model.categoriaNombre || "",
                fechaIngreso: model.fechaIngreso || "",
                cuil: model.cuil || ""
            })

            color: root.selectedIndex === index ? Theme.selectedBg : Theme.cardBg
            border.color: root.selectedIndex === index ? Theme.accentColor : Theme.borderColor

            onClicked: root.selectEmployeeAtRow(index)

            onEditRequested: function(data) {
                if (AppController.isCurrentPeriodClosed) return;
                employeeDialog.setComboModel("categoriaId", root.getCategoriesCombo())
                var tipo = (data.tipoLiquidacion || data.tipo_liquidacion || "mensual").toLowerCase()
                employeeDialog.setComboModel("esquema", root.getSchemasCombo(tipo))
                employeeDialog.setFieldVisible("categoriaId", tipo === "jornal")
                employeeDialog.openEdit(data)
            }
            onDeleteRequested: function(data) {
                if (AppController.isCurrentPeriodClosed) return;
                var id = data.employeeId || data.id
                confirmDeleteEmployeeDialog.targetId = id
                confirmDeleteEmployeeDialog.open()
            }
            onDuplicateRequested: function(data) {
                if (AppController.isCurrentPeriodClosed) return;
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

        StyledButton {
            Layout.fillWidth: true
            variant: "primary"
            text: "➕ Nuevo Empleado"
            visible: AppController.currentRole === "admin" && !AppController.isCurrentPeriodClosed
            onClicked: {
                employeeDialog.setComboModel("categoriaId", root.getCategoriesCombo())
                employeeDialog.setComboModel("esquema", root.getSchemasCombo("mensual"))
                employeeDialog.setFieldVisible("categoriaId", false)
                employeeDialog.openNew()
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // DETAIL CONTENT (Right Panel)
    // ══════════════════════════════════════════════════════════════
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        // Status Banner for Closed Month
        StatusBanner {
            visible: AppController.isCurrentPeriodClosed
            Layout.fillWidth: true
            variant: "warning"
            message: "🔒 Período " + AppController.selectedMonth + "/" + AppController.selectedYear + " Cerrado: Visualizando snapshot inmutable de empleados e insumos. Los datos se encuentran en modo solo lectura."
        }

        // Employee Info Card
        SectionPanel {
            visible: root.selectedEmployeeId > 0
            title: root.selectedEmployeeData ? (root.selectedEmployeeData.nombre || root.selectedEmployeeData.nombre_completo || "Empleado Seleccionado") : "Empleado Seleccionado"
            padding: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 8
                    columnSpacing: 16

                    Label { text: "Legajo:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                    Label { text: root.selectedEmployeeData ? (root.selectedEmployeeData.legajo || "-") : "-"; color: Theme.textColor; font.pixelSize: 13 }

                    Label { text: "CUIL:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                    Label { text: root.selectedEmployeeData ? (root.selectedEmployeeData.cuil || "N/A") : "-"; color: Theme.textColor; font.pixelSize: 13 }

                    Label { text: "Esquema:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                    Label { text: root.selectedEmployeeData ? (root.selectedEmployeeData.esquema || root.selectedEmployeeData.esquema_codigo || "-") : "-"; color: Theme.accentColor; font.bold: true; font.pixelSize: 13 }

                    Label { text: "Categoría:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                    Label { text: root.selectedEmployeeData ? (root.selectedEmployeeData.categoriaNombre || root.selectedEmployeeData.categoria_nombre || "General") : "-"; color: Theme.textColor; font.pixelSize: 13 }

                    Label { text: "Tipo Liquidación:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                    Label { text: root.selectedEmployeeData ? (root.selectedEmployeeData.tipoLiquidacion || root.selectedEmployeeData.tipo_liquidacion || "-") : "-"; color: Theme.textColor; font.pixelSize: 13 }

                    Label { text: "Fecha Ingreso:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                    Label { text: root.selectedEmployeeData ? (root.selectedEmployeeData.fechaIngreso || root.selectedEmployeeData.fecha_ingreso || "N/A") : "-"; color: Theme.textColor; font.pixelSize: 13 }
                }
            }
        }

        // Quincena Selector Bar (Only for Jornal / Hourly Employees)
        RowLayout {
            visible: root.selectedEmployeeId > 0 && root.selectedEmployeeData && ((root.selectedEmployeeData.tipoLiquidacion || root.selectedEmployeeData.tipo_liquidacion) === "jornal")
            Layout.fillWidth: true
            spacing: 12

            Label {
                text: "Variables de Liquidación para:"
                font.bold: true
                font.pixelSize: 14
                color: Theme.accentColor
            }

            StyledComboBox {
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

            StyledButton {
                variant: "secondary"
                text: "➕ Agregar Quincena"
                visible: AppController.currentRole === "admin" && !AppController.isCurrentPeriodClosed
                onClicked: {
                    var nextQ = "Q" + (cbQuincenas.count + 1)
                    AppController.addQuincena(root.selectedEmployeeId, nextQ)
                    root.refreshQuincenasList()
                }
            }

            StyledButton {
                variant: "danger"
                text: "🗑️ Eliminar Quincena"
                visible: AppController.currentRole === "admin" && !AppController.employeeVarsModel.isReadOnly && cbQuincenas.count > 1 && cbQuincenas.currentText !== "Q1"
                onClicked: confirmDeleteQuincenaDialog.open()
            }

            BadgePill {
                text: "🔒 Quincena Cerrada"
                variant: "warning"
                visible: AppController.employeeVarsModel.isReadOnly
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
                        readOnly: AppController.employeeVarsModel.isReadOnly
                        onValueSaved: function(newValue) {
                            if (!AppController.employeeVarsModel.isReadOnly) {
                                AppController.employeeVarsModel.setValue(index, newValue)
                            }
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
            { key: "esquema",      label: "Esquema de Cálculo:", type: "combo", comboModel: root.getSchemasCombo("mensual") },
            { key: "categoriaId",  label: "Categoría Jornalera:", type: "combo", comboModel: root.getCategoriesCombo(), visible: false },
            { key: "fechaIngreso", label: "Fecha Ingreso:",   placeholder: "YYYY-MM-DD", type: "date" }
        ]

        onFieldValueChanged: function(key, newValue) {
            if (key === "tipoLiq") {
                var t = (newValue || "mensual").toString().toLowerCase()
                employeeDialog.setComboModel("esquema", root.getSchemasCombo(t))
                employeeDialog.setFieldVisible("categoriaId", t === "jornal")
            }
        }

        onFormAccepted: function(values) {
            var empId = employeeDialog.itemId
            var legajo = values.legajo ? values.legajo.trim() : ""
            var nombre = values.nombre ? values.nombre.trim() : ""
            var cuil = values.cuil ? values.cuil.trim() : ""
            var tipoLiq = values.tipoLiq || "mensual"
            var esquema = values.esquema || "MENSUAL"
            var catId = (tipoLiq === "jornal" && values.categoriaId) ? (parseInt(values.categoriaId) || 0) : 0
            var fechaIngreso = values.fechaIngreso ? values.fechaIngreso.trim() : ""

            if (legajo !== "" && nombre !== "") {
                var targetId = empId
                if (empId > 0) {
                    AppController.employeeModel.saveEmployee(empId, legajo, nombre, tipoLiq, esquema, catId, fechaIngreso, cuil)
                } else {
                    targetId = AppController.employeeModel.addEmployee(legajo, nombre, tipoLiq, esquema, catId, fechaIngreso, cuil)
                    if (targetId > 0) {
                        AppController.employeeModel.refresh()
                    }
                }
                root.selectEmployeeAtRow(root.selectedIndex >= 0 ? root.selectedIndex : 0)
                if (targetId > 0) {
                    AppController.employeeVarsModel.employeeId = targetId
                    AppController.employeeVarsModel.refresh()
                }
            }
        }
    }

    ConfirmDialog {
        id: confirmDeleteEmployeeDialog
        property int targetId: -1
        title: "🗑️ Eliminar Empleado"
        message: "¿Está seguro de eliminar a este empleado y toda su información registrada?"
        confirmButtonText: "Sí, Eliminar"
        confirmButtonVariant: "danger"
        onConfirmed: {
            if (targetId > 0) {
                AppController.employeeModel.removeEmployee(targetId)
                if (AppController.employeeModel.count > 0) root.selectEmployeeAtRow(0)
                else { root.selectedEmployeeId = -1; root.selectedEmployeeData = null }
            }
        }
    }

    ConfirmDialog {
        id: confirmDeleteQuincenaDialog
        title: "🗑️ Eliminar Quincena"
        message: "¿Está seguro de eliminar los datos guardados para la quincena " + (cbQuincenas.currentText || "") + "?"
        confirmButtonText: "Sí, Eliminar Quincena"
        confirmButtonVariant: "danger"
        onConfirmed: {
            if (cbQuincenas.currentText && cbQuincenas.currentText !== "") {
                AppController.removeQuincena(root.selectedEmployeeId, cbQuincenas.currentText)
                root.refreshQuincenasList()
            }
        }
    }
}
