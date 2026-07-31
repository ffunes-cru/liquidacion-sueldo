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
    property alias codigoVariable: txtCodigoVariable.text
    property alias descripcion: txtDescripcion.text
    property alias condicion: txtCondicion.text
    property alias formulaMonto: txtFormulaMonto.text
    property alias formulaUnidad: txtFormulaUnidad.text
    property alias formulaBase: txtFormulaBase.text
    property int orden: 10
    property alias simplePorcentaje: txtSimplePorcentaje.text
    property alias simpleBaseVariable: txtSimpleBaseVar.text
    property alias simpleMontoFijo: txtSimpleMontoFijo.text
    property alias visibleRecibo: chkVisibleRecibo.checked

    property var sectionsList: []

    signal conceptSaved()

    title: cellId > 0 ? "Editar Concepto #" + cellId : "Nuevo Concepto de Recibo"
    dialogWidth: 620
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
    }

    onAccepted: {
        var calcType = (cbTipoCalculo.currentIndex === 1) ? "simple" : "formula"
        var code = txtCodigoVariable.text.trim().toUpperCase()
        var desc = txtDescripcion.text.trim()
        var cond = txtCondicion.text.trim() || "1"
        var fMonto = txtFormulaMonto.text.trim()
        if (calcType === "formula" && fMonto === "") fMonto = "0.0"

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
                txtSimpleBaseVar.text.trim(),
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
            width: root.dialogWidth - 40
            spacing: 12

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 12

                Label { text: "Sección del Recibo:"; color: Theme.textColor; font.pixelSize: 13 }
                ComboBox {
                    id: cbSeccion
                    Layout.fillWidth: true
                    model: ["REMUNERATIVO", "NO_REMUNERATIVO", "DESCUENTO", "APORTE_PATRONAL"]
                }

                Label { text: "Código de Concepto:"; color: Theme.textColor; font.pixelSize: 13 }
                StyledTextField {
                    id: txtCodigoVariable
                    placeholderText: "Ej: JUBILACION"
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
                ComboBox {
                    id: cbTipoCalculo
                    Layout.fillWidth: true
                    model: ["Fórmula Completa (IDE)", "Simplificado (% / Fijo)"]
                }
            }

            // ── IDE Formula Editor ─────────────────────────────────
            ColumnLayout {
                visible: cbTipoCalculo.currentIndex === 0
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: "Fórmula Monto ($) — Con Autocompletado IDE:"
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

            // ── Simple Calculator ──────────────────────────────────
            GridLayout {
                visible: cbTipoCalculo.currentIndex === 1
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 10

                Label { text: "Porcentaje (%):"; color: Theme.textColor; font.pixelSize: 13 }
                PercentageField {
                    id: txtSimplePorcentaje
                    Layout.fillWidth: true
                }

                Label { text: "Variable Base:"; color: Theme.textColor; font.pixelSize: 13 }
                FormulaInput {
                    id: txtSimpleBaseVar
                    esquemaCodigo: root.esquemaCodigo
                    placeholderText: "total_remunerativo"
                    Layout.fillWidth: true
                }

                Label { text: "Monto Fijo ($):"; color: Theme.textColor; font.pixelSize: 13 }
                MoneyField {
                    id: txtSimpleMontoFijo
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                CheckBox {
                    id: chkVisibleRecibo
                    text: "Visible en la impresión del Recibo de Sueldo"
                    checked: true
                }
            }
        }
    }
}
