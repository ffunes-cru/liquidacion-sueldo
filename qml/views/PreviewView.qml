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
                        StyledComboBox {
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
                        StyledComboBox {
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
                            onTextChanged: {
                                var parts = text.split("-")
                                if (parts.length === 3) {
                                    var y = parseInt(parts[0])
                                    var m = parseInt(parts[1])
                                    if (m >= 1 && m <= 12) sbMes.value = m
                                    if (y >= 2000 && y <= 2100) sbAnio.value = y
                                }
                            }
                        }

                        Label { text: "Mes Histórico:"; color: Theme.textColor; font.pixelSize: 13 }
                        StyledSpinBox {
                            id: sbMes
                            from: 1; to: 12
                            value: (new Date()).getMonth() + 1
                            Layout.fillWidth: true
                        }

                        Label { text: "Año Histórico:"; color: Theme.textColor; font.pixelSize: 13 }
                        StyledSpinBox {
                            id: sbAnio
                            from: 2020; to: 2030
                            value: (new Date()).getFullYear()
                            Layout.fillWidth: true
                        }
                    }
                }

                StyledButton {
                    Layout.fillWidth: true
                    variant: "primary"
                    text: "⚡ Calcular Liquidación"
                    enabled: cbEmpleado.currentIndex >= 0
                    onClicked: {
                        var empId = cbEmpleado.currentValue !== undefined ? cbEmpleado.currentValue : -1
                        if (empId > 0) {
                            if (cbEmpleado.currentIndex >= 0)
                                root.employeeData = AppController.employeeModel.get(cbEmpleado.currentIndex)
                            root.companyData = AppController.getCompany()
                            var res = AppController.processLiquidation(empId, cbQuincena.currentText, txtFechaCalculo.text)
                            root.liquidationResult = res
                            if (res && res.errores && res.errores.length > 0) {
                                root.statusMsg = "⚠️ Se detectaron " + res.errores.length + " error(es) en la liquidación."
                            } else {
                                root.statusMsg = "Liquidación calculada con éxito."
                            }
                        } else {
                            root.statusMsg = "Seleccione un empleado válido."
                        }
                    }
                }

                StyledButton {
                    Layout.fillWidth: true
                    variant: "secondary"
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

                StyledButton {
                    Layout.fillWidth: true
                    variant: "secondary"
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
                    color: root.statusMsg.indexOf("⚠️") !== -1 ? "#EF4444" : Theme.accentColor
                    font.bold: root.statusMsg.indexOf("⚠️") !== -1
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
                                    Label { text: "Unidad"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                                    Label { text: "Base Imp."; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
                                    Label { text: "Monto ($)"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11; Layout.preferredWidth: 130; horizontalAlignment: Text.AlignRight }
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
                                    property bool isTotal: {
                                        if (isSep) return false;
                                        var c = (modelData["codigo"] || modelData["codigo_variable"] || "").toUpperCase();
                                        var d = (modelData["descripcion"] || "").toUpperCase();
                                        return c.indexOf("TOT_") === 0 || c.indexOf("TOTAL_") === 0 || c.indexOf("NETO") === 0 || d.indexOf("TOTAL") !== -1 || d.indexOf("NETO") !== -1;
                                    }
                                    property bool isVisibleInReceipt: {
                                        var v = modelData["visible_recibo"];
                                        return v === undefined || v === null || v === true || v === 1 || v === "1" || v === "true";
                                    }

                                    visible: isVisibleInReceipt
                                    Layout.fillWidth: isVisibleInReceipt
                                    height: isVisibleInReceipt ? (isSep ? 32 : (isTotal ? 40 : 36)) : 0
                                    color: isSep ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.15)
                                                 : (isTotal ? "#1E293B" : (index % 2 === 0 ? Qt.alpha("#ffffff", 0.02) : "transparent"))
                                    radius: 4
                                    border.color: isSep ? Theme.accentColor : (isTotal ? "#F59E0B" : "transparent")
                                    border.width: isSep ? 1 : (isTotal ? 1 : 0)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8; anchors.rightMargin: 8
                                        spacing: 8

                                        // Separator full banner title
                                        Label {
                                            visible: isSep
                                            text: "🔹  " + (modelData["descripcion"] || "SECCIÓN")
                                            color: Theme.accentColor
                                            font.bold: true
                                            font.pixelSize: 13
                                            Layout.fillWidth: true
                                        }

                                        // Regular concept columns
                                        Label {
                                            visible: !isSep
                                            text: modelData["codigo"] || modelData["codigo_variable"] || ""
                                            color: isTotal ? "#F59E0B" : Theme.accentColor; font.bold: true; font.family: "Monospace"; font.pixelSize: isTotal ? 13 : 12
                                            Layout.preferredWidth: 80; elide: Text.ElideRight
                                        }
                                        Label {
                                            visible: !isSep
                                            text: modelData["descripcion"] || ""
                                            color: isTotal ? "#F8FAFC" : Theme.textColor; font.bold: isTotal; font.pixelSize: isTotal ? 13 : 13
                                            Layout.fillWidth: true; elide: Text.ElideRight
                                        }
                                        Label {
                                            visible: !isSep
                                            text: formatNumber(modelData["unidad"], 2)
                                            color: isTotal ? "#F8FAFC" : "#94A3B8"; font.family: "Monospace"; font.pixelSize: isTotal ? 13 : 12
                                            Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight
                                        }
                                        Label {
                                            visible: !isSep
                                            text: formatMoney(modelData["base"])
                                            color: isTotal ? "#38BDF8" : "#94A3B8"; font.family: "Monospace"; font.pixelSize: isTotal ? 13 : 12
                                            Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight
                                        }
                                        Label {
                                            visible: !isSep
                                            property string sec: (modelData["seccion"] || "").toUpperCase()
                                            property bool isDesc: (sec === "DESCUENTO" || sec === "RECIBO" || sec === "RETENCION" || sec === "RETENCIONES" || sec === "DESCUENTOS")
                                            text: formatMoney(modelData["monto"])
                                            color: isTotal ? "#F59E0B" : (isDesc ? "#EF4444" : "#10B981"); font.bold: true; font.family: "Monospace"; font.pixelSize: isTotal ? 14 : 13
                                            Layout.preferredWidth: 130; horizontalAlignment: Text.AlignRight
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

    function formatNumber(val, decimals) {
        if (val === undefined || val === null || isNaN(val)) return "-";
        var num = Number(val);
        if (num === 0) return "-";
        var dec = (decimals !== undefined) ? decimals : 2;
        var parts = num.toFixed(dec).split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ".");
        return parts.join(",");
    }

    function formatMoney(val) {
        if (val === undefined || val === null || isNaN(val) || Number(val) === 0) return "-";
        return "$ " + formatNumber(val, 2);
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
