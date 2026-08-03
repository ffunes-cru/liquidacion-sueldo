import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

AppDialog {
    id: root

    property int cellId: -1
    property string esquemaCodigo: "MENSUAL"
    property string seccionCodigo: "REMUNERATIVO"
    property string tipoCalculo: "formula"
    property alias codigoVariable: txtCodigoVariable.text
    property alias descripcion: txtDescripcion.text
    property alias condicion: txtCondicion.text
    property alias formulaMonto: txtFormulaMonto.text
    property alias formulaUnidad: txtFormulaUnidad.text
    property alias formulaBase: txtFormulaBase.text
    property int orden: 10
    property alias simplePorcentaje: txtSimplePorcentaje.text
    property string simpleBaseVariable: ""
    property alias simpleMontoFijo: txtSimpleMontoFijo.text
    property alias visibleRecibo: chkVisibleRecibo.checked

    property var sectionsList: []

    signal conceptSaved()

    title: cellId > 0 ? "Editar Concepto #" + cellId : "Nuevo Concepto de Recibo"
    dialogWidth: 720
    dialogHeight: 540
    standardButtons: Dialog.Save | Dialog.Cancel

    onOpened: {
        sectionsList = AppController.listSections()
        var codes = []
        for (var i = 0; i < sectionsList.length; i++) {
            codes.push(sectionsList[i].codigo)
        }
        if (codes.length === 0) {
            codes = ["REMUNERATIVO", "NO_REMUNERATIVO", "DESCUENTO", "APORTE_PATRONAL"]
        }
        cbSeccion.model = codes

        for (var j = 0; j < cbSeccion.count; j++) {
            if (cbSeccion.textAt(j) === root.seccionCodigo) {
                cbSeccion.currentIndex = j
                break
            }
        }

        // Base variables model for ComboBox
        var varsList = AppController.getAvailableFormulaVariables(root.esquemaCodigo)
        var baseOpts = ["bruto", "total_remunerativo", "basico", "total_no_remunerativo"]
        for (var k = 0; k < varsList.length; k++) {
            var vCode = (varsList[k].code || "").toLowerCase()
            if (vCode !== "" && baseOpts.indexOf(vCode) === -1) {
                baseOpts.push(vCode)
            }
        }
        cbSimpleBaseVar.model = baseOpts

        var initBase = (root.simpleBaseVariable || "bruto").toLowerCase()
        cbSimpleBaseVar.editText = initBase
        for (var m = 0; m < cbSimpleBaseVar.count; m++) {
            if (cbSimpleBaseVar.textAt(m).toLowerCase() === initBase) {
                cbSimpleBaseVar.currentIndex = m
                break
            }
        }

        if (root.tipoCalculo === "porcentaje" || root.tipoCalculo === "simple") {
            cbTipoCalculo.currentIndex = 1
        } else if (root.tipoCalculo === "fijo") {
            cbTipoCalculo.currentIndex = 2
        } else {
            cbTipoCalculo.currentIndex = 0
        }
    }

    onAccepted: {
        var calcType = "formula"
        if (cbTipoCalculo.currentIndex === 1) calcType = "porcentaje"
        else if (cbTipoCalculo.currentIndex === 2) calcType = "fijo"

        var code = txtCodigoVariable.text.trim().toLowerCase()
        var desc = txtDescripcion.text.trim()
        var cond = txtCondicion.text.trim() || "1"
        var fMonto = txtFormulaMonto.text.trim()
        if (calcType === "formula" && fMonto === "") fMonto = "0.0"

        var baseVarVal = (cbTipoCalculo.currentIndex === 1) ? cbSimpleBaseVar.editText.trim().toLowerCase() : ""

        if (code !== "") {
            AppController.cellModel.saveCell(
                cellId > 0 ? cellId : 0,
                cbSeccion.currentText,
                code,
                desc !== "" ? desc : code,
                cond,
                txtFormulaUnidad.text.trim(),
                txtFormulaBase.text.trim(),
                fMonto,
                orden,
                esquemaCodigo,
                calcType,
                parseFloat(txtSimplePorcentaje.text) || 0.0,
                baseVarVal,
                parseFloat(txtSimpleMontoFijo.text) || 0.0,
                chkVisibleRecibo.checked
            )
            conceptSaved()
        }
    }

    contentItem: ScrollView {
        clip: true

        ColumnLayout {
            id: dialogColumn
            width: root.dialogWidth - 48
            spacing: 14

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 14

                Label { text: "Sección del Recibo:"; color: Theme.textColor; font.pixelSize: 13 }
                StyledComboBox {
                    id: cbSeccion
                    Layout.fillWidth: true
                    model: ["REMUNERATIVO", "NO_REMUNERATIVO", "DESCUENTO", "APORTE_PATRONAL"]
                }

                Label { text: "Código de Variable:"; color: Theme.textColor; font.pixelSize: 13 }
                StyledTextField {
                    id: txtCodigoVariable
                    placeholderText: "Ej: jubilacion (siempre minúsculas)"
                    Layout.fillWidth: true
                }

                Label { text: "Descripción:"; color: Theme.textColor; font.pixelSize: 13 }
                StyledTextField {
                    id: txtDescripcion
                    placeholderText: "Ej: Jubilación Ley 24.241"
                    Layout.fillWidth: true
                }

                Label { text: "Condición:"; color: Theme.textColor; font.pixelSize: 13 }
                FormulaInput {
                    id: txtCondicion
                    esquemaCodigo: root.esquemaCodigo
                    placeholderText: "1 (o expresión p.ej basico > 0)"
                    Layout.fillWidth: true
                }

                Label { text: "Modo de Cálculo:"; color: Theme.textColor; font.pixelSize: 13 }
                StyledComboBox {
                    id: cbTipoCalculo
                    Layout.fillWidth: true
                    model: ["Fórmula JavaScript (IDE)", "Porcentaje (%)", "Monto Fijo ($)"]
                }
            }

            // ── IDE Formula Editor ─────────────────────────────────
            ColumnLayout {
                visible: cbTipoCalculo.currentIndex === 0
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: "Fórmula Monto ($) — Expresión JS:"
                    color: Theme.accentColor
                    font.bold: true
                    font.pixelSize: 13
                }
                FormulaInput {
                    id: txtFormulaMonto
                    esquemaCodigo: root.esquemaCodigo
                    placeholderText: "Ej: basico * 0.11"
                    Layout.fillWidth: true
                }

                Label { text: "Fórmula Unidad / Cantidad:"; color: Theme.textColor; font.pixelSize: 13 }
                FormulaInput {
                    id: txtFormulaUnidad
                    esquemaCodigo: root.esquemaCodigo
                    placeholderText: "Ej: 11"
                    Layout.fillWidth: true
                }

                Label { text: "Fórmula Base Imponible:"; color: Theme.textColor; font.pixelSize: 13 }
                FormulaInput {
                    id: txtFormulaBase
                    esquemaCodigo: root.esquemaCodigo
                    placeholderText: "Ej: total_remunerativo"
                    Layout.fillWidth: true
                }
            }

            // ── Porcentaje (%) Mode ──────────────────────────────────
            GridLayout {
                visible: cbTipoCalculo.currentIndex === 1
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 14

                Label { text: "Porcentaje (%):"; color: Theme.textColor; font.pixelSize: 13 }
                PercentageField {
                    id: txtSimplePorcentaje
                    Layout.fillWidth: true
                }

                Label { text: "Variable Base:"; color: Theme.textColor; font.pixelSize: 13 }
                StyledComboBox {
                    id: cbSimpleBaseVar
                    Layout.fillWidth: true
                    editable: true
                    model: ["bruto", "total_remunerativo", "basico", "total_no_remunerativo"]
                }
            }

            // ── Monto Fijo ($) Mode ──────────────────────────────────
            GridLayout {
                visible: cbTipoCalculo.currentIndex === 2
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 14

                Label { text: "Monto Fijo ($):"; color: Theme.textColor; font.pixelSize: 13 }
                MoneyField {
                    id: txtSimpleMontoFijo
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledCheckBox {
                    id: chkVisibleRecibo
                    text: "Visible en la impresión del Recibo de Sueldo"
                    checked: true
                }
            }
        }
    }
}
