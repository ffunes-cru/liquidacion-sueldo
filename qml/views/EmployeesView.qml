import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property int selectedEmployeeId: -1
    property int selectedRow: -1
    property string currentQuincena: "Q1"
    property bool isJornal: false
    property var quincenasList: ["Q1", "Q2"]
    property bool isLoading: false

    // Save the entire basic employee form
    function saveEmployeeForm() {
        if (root.isLoading || root.selectedEmployeeId <= 0) return;

        var catId = (cbCategoria.currentIndex >= 0 && cbCategoria.currentValue !== undefined) ? cbCategoria.currentValue : 0
        AppController.employeeModel.saveEmployee(
            root.selectedEmployeeId,
            txtLegajo.text,
            txtNombre.text,
            root.isJornal ? "jornal" : "mensual",
            cbEsquema.currentText || "MENSUAL",
            catId || 0,
            txtFechaIngreso.text,
            txtCuil.text
        )
    }

    // Load selected employee into form
    function loadEmployee(row) {
        if (row < 0 || row >= AppController.employeeModel.count) {
            clearForm()
            return
        }

        root.isLoading = true
        selectedRow = row
        var emp = AppController.employeeModel.get(row)
        selectedEmployeeId = emp.id

        txtLegajo.text = emp.legajo || ""
        txtNombre.text = emp.nombre_completo || ""
        txtCuil.text = emp.cuil || ""
        txtFechaIngreso.text = emp.fecha_ingreso || "2020-01-01"

        // Set Tipo Liquidación
        var tipo = emp.tipo_liquidacion || "mensual"
        cbTipoLiq.currentIndex = (tipo === "jornal") ? 1 : 0
        root.isJornal = (tipo === "jornal")

        // Set Esquema combo
        setComboValue(cbEsquema, emp.esquema_codigo)

        // Set Categoria combo
        setComboValue(cbCategoria, emp.categoria_jornal_id)

        // Load quincenas list dynamically
        refreshQuincenas()

        root.isLoading = false
    }

    function refreshQuincenas() {
        if (selectedEmployeeId > 0) {
            var list = AppController.listEmployeeQuincenas(selectedEmployeeId)
            if (list && list.length > 0) {
                quincenasList = list
            } else {
                quincenasList = ["Q1"]
            }
        } else {
            quincenasList = ["Q1"]
        }
        if (quincenasList.indexOf(currentQuincena) < 0) {
            currentQuincena = quincenasList[0]
        }
        AppController.employeeVarsModel.employeeId = selectedEmployeeId
        AppController.employeeVarsModel.quincena = currentQuincena
    }

    function clearForm() {
        root.isLoading = true
        selectedRow = -1
        selectedEmployeeId = -1
        txtLegajo.text = ""
        txtNombre.text = ""
        txtCuil.text = ""
        txtFechaIngreso.text = "2020-01-01"
        cbTipoLiq.currentIndex = 0
        root.isJornal = false
        quincenasList = ["Q1"]
        currentQuincena = "Q1"
        AppController.employeeVarsModel.employeeId = -1
        root.isLoading = false
    }

    function setComboValue(combo, value) {
        for (var i = 0; i < combo.count; i++) {
            if (combo.textAt(i) === value || combo.valueAt(i) === value) {
                combo.currentIndex = i
                return
            }
        }
        if (combo.count > 0) combo.currentIndex = 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════════════
        // LEFT PANE: Employee List & Actions
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 380
            color: window.panelBg
            radius: 8
            border.color: window.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header & Search
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Lista de Empleados"
                        font.pixelSize: 16
                        font.bold: true
                        color: window.textColor
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: AppController.employeeModel.count + " emp."
                        font.pixelSize: 12
                        color: window.subtextColor
                    }
                }

                // Interactive Real-Time Search Bar
                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholderText: "Buscar por legajo o nombre..."
                    color: window.textColor
                    onTextChanged: {
                        AppController.employeeModel.filterText = text
                    }
                    background: Rectangle {
                        color: window.inputBg
                        radius: 6
                        border.color: searchInput.activeFocus ? window.accentColor : window.borderColor
                    }
                }

                // Employee ListView
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: empListView
                        model: AppController.employeeModel
                        spacing: 6

                        delegate: Rectangle {
                            width: empListView.width
                            height: 60
                            radius: 6
                            color: root.selectedEmployeeId === model.employeeId ? (window.isDark ? "#3b3b58" : "#e4e4e9") :
                                   (mouseArea.containsMouse ? (window.isDark ? "#303045" : "#f0f0f5") : window.cardBg)
                            border.color: root.selectedEmployeeId === model.employeeId ? window.accentColor : window.borderColor
                            border.width: 1

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.loadEmployee(index)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Rectangle {
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: model.tipoLiquidacion === "jornal" ? "#fab387" : "#89b4fa"

                                    Label {
                                        anchors.centerIn: parent
                                        text: model.tipoLiquidacion === "jornal" ? "J" : "M"
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: "#11111b"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        text: model.nombre
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: window.textColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        Label {
                                            text: "Leg: " + model.legajo
                                            font.pixelSize: 12
                                            color: window.subtextColor
                                        }
                                        Label { text: "•"; font.pixelSize: 10; color: window.subtextColor }
                                        Label {
                                            text: model.esquema
                                            font.pixelSize: 12
                                            color: window.accentColor
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        Layout.fillWidth: true
                        text: "Nuevo"
                        visible: AppController.currentRole === "admin"
                        onClicked: {
                            var newId = AppController.employeeModel.addEmployee(
                                "000" + (AppController.employeeModel.count + 1),
                                "Nuevo Empleado",
                                "mensual",
                                "MENSUAL",
                                0,
                                "2020-01-01",
                                ""
                            )
                            if (newId > 0) {
                                root.loadEmployee(AppController.employeeModel.count - 1)
                            }
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: "Duplicar"
                        enabled: root.selectedEmployeeId > 0
                        onClicked: {
                            if (root.selectedEmployeeId > 0) {
                                AppController.employeeModel.duplicateEmployee(root.selectedEmployeeId)
                                root.loadEmployee(AppController.employeeModel.count - 1)
                            }
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: "Eliminar"
                        visible: AppController.currentRole === "admin"
                        enabled: root.selectedEmployeeId > 0
                        onClicked: {
                            if (root.selectedEmployeeId > 0) {
                                AppController.employeeModel.removeEmployee(root.selectedEmployeeId)
                                root.clearForm()
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // RIGHT PANE: Employee Form & Variable Input Editor
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: window.panelBg
            radius: 8
            border.color: window.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 12

                Label {
                    text: root.selectedEmployeeId > 0 ? "Editar Empleado #" + root.selectedEmployeeId : "Ficha del Empleado"
                    font.pixelSize: 18
                    font.bold: true
                    color: window.textColor
                }

                // ── Basic Info Form ────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: formGrid.implicitHeight + 20
                    color: window.cardBg
                    radius: 6
                    border.color: window.borderColor

                    GridLayout {
                        id: formGrid
                        anchors.fill: parent
                        anchors.margins: 10
                        columns: 4
                        rowSpacing: 10
                        columnSpacing: 15

                        Label { text: "Legajo:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtLegajo
                            Layout.fillWidth: true
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 4
                                border.color: parent.activeFocus ? window.accentColor : window.borderColor
                            }
                            onEditingFinished: root.saveEmployeeForm()
                        }

                        Label { text: "Nombre Completo:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtNombre
                            Layout.fillWidth: true
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 4
                                border.color: parent.activeFocus ? window.accentColor : window.borderColor
                            }
                            onEditingFinished: root.saveEmployeeForm()
                        }

                        Label { text: "Tipo Liquidación:"; color: window.textColor; font.pixelSize: 13 }
                        ComboBox {
                            id: cbTipoLiq
                            Layout.fillWidth: true
                            model: ["Mensual", "Jornalero"]
                            onActivated: {
                                root.isJornal = (currentIndex === 1)
                                root.saveEmployeeForm()
                            }
                        }

                        Label { text: "Esquema:"; color: window.textColor; font.pixelSize: 13 }
                        ComboBox {
                            id: cbEsquema
                            Layout.fillWidth: true
                            model: AppController.schemaModel
                            textRole: "code"
                            onActivated: root.saveEmployeeForm()
                        }

                        Label { text: "Categoría Jornal:"; color: window.textColor; font.pixelSize: 13 }
                        ComboBox {
                            id: cbCategoria
                            Layout.fillWidth: true
                            model: AppController.categoryModel
                            textRole: "name"
                            valueRole: "catId"
                            enabled: root.isJornal
                            onActivated: root.saveEmployeeForm()
                        }

                        Label { text: "Fecha Ingreso:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtFechaIngreso
                            placeholderText: "YYYY-MM-DD"
                            Layout.fillWidth: true
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 4
                                border.color: parent.activeFocus ? window.accentColor : window.borderColor
                            }
                            onEditingFinished: root.saveEmployeeForm()
                        }

                        Label { text: "CUIL:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtCuil
                            placeholderText: "20-12345678-9"
                            Layout.fillWidth: true
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 4
                                border.color: parent.activeFocus ? window.accentColor : window.borderColor
                            }
                            onEditingFinished: root.saveEmployeeForm()
                        }
                    }
                }

                // ── Dynamic N-Quincena Selector Bar (For Jornaleros) ───
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.isJornal
                    spacing: 10

                    Label {
                        text: "Quincenas:"
                        font.bold: true
                        color: window.textColor
                    }

                    TabBar {
                        id: quincenaTabBar
                        Layout.fillWidth: true

                        Repeater {
                            model: root.quincenasList
                            TabButton {
                                contentItem: Text {
                                    text: modelData
                                    color: parent.checked ? window.accentColor : window.textColor
                                    font.bold: parent.checked
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    root.currentQuincena = modelData
                                    AppController.employeeVarsModel.quincena = modelData
                                }
                            }
                        }
                    }

                    Button {
                        text: "Agregar Quincena"
                        onClicked: {
                            if (root.selectedEmployeeId > 0) {
                                var nextCode = "Q" + (root.quincenasList.length + 1)
                                AppController.addQuincena(root.selectedEmployeeId, nextCode)
                                root.currentQuincena = nextCode
                                root.refreshQuincenas()
                            }
                        }
                    }

                    Button {
                        text: "Eliminar Quincena"
                        enabled: root.currentQuincena !== "Q1"
                        onClicked: {
                            if (root.selectedEmployeeId > 0 && root.currentQuincena !== "Q1") {
                                AppController.removeQuincena(root.selectedEmployeeId, root.currentQuincena)
                                root.currentQuincena = "Q1"
                                root.refreshQuincenas()
                            }
                        }
                    }
                }

                // ── Variable Input Fields (Relational Model) ──────────
                Label {
                    text: "Variables de Entrada (" + (root.isJornal ? root.currentQuincena + " - " : "") + (cbEsquema.currentText || "") + "):"
                    font.pixelSize: 14
                    font.bold: true
                    color: window.accentColor
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: window.cardBg
                    radius: 6
                    border.color: window.borderColor

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true

                        ListView {
                            id: varsListView
                            model: AppController.employeeVarsModel
                            spacing: 8

                            delegate: Rectangle {
                                width: varsListView.width - 20
                                height: 42
                                color: window.panelBg
                                radius: 4
                                border.color: window.borderColor

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 12

                                    Label {
                                        text: model.fieldLabel + " (" + model.fieldCode + ")"
                                        font.pixelSize: 13
                                        color: window.textColor
                                        Layout.preferredWidth: 200
                                        elide: Text.ElideRight
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Switch for bool types
                                    Switch {
                                        visible: model.fieldType === "bool"
                                        checked: model.value === "true" || model.value === "1"
                                        onToggled: {
                                            AppController.employeeVarsModel.setValue(index, checked ? "true" : "false")
                                        }
                                    }

                                    // TextField for numeric / string types with validation
                                    TextField {
                                        id: txtVal
                                        visible: model.fieldType !== "bool"
                                        text: model.value
                                        Layout.preferredWidth: 140
                                        color: window.textColor
                                        horizontalAlignment: Text.AlignRight
                                        inputMethodHints: model.fieldType === "number" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
                                        validator: model.fieldType === "number" ? numValidator : null

                                        background: Rectangle {
                                            color: window.inputBg
                                            radius: 4
                                            border.color: parent.activeFocus ? window.accentColor : window.borderColor
                                        }

                                        DoubleValidator {
                                            id: numValidator
                                            locale: "C"
                                            notation: DoubleValidator.StandardNotation
                                        }

                                        onEditingFinished: {
                                            var ok = AppController.employeeVarsModel.setValue(index, text)
                                            if (!ok) {
                                                text = model.value // Revert if backend validation rejected the value
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Bottom Save Button Bar ──────────────────────────────
                RowLayout {
                    Layout.fillWidth: true

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Guardar Cambios"
                        highlighted: true
                        enabled: root.selectedEmployeeId > 0
                        onClicked: root.saveEmployeeForm()
                    }
                }
            }
        }
    }
}
