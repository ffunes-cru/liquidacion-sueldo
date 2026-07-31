import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

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

        // ═══════════════════════════════════════════════════════
        // LEFT PANE: Calculation Parameters & Actions
        // ═══════════════════════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 340
            color: Theme.panelBg
            radius: 8
            border.color: Theme.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 15

                Label {
                    text: "Parámetros de Liquidación"
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.textColor
                }

                SectionPanel {
                    padding: 12

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 10

                        Label { text: "Empleado:"; color: Theme.textColor; font.pixelSize: 13 }
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

                        Label {
                            text: "Quincena / Periodo:"
                            color: Theme.textColor
                            font.pixelSize: 13
                            visible: root.employeeData && ((root.employeeData.tipoLiquidacion || root.employeeData.tipo_liquidacion) === "jornal")
                        }
                        ComboBox {
                            id: cbQuincena
                            Layout.fillWidth: true
                            model: ["Q1", "Q2"]
                            visible: root.employeeData && ((root.employeeData.tipoLiquidacion || root.employeeData.tipo_liquidacion) === "jornal")
                        }

                        Label { text: "Fecha Cálculo:"; color: Theme.textColor; font.pixelSize: 13 }
                        StyledTextField {
                            id: txtFechaCalculo
                            text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                            Layout.fillWidth: true
                        }

                        Label { text: "Mes Histórico:"; color: Theme.textColor; font.pixelSize: 13 }
                        SpinBox {
                            id: sbMes
                            from: 1; to: 12
                            value: (new Date()).getMonth() + 1
                            Layout.fillWidth: true
                        }

                        Label { text: "Año Histórico:"; color: Theme.textColor; font.pixelSize: 13 }
                        SpinBox {
                            id: sbAnio
                            from: 2020; to: 2030
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
                            if (cbEmpleado.currentIndex >= 0)
                                root.employeeData = AppController.employeeModel.get(cbEmpleado.currentIndex)
                            root.companyData = AppController.getCompany()
                            root.liquidationResult = AppController.processLiquidation(empId, cbQuincena.currentText, txtFechaCalculo.text)
                            root.statusMsg = "Liquidación calculada con éxito."
                        } else {
                            root.statusMsg = "Seleccione un empleado válido."
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "💾 Guardar en Historial"
                    enabled: root.liquidationResult !== null
                    onClicked: {
                        if (root.liquidationResult) {
                            var periodoStr = "Mes " + sbMes.value + "/" + sbAnio.value + " (" + cbQuincena.currentText + ")"
                            var recId = AppController.persistLiquidation(root.liquidationResult, sbMes.value, sbAnio.value, periodoStr)
                            root.statusMsg = recId > 0 ? "Recibo histórico guardado con ID #" + recId : "Error al guardar en el historial."
                            if (recId > 0) AppController.receiptHistoryModel.refresh()
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "📄 Exportar a PDF"
                    enabled: root.liquidationResult !== null
                    onClicked: {
                        var empId = cbEmpleado.currentValue !== undefined ? cbEmpleado.currentValue : -1
                        if (empId > 0 && root.liquidationResult) {
                            var pdfPath = AppController.exportReceiptPdf(empId, root.liquidationResult, "")
                            root.statusMsg = pdfPath !== "" ? "Recibo PDF generado: " + pdfPath : "Error al generar PDF."
                        }
                    }
                }

                Label {
                    text: root.statusMsg
                    color: Theme.accentColor
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ═══════════════════════════════════════════════════════
        // RIGHT PANE: Paystub Preview Document
        // ═══════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.panelBg
            radius: 8
            border.color: Theme.borderColor

            ScrollView {
                id: mainScroll
                anchors.fill: parent
                anchors.margins: 15
                clip: true

                ColumnLayout {
                    width: mainScroll.width - 30
                    spacing: 15

                    // Title
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Vista Previa del Recibo de Sueldo"
                            font.pixelSize: 18; font.bold: true; color: Theme.textColor
                        }
                        Item { Layout.fillWidth: true }
                        Label {
                            text: root.liquidationResult ? ("Esquema: " + (root.employeeData ? root.employeeData.esquema_codigo : "")) : "Sin Calcular"
                            font.pixelSize: 12; color: Theme.accentColor
                        }
                    }

                    // ── Document Header Card ─────────────────────────
                    SectionPanel {
                        padding: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    spacing: 2
                                    Label {
                                        text: root.companyData ? (root.companyData.razon_social || "EMPRESA S.A.") : "EMPRESA S.A."
                                        font.bold: true; font.pixelSize: 15; color: Theme.textColor
                                    }
                                    Label {
                                        text: "CUIT: " + (root.companyData ? (root.companyData.cuit || "No registrado") : "-") + " | " + (root.companyData ? (root.companyData.direccion || "") : "")
                                        font.pixelSize: 11; color: Theme.subtextColor
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                BadgePill {
                                    text: "RECIBO DE SUELDO"
                                    badgeColor: Theme.accentColor
                                    fontSize: 11
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderColor }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4; rowSpacing: 6; columnSpacing: 15

                                Label { text: "Empleado:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                                Label { text: root.employeeData ? root.employeeData.nombre_completo : "-"; color: Theme.textColor; font.bold: true; font.pixelSize: 13 }
                                Label { text: "Legajo:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                                Label { text: root.employeeData ? root.employeeData.legajo : "-"; color: Theme.textColor; font.pixelSize: 13 }
                                Label { text: "CUIL:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                                Label { text: root.employeeData ? (root.employeeData.cuil || "N/A") : "-"; color: Theme.textColor; font.pixelSize: 13 }
                                Label { text: "Categoría:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 12 }
                                Label { text: root.employeeData ? (root.employeeData.categoria_nombre || "General") : "-"; color: Theme.textColor; font.pixelSize: 13 }
                            }
                        }
                    }

                    // ── KPI Summary Cards ─────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        KpiCard {
                            title: "Total Remunerativo"
                            value: root.liquidationResult ? "$ " + Number(root.liquidationResult["total_remunerativo"] || 0).toFixed(2) : "$ 0.00"
                            borderAccent: Theme.successColor
                            valueColor: Theme.successColor
                        }

                        KpiCard {
                            title: "Total Descuentos"
                            value: root.liquidationResult ? "$ " + Number(root.liquidationResult["total_descuentos"] || 0).toFixed(2) : "$ 0.00"
                            borderAccent: Theme.dangerColor
                            valueColor: Theme.dangerColor
                        }

                        KpiCard {
                            title: "NETO A COBRAR"
                            value: root.liquidationResult ? "$ " + Number(root.liquidationResult["neto_a_cobrar"] || 0).toFixed(2) : "$ 0.00"
                            borderAccent: Theme.accentColor
                            valueColor: Theme.accentColor
                            valueSize: 18
                        }
                    }

                    // ── Concepts Breakdown Table ──────────────────────
                    SectionPanel {
                        Layout.fillHeight: true
                        padding: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Table Header
                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                color: Theme.headerBg
                                radius: 4

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    spacing: 8

                                    Label { text: "Cód"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 80 }
                                    Label { text: "Descripción del Concepto"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11; Layout.fillWidth: true }
                                    Label { text: "Unidad"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                                    Label { text: "Base Imp."; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                                    Label { text: "Haberes ($)"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
                                    Label { text: "Descuentos ($)"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
                                }
                            }

                            // Empty state
                            Label {
                                visible: !root.liquidationResult || !root.liquidationResult["conceptos"] || root.liquidationResult["conceptos"].length === 0
                                text: "Haga clic en '⚡ Calcular Liquidación' para ver los conceptos."
                                color: Theme.subtextColor
                                font.italic: true; font.pixelSize: 13
                                Layout.alignment: Qt.AlignHCenter; Layout.margins: 20
                            }

                            // Concept rows & Separators
                            Repeater {
                                model: root.liquidationResult ? root.liquidationResult["conceptos"] : []
                                delegate: Rectangle {
                                    property bool isSep: (modelData["tipo_calculo"] === "separator" || (modelData["codigo"] || "").indexOf("SEP_") === 0)
                                    Layout.fillWidth: true
                                    height: isSep ? 32 : 36
                                    color: isSep ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.15)
                                                 : (index % 2 === 0 ? Qt.alpha("#ffffff", 0.02) : "transparent")
                                    radius: 4
                                    border.color: isSep ? Theme.accentColor : "transparent"
                                    border.width: isSep ? 1 : 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8; anchors.rightMargin: 8
                                        spacing: 8

                                        // Separator full banner title
                                        Label {
                                            visible: isSep
                                            text: "🔹  " + (modelData["descripcion"] || "SECCIÓN")
                                            color: Theme.textColor
                                            font.bold: true
                                            font.pixelSize: 13
                                            Layout.fillWidth: true
                                        }

                                        // Regular concept columns
                                        Label {
                                            visible: !isSep
                                            text: modelData["codigo"] || modelData["codigo_variable"] || ""
                                            color: Theme.accentColor; font.bold: true; font.family: "Monospace"; font.pixelSize: 12
                                            Layout.preferredWidth: 80; elide: Text.ElideRight
                                        }
                                        Label {
                                            visible: !isSep
                                            text: modelData["descripcion"] || ""
                                            color: Theme.textColor; font.pixelSize: 13
                                            Layout.fillWidth: true; elide: Text.ElideRight
                                        }
                                        Label {
                                            visible: !isSep
                                            text: (modelData["unidad"] !== undefined && modelData["unidad"] !== null && Number(modelData["unidad"]) !== 0) ? Number(modelData["unidad"]).toFixed(2) : "-"
                                            color: Theme.subtextColor; font.pixelSize: 12
                                            Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight
                                        }
                                        Label {
                                            visible: !isSep
                                            text: (modelData["base"] !== undefined && modelData["base"] !== null && Number(modelData["base"]) > 0) ? "$ " + Number(modelData["base"]).toFixed(2) : "-"
                                            color: Theme.subtextColor; font.pixelSize: 12
                                            Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight
                                        }
                                        Label {
                                            visible: !isSep
                                            property string sec: (modelData["seccion"] || "").toUpperCase()
                                            text: (sec === "REMUNERATIVO" || sec === "NO_REMUNERATIVO" || sec === "COMPOSICION" || sec === "HABERES") ? "$ " + Number(modelData["monto"] || 0).toFixed(2) : "-"
                                            color: Theme.successColor; font.bold: true; font.pixelSize: 13
                                            Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight
                                        }
                                        Label {
                                            visible: !isSep
                                            property string sec: (modelData["seccion"] || "").toUpperCase()
                                            text: (sec === "DESCUENTO" || sec === "RECIBO" || sec === "RETENCION" || sec === "RETENCIONES") ? "$ " + Number(modelData["monto"] || 0).toFixed(2) : "-"
                                            color: Theme.dangerColor; font.bold: true; font.pixelSize: 13
                                            Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight
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
            cbQuincena.model = (list && list.length > 0) ? list : ["Q1", "Q2"]
        } else {
            cbQuincena.model = ["Q1", "Q2"]
        }
    }
}
