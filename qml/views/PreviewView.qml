import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"
import "../dialogs"

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

    EmployeeSelectorDialog {
        id: employeeSelectorDialog
        onEmployeeSelected: function(empId, empData) {
            root.selectedEmployeeId = empId
            root.employeeData = empData
            root.refreshQuincenasCombo(empId)
        }
    }

    ConfirmDialog {
        id: confirmHistoryDialog
        title: "💾 Guardar en Historial"
        iconText: "ℹ️"
        message: "¿Desea guardar una copia instantánea de este recibo de sueldo en el historial de liquidaciones?"
        confirmButtonText: "Sí, Guardar Recibo"
        confirmButtonVariant: "primary"
        onConfirmed: {
            if (root.liquidationResult) {
                var qText = ((root.employeeData && (root.employeeData.tipoLiquidacion || root.employeeData.tipo_liquidacion) === "jornal") ? (" (" + cbQuincena.currentText + ")") : "")
                var periodoStr = "Mes " + dpFechaCalculo.selectedMonth + "/" + dpFechaCalculo.selectedYear + qText
                var recId = AppController.persistLiquidation(root.liquidationResult, dpFechaCalculo.selectedMonth, dpFechaCalculo.selectedYear, periodoStr)
                root.statusMsg = recId > 0 ? "Recibo histórico guardado con ID #" + recId : "Error al guardar en el historial."
                if (recId > 0) AppController.receiptHistoryModel.refresh()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════
        // TOP SELECTION & PARAMETERS BAR
        // ═══════════════════════════════════════════════════════
        SectionPanel {
            Layout.fillWidth: true
            padding: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Employee Selector Button
                StyledButton {
                    id: btnSelectEmployee
                    variant: "secondary"
                    text: root.employeeData ? ("👤 " + (root.employeeData.nombre || root.employeeData.nombre_completo) + " (Leg. " + (root.employeeData.legajo || "-") + ")") : "🔍 Seleccionar Empleado..."
                    onClicked: employeeSelectorDialog.open()
                }

                // Quincena (For Hourly/Jornal employees)
                Label {
                    text: "Quincena:"
                    color: Theme.textColor
                    font.pixelSize: 13
                    visible: root.employeeData && ((root.employeeData.tipoLiquidacion || root.employeeData.tipo_liquidacion) === "jornal")
                }
                StyledComboBox {
                    id: cbQuincena
                    Layout.preferredWidth: 110
                    model: ["Q1", "Q2"]
                    visible: root.employeeData && ((root.employeeData.tipoLiquidacion || root.employeeData.tipo_liquidacion) === "jornal")
                }

                // Fecha Cálculo (Única)
                Label { text: "Fecha:"; color: Theme.textColor; font.pixelSize: 13 }
                StyledDatePicker {
                    id: dpFechaCalculo
                    Layout.preferredWidth: 145
                }

                Item { Layout.fillWidth: true }

                // Actions
                StyledButton {
                    variant: "primary"
                    text: "⚡ Calcular"
                    enabled: root.selectedEmployeeId > 0
                    onClicked: {
                        var empId = root.selectedEmployeeId
                        if (empId > 0) {
                            root.companyData = AppController.getCompany()
                            var res = AppController.processLiquidation(empId, cbQuincena.currentText, dpFechaCalculo.formattedDate)
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
                    variant: "secondary"
                    text: "💾 Historial"
                    enabled: root.liquidationResult !== null
                    onClicked: confirmHistoryDialog.open()
                }

                StyledButton {
                    variant: "secondary"
                    text: "📄 Exportar PDF"
                    enabled: root.liquidationResult !== null
                    onClicked: {
                        var empId = root.selectedEmployeeId
                        if (empId > 0 && root.liquidationResult) {
                            var legajo = (root.employeeData ? (root.employeeData.legajo || empId) : empId)
                            var defaultName = "recibo_legajo_" + legajo + "_" + dpFechaCalculo.selectedMonth + "_" + dpFechaCalculo.selectedYear + ".pdf"
                            var savePath = AppController.selectSaveFile("Guardar Recibo de Sueldo PDF", defaultName, "Archivos PDF (*.pdf)")
                            if (savePath !== "") {
                                var pdfPath = AppController.exportReceiptPdf(empId, root.liquidationResult, savePath)
                                root.statusMsg = pdfPath !== "" ? "Recibo PDF guardado exitosamente en: " + pdfPath : "Error al generar PDF."
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════
        // MAIN PANE: Paystub Preview Document
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
                            text: root.liquidationResult ? ("Esquema: " + (root.employeeData ? (root.employeeData.esquema || root.employeeData.esquema_codigo || "") : "")) : "Sin Calcular"
                            font.pixelSize: 12; color: Theme.accentColor
                        }
                    }

                    // Document Header Card
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
                                ColumnLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignRight
                                    Label {
                                        text: "RECIBO DE HABERES"
                                        font.bold: true; font.pixelSize: 14; color: Theme.accentColor
                                    }
                                    Label {
                                        text: "Fecha: " + dpFechaCalculo.displayDate
                                        font.pixelSize: 11; color: Theme.subtextColor
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderColor }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                rowSpacing: 6
                                columnSpacing: 15

                                Label { text: "Empleado:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11 }
                                Label {
                                    text: root.employeeData ? (root.employeeData.nombre || root.employeeData.nombre_completo || "-") : "-"
                                    font.bold: true; color: Theme.textColor; font.pixelSize: 12
                                }

                                Label { text: "Legajo:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11 }
                                Label {
                                    text: root.employeeData ? (root.employeeData.legajo || "-") : "-"
                                    color: Theme.textColor; font.pixelSize: 12
                                }

                                Label { text: "C.U.I.T.:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11 }
                                Label {
                                    text: root.employeeData ? (root.employeeData.cuil || "N/A") : "-"
                                    color: Theme.textColor; font.pixelSize: 12
                                }

                                Label { text: "Fecha Ingreso:"; font.bold: true; color: Theme.subtextColor; font.pixelSize: 11 }
                                Label {
                                    text: root.employeeData ? (root.employeeData.fechaIngreso || root.employeeData.fecha_ingreso || "N/A") : "-"
                                    color: Theme.textColor; font.pixelSize: 12
                                }
                            }
                        }
                    }

                    // Table Header Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        color: Theme.headerBg
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 10

                            Label { text: "Cód."; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 80 }
                            Label { text: "Concepto / Descripción"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.fillWidth: true }
                            Label { text: "Unidad"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                            Label { text: "Base Imponible"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
                            Label { text: "Monto ($)"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 130; horizontalAlignment: Text.AlignRight }
                        }
                    }

                    // Table Body Lines
                    SectionPanel {
                        padding: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: root.liquidationResult ? root.liquidationResult.conceptos : []

                                delegate: Item {
                                    Layout.fillWidth: true
                                    property bool isSep: modelData["tipo_calculo"] === "separator" || (modelData["codigo"] && modelData["codigo"].indexOf("SEP_") === 0)
                                    property bool isTotal: (!isSep && (modelData["codigo"].indexOf("TOT_") === 0 || modelData["codigo"].indexOf("TOTAL_") === 0 || modelData["codigo"].indexOf("NETO") === 0 || modelData["descripcion"].toUpperCase().indexOf("TOTAL") !== -1 || modelData["descripcion"].toUpperCase().indexOf("NETO") !== -1))
                                    implicitHeight: isSep ? 34 : 38

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: isSep ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.15) : (isTotal ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.25) : (index % 2 === 0 ? Theme.panelBg : Theme.cardBg))
                                        border.color: isTotal ? Theme.accentColor : (isSep ? Theme.accentColor : "transparent")
                                        border.width: isTotal ? 1.5 : (isSep ? 1 : 0)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12; anchors.rightMargin: 12
                                            spacing: 10

                                            // Separator Header
                                            Label {
                                                visible: isSep
                                                text: "■  " + (modelData["descripcion"] || "").toUpperCase()
                                                font.bold: true; font.pixelSize: 12; color: Theme.accentColor
                                                Layout.fillWidth: true
                                            }

                                            // Concept Regular Row
                                            Label {
                                                visible: !isSep
                                                text: modelData["codigo"] || ""
                                                font.family: "Monospace"; font.pixelSize: 11; color: Theme.subtextColor
                                                Layout.preferredWidth: 80; elide: Text.ElideRight
                                            }
                                            Label {
                                                visible: !isSep
                                                text: modelData["descripcion"] || ""
                                                color: isTotal ? Theme.accentColor : Theme.textColor; font.bold: isTotal; font.pixelSize: isTotal ? 13 : 13
                                                Layout.fillWidth: true; elide: Text.ElideRight
                                            }
                                            Label {
                                                visible: !isSep
                                                text: {
                                                    var tc = (modelData["tipo_calculo"] || "").toLowerCase();
                                                    var isPct = (tc === "porcentaje" || tc === "percentage" || tc === "simple" || (Number(modelData["simple_porcentaje"]) > 0));
                                                    var uVal = Number(modelData["unidad"]);
                                                    var sPct = Number(modelData["simple_porcentaje"]);
                                                    if (isPct && uVal > 0) return "% " + root.formatNumber(uVal, 2);
                                                    if (isPct && sPct > 0) return "% " + root.formatNumber(sPct, 2);
                                                    if (uVal !== 0 && !isNaN(uVal)) return root.formatNumber(uVal, 4);
                                                    return "-";
                                                }
                                                color: Theme.subtextColor; font.family: "Monospace"; font.pixelSize: 12
                                                Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight
                                            }
                                            Label {
                                                visible: !isSep
                                                text: {
                                                    if (isTotal) return "";
                                                    var bVal = Number(modelData["base"]);
                                                    if (bVal > 0) return root.formatMoney(bVal, 2);
                                                    return "-";
                                                }
                                                color: Theme.subtextColor; font.family: "Monospace"; font.pixelSize: 12
                                                Layout.preferredWidth: 120; horizontalAlignment: Text.AlignRight
                                            }
                                            Label {
                                                visible: !isSep
                                                text: root.formatMoney(modelData["monto"], 4)
                                                color: isTotal ? Theme.accentColor : Theme.textColor; font.bold: true; font.family: "Monospace"; font.pixelSize: isTotal ? 14 : 13
                                                Layout.preferredWidth: 140; horizontalAlignment: Text.AlignRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PieChartCanvas {
                        id: previewPieChart
                        Layout.fillWidth: true
                        visible: root.liquidationResult !== null && slices && slices.length > 0
                        slices: root.getChartSlices()
                        totalReference: root.getChartTotalReference()
                    }
                }
            }
        }
    }

    function formatNumber(val, maxDecimals) {
        if (val === undefined || val === null || isNaN(val)) return "-";
        var num = Number(val);
        if (num === 0) return "-";
        var maxDec = (maxDecimals !== undefined) ? maxDecimals : 4;
        var str = num.toFixed(maxDec);
        if (str.indexOf(".") !== -1) {
            str = str.replace(/\.?0+$/, "");
            if (str.indexOf(".") !== -1) {
                var p = str.split(".");
                p[0] = p[0].replace(/\B(?=(\d{3})+(?!\d))/g, ".");
                if (p[1].length < 2) p[1] = (p[1] + "00").substring(0, 2);
                return p.join(",");
            }
        }
        return str.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
    }

    function formatMoney(val, maxDecimals) {
        if (val === undefined || val === null || isNaN(val) || Number(val) === 0) return "-";
        return "$ " + formatNumber(val, maxDecimals !== undefined ? maxDecimals : 4);
    }

    function refreshQuincenasCombo(empId) {
        if (empId > 0) {
            var list = AppController.listEmployeeQuincenas(empId)
            cbQuincena.model = (list && list.length > 0) ? list : ["Q1", "Q2"]
        } else {
            cbQuincena.model = ["Q1", "Q2"]
        }
    }

    function getChartSlices() {
        if (!root.liquidationResult || !root.liquidationResult.conceptos) return [];
        var res = [];
        var conceptos = root.liquidationResult.conceptos;
        for (var i = 0; i < conceptos.length; i++) {
            var c = conceptos[i];
            var inChart = c.en_grafico === true || c.en_grafico === 1 || c.en_grafico === "1";
            if (!inChart) {
                var code = (c.codigo || c.codigo_variable || "").toLowerCase();
                for (var j = 0; j < AppController.cellModel.count; j++) {
                    var cell = AppController.cellModel.get(j);
                    if ((cell.codigoVariable || "").toLowerCase() === code) {
                        inChart = cell.enGrafico;
                        if (!c.color_hex && cell.colorHex) c.color_hex = cell.colorHex;
                        break;
                    }
                }
            }
            if (inChart) {
                var mVal = Math.abs(Number(c.monto) || 0);
                if (mVal > 0) {
                    res.push({
                        label: c.descripcion || c.codigo || c.codigo_variable,
                        value: mVal,
                        color: c.color_hex ? c.color_hex : undefined
                    });
                }
            }
        }
        return res;
    }

    function getChartTotalReference() {
        if (!root.liquidationResult || !root.liquidationResult.conceptos) return 0.0;
        var conceptos = root.liquidationResult.conceptos;
        for (var i = 0; i < conceptos.length; i++) {
            var c = conceptos[i];
            var isTotalRef = c.es_grafico_total === true || c.es_grafico_total === 1 || c.es_grafico_total === "1";
            if (!isTotalRef) {
                var code = (c.codigo || c.codigo_variable || "").toLowerCase();
                for (var j = 0; j < AppController.cellModel.count; j++) {
                    var cell = AppController.cellModel.get(j);
                    if ((cell.codigoVariable || "").toLowerCase() === code) {
                        isTotalRef = cell.esGraficoTotal;
                        break;
                    }
                }
            }
            if (isTotalRef) {
                return Math.abs(Number(c.monto) || 0.0);
            }
        }
        return 0.0;
    }
}
