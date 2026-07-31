import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property var liquidationResult: null
    property int selectedEmployeeId: -1
    property var employeeData: null
    property var companyData: null
    property string statusMsg: ""

    Component.onCompleted: {
        companyData = AppController.getCompany()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════════════
        // LEFT PANE: Calculation Parameters & Actions
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 340
            color: window.panelBg
            radius: 8
            border.color: window.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                Label {
                    text: "Parámetros de Liquidación"
                    font.pixelSize: 18
                    font.bold: true
                    color: window.textColor
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: paramGrid.implicitHeight + 24
                    color: window.cardBg
                    radius: 6
                    border.color: window.borderColor

                    GridLayout {
                        id: paramGrid
                        anchors.fill: parent
                        anchors.margins: 12
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 10

                        Label { text: "Empleado:"; color: window.textColor; font.pixelSize: 13 }
                        ComboBox {
                            id: cbEmpleado
                            Layout.fillWidth: true
                            model: AppController.employeeModel
                            textRole: "nombre"
                            valueRole: "employeeId"
                            onActivated: {
                                var empId = currentValue || -1
                                root.selectedEmployeeId = empId
                                refreshQuincenasCombo(empId)
                                if (empId > 0 && currentIndex >= 0) {
                                    root.employeeData = AppController.employeeModel.get(currentIndex)
                                }
                            }
                        }

                        Label { text: "Quincena / Periodo:"; color: window.textColor; font.pixelSize: 13 }
                        ComboBox {
                            id: cbQuincena
                            Layout.fillWidth: true
                            model: ["Q1", "Q2"]
                        }

                        Label { text: "Fecha Cálculo:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtFechaCalculo
                            text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                            Layout.fillWidth: true
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 6
                                border.color: parent.activeFocus ? window.accentColor : window.borderColor
                            }
                        }

                        Label { text: "Mes Histórico:"; color: window.textColor; font.pixelSize: 13 }
                        SpinBox {
                            id: sbMes
                            from: 1
                            to: 12
                            value: (new Date()).getMonth() + 1
                            Layout.fillWidth: true
                        }

                        Label { text: "Año Histórico:"; color: window.textColor; font.pixelSize: 13 }
                        SpinBox {
                            id: sbAnio
                            from: 2020
                            to: 2030
                            value: (new Date()).getFullYear()
                            Layout.fillWidth: true
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "⚡ Calcular Liquidación"
                    highlighted: true
                    enabled: cbEmpleado.currentIndex >= 0
                    onClicked: {
                        var empId = cbEmpleado.currentValue !== undefined ? cbEmpleado.currentValue : -1
                        if (empId > 0) {
                            if (cbEmpleado.currentIndex >= 0) {
                                root.employeeData = AppController.employeeModel.get(cbEmpleado.currentIndex)
                            }
                            root.companyData = AppController.getCompany()
                            var res = AppController.processLiquidation(empId, cbQuincena.currentText, txtFechaCalculo.text)
                            root.liquidationResult = res
                            root.statusMsg = "Liquidación calculada con éxito."
                        } else {
                            root.statusMsg = "Seleccione un empleado válido."
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "💾 Guardar en Historial"
                    enabled: root.liquidationResult !== null && root.liquidationResult !== undefined
                    onClicked: {
                        if (root.liquidationResult) {
                            var periodoStr = "Mes " + sbMes.value + "/" + sbAnio.value + " (" + cbQuincena.currentText + ")"
                            var recId = AppController.persistLiquidation(root.liquidationResult, sbMes.value, sbAnio.value, periodoStr)
                            if (recId > 0) {
                                root.statusMsg = "Recibo histórico guardado con ID #" + recId
                                AppController.receiptHistoryModel.refresh()
                            } else {
                                root.statusMsg = "Error al guardar en el historial."
                            }
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "📄 Exportar a PDF"
                    enabled: root.liquidationResult !== null && root.liquidationResult !== undefined
                    onClicked: {
                        var empId = cbEmpleado.currentValue !== undefined ? cbEmpleado.currentValue : -1
                        if (empId > 0 && root.liquidationResult) {
                            var pdfPath = AppController.exportReceiptPdf(empId, root.liquidationResult, "")
                            if (pdfPath !== "") {
                                root.statusMsg = "Recibo PDF generado: " + pdfPath
                            } else {
                                root.statusMsg = "Error al generar PDF."
                            }
                        }
                    }
                }

                Label {
                    text: root.statusMsg
                    color: window.accentColor
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // RIGHT PANE: Paystub Preview Document Card
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: window.panelBg
            radius: 8
            border.color: window.borderColor

            ScrollView {
                id: mainScroll
                anchors.fill: parent
                anchors.margins: 15
                clip: true

                ColumnLayout {
                    width: mainScroll.width - 30
                    spacing: 15

                    // Title Header
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Vista Previa del Recibo de Sueldo"
                            font.pixelSize: 18
                            font.bold: true
                            color: window.textColor
                        }
                        Item { Layout.fillWidth: true }
                        Label {
                            text: root.liquidationResult ? ("Esquema: " + (root.employeeData ? root.employeeData.esquema_codigo : "")) : "Sin Calcular"
                            font.pixelSize: 12
                            color: window.accentColor
                        }
                    }

                    // ── Paystub Document Header Card ────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: headerColumn.implicitHeight + 20
                        color: window.cardBg
                        radius: 6
                        border.color: window.borderColor

                        ColumnLayout {
                            id: headerColumn
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    spacing: 2
                                    Label {
                                        text: root.companyData ? (root.companyData.razon_social || "EMPRESA S.A.") : "EMPRESA S.A."
                                        font.bold: true
                                        font.pixelSize: 15
                                        color: window.textColor
                                    }
                                    Label {
                                        text: "CUIT: " + (root.companyData ? (root.companyData.cuit || "No registrado") : "-") + " | " + (root.companyData ? (root.companyData.direccion || "") : "")
                                        font.pixelSize: 11
                                        color: window.subtextColor
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    implicitWidth: 140
                                    implicitHeight: 28
                                    radius: 4
                                    color: Qt.alpha(window.accentColor, 0.2)
                                    border.color: window.accentColor
                                    Label {
                                        anchors.centerIn: parent
                                        text: "RECIBO DE SUELDO"
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: window.accentColor
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: window.borderColor }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                rowSpacing: 6
                                columnSpacing: 15

                                Label { text: "Empleado:"; font.bold: true; color: window.subtextColor; font.pixelSize: 12 }
                                Label {
                                    text: root.employeeData ? root.employeeData.nombre_completo : "-"
                                    color: window.textColor; font.bold: true; font.pixelSize: 13
                                }

                                Label { text: "Legajo:"; font.bold: true; color: window.subtextColor; font.pixelSize: 12 }
                                Label {
                                    text: root.employeeData ? root.employeeData.legajo : "-"
                                    color: window.textColor; font.pixelSize: 13
                                }

                                Label { text: "CUIL:"; font.bold: true; color: window.subtextColor; font.pixelSize: 12 }
                                Label {
                                    text: root.employeeData ? (root.employeeData.cuil || "N/A") : "-"
                                    color: window.textColor; font.pixelSize: 13
                                }

                                Label { text: "Categoría:"; font.bold: true; color: window.subtextColor; font.pixelSize: 12 }
                                Label {
                                    text: root.employeeData ? (root.employeeData.categoria_nombre || "General") : "-"
                                    color: window.textColor; font.pixelSize: 13
                                }
                            }
                        }
                    }

                    // ── Summary KPI Cards ──────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Total Remunerativo
                        Rectangle {
                            Layout.fillWidth: true
                            height: 65
                            color: window.cardBg
                            radius: 6
                            border.color: "#a6e3a1"

                            ColumnLayout {
                                anchors.centerIn: parent
                                Label { text: "Total Remunerativo"; color: window.subtextColor; font.pixelSize: 11 }
                                Label {
                                    text: root.liquidationResult ? "$ " + Number(root.liquidationResult["total_remunerativo"] || 0).toFixed(2) : "$ 0.00"
                                    color: "#a6e3a1"
                                    font.bold: true
                                    font.pixelSize: 16
                                }
                            }
                        }

                        // Total Descuentos
                        Rectangle {
                            Layout.fillWidth: true
                            height: 65
                            color: window.cardBg
                            radius: 6
                            border.color: "#f38ba8"

                            ColumnLayout {
                                anchors.centerIn: parent
                                Label { text: "Total Descuentos"; color: window.subtextColor; font.pixelSize: 11 }
                                Label {
                                    text: root.liquidationResult ? "$ " + Number(root.liquidationResult["total_descuentos"] || 0).toFixed(2) : "$ 0.00"
                                    color: "#f38ba8"
                                    font.bold: true
                                    font.pixelSize: 16
                                }
                            }
                        }

                        // Neto a Cobrar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 65
                            color: window.cardBg
                            radius: 6
                            border.color: window.accentColor

                            ColumnLayout {
                                anchors.centerIn: parent
                                Label { text: "NETO A COBRAR"; color: window.subtextColor; font.pixelSize: 11 }
                                Label {
                                    text: root.liquidationResult ? "$ " + Number(root.liquidationResult["neto_a_cobrar"] || 0).toFixed(2) : "$ 0.00"
                                    color: window.accentColor
                                    font.bold: true
                                    font.pixelSize: 18
                                }
                            }
                        }
                    }

                    // ── Concepts Breakdown Table ────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: conceptListColumn.implicitHeight + 24
                        color: window.cardBg
                        radius: 6
                        border.color: window.borderColor

                        ColumnLayout {
                            id: conceptListColumn
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            // Table Header
                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                color: "#181825"
                                radius: 4

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Label { text: "Cód"; font.bold: true; color: window.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 80 }
                                    Label { text: "Descripción del Concepto"; font.bold: true; color: window.subtextColor; font.pixelSize: 11; Layout.fillWidth: true }
                                    Label { text: "Unidad"; font.bold: true; color: window.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                                    Label { text: "Base Imp."; font.bold: true; color: window.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                                    Label { text: "Haberes ($)"; font.bold: true; color: window.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
                                    Label { text: "Descuentos ($)"; font.bold: true; color: window.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
                                }
                            }

                            // Empty state placeholder
                            Label {
                                visible: !root.liquidationResult || !root.liquidationResult["conceptos"] || root.liquidationResult["conceptos"].length === 0
                                text: "Haga clic en '⚡ Calcular Liquidación' para calcular y ver los conceptos."
                                color: window.subtextColor
                                font.italic: true
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignHCenter
                                Layout.margins: 20
                            }

                            // Concepts List Repeater
                            Repeater {
                                model: root.liquidationResult ? root.liquidationResult["conceptos"] : []
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: 36
                                    color: index % 2 === 0 ? Qt.alpha("#ffffff", 0.02) : "transparent"
                                    radius: 4

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Label {
                                            text: modelData["codigo"] || modelData["codigo_variable"] || ""
                                            color: window.accentColor
                                            font.bold: true
                                            font.family: "Monospace"
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 80
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            text: modelData["descripcion"] || ""
                                            color: window.textColor
                                            font.pixelSize: 13
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            text: (modelData["unidad"] !== undefined && modelData["unidad"] !== null && Number(modelData["unidad"]) !== 0) ? Number(modelData["unidad"]).toFixed(2) : "-"
                                            color: window.subtextColor
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 70
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Label {
                                            text: (modelData["base"] !== undefined && modelData["base"] !== null && Number(modelData["base"]) > 0) ? "$ " + Number(modelData["base"]).toFixed(2) : "-"
                                            color: window.subtextColor
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 90
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Label {
                                            property string sec: (modelData["seccion"] || "").toUpperCase()
                                            text: (sec === "REMUNERATIVO" || sec === "NO_REMUNERATIVO" || sec === "COMPOSICION" || sec === "HABERES") ? "$ " + Number(modelData["monto"] || 0).toFixed(2) : "-"
                                            color: "#a6e3a1"
                                            font.bold: true
                                            font.pixelSize: 13
                                            Layout.preferredWidth: 100
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Label {
                                            property string sec: (modelData["seccion"] || "").toUpperCase()
                                            text: (sec === "DESCUENTO" || sec === "RECIBO" || sec === "RETENCION" || sec === "RETENCIONES") ? "$ " + Number(modelData["monto"] || 0).toFixed(2) : "-"
                                            color: "#f38ba8"
                                            font.bold: true
                                            font.pixelSize: 13
                                            Layout.preferredWidth: 100
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function refreshQuincenasCombo(empId) {
        if (empId > 0) {
            var list = AppController.listEmployeeQuincenas(empId)
            if (list && list.length > 0) {
                cbQuincena.model = list
            } else {
                cbQuincena.model = ["Q1", "Q2"]
            }
        } else {
            cbQuincena.model = ["Q1", "Q2"]
        }
    }
}
