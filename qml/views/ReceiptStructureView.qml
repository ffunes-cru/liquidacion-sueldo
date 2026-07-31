import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"
import "../dialogs"

Item {
    id: root

    property string currentEsquema: "MENSUAL"
    property var sectionsList: []

    Component.onCompleted: {
        refreshSections()
        refreshCells()
    }

    function refreshSections() {
        sectionsList = AppController.listSections()
    }

    function refreshCells() {
        AppController.cellModel.esquemaCodigo = currentEsquema
        AppController.cellModel.refresh()
    }

    function openNewConceptDialog(secCode) {
        conceptDialog.cellId = -1
        conceptDialog.esquemaCodigo = currentEsquema
        conceptDialog.seccionCodigo = secCode || "REMUNERATIVO"
        conceptDialog.codigoVariable = ""
        conceptDialog.descripcion = ""
        conceptDialog.condicion = "1"
        conceptDialog.formulaMonto = ""
        conceptDialog.formulaUnidad = ""
        conceptDialog.formulaBase = ""
        conceptDialog.orden = (AppController.cellModel.count + 1) * 10
        conceptDialog.simplePorcentaje = "0.0"
        conceptDialog.simpleBaseVariable = ""
        conceptDialog.simpleMontoFijo = "0.0"
        conceptDialog.visibleRecibo = true
        conceptDialog.open()
    }

    function openEditConceptDialog(cellData) {
        conceptDialog.cellId = cellData.cellId
        conceptDialog.esquemaCodigo = currentEsquema
        conceptDialog.seccionCodigo = cellData.seccionCodigo
        conceptDialog.codigoVariable = cellData.codigoVariable || ""
        conceptDialog.descripcion = cellData.descripcion || ""
        conceptDialog.condicion = cellData.condicion || "1"
        conceptDialog.formulaMonto = cellData.formulaMonto || ""
        conceptDialog.formulaUnidad = cellData.formulaUnidad || ""
        conceptDialog.formulaBase = cellData.formulaBase || ""
        conceptDialog.orden = cellData.orden || 10
        conceptDialog.simplePorcentaje = (cellData.simplePorcentaje || 0.0).toString()
        conceptDialog.simpleBaseVariable = cellData.simpleBaseVariable || ""
        conceptDialog.simpleMontoFijo = (cellData.simpleMontoFijo || 0.0).toString()
        conceptDialog.visibleRecibo = cellData.visibleRecibo
        conceptDialog.open()
    }

    function getSectionColor(code) {
        if (code === "REMUNERATIVO") return "#a6e3a1"
        if (code === "NO_REMUNERATIVO") return "#89b4fa"
        if (code === "DESCUENTO") return "#f38ba8"
        if (code === "APORTE_PATRONAL") return "#fab387"
        return window.accentColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════════════
        // TOP CONTROL BAR
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 60
            color: window.panelBg
            radius: 8
            border.color: window.borderColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 15

                Label {
                    text: "Estructura del Recibo de Sueldo"
                    font.pixelSize: 18
                    font.bold: true
                    color: window.textColor
                }

                Label { text: "Esquema:"; color: window.textColor; font.pixelSize: 13 }
                ComboBox {
                    id: cbEsquema
                    model: AppController.schemaModel
                    textRole: "code"
                    onActivated: {
                        root.currentEsquema = currentText
                        root.refreshCells()
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "⚙️ Campos de Esquema"
                    onClicked: {
                        schemaConfigDialog.esquemaCodigo = root.currentEsquema
                        schemaConfigDialog.open()
                    }
                }

                Button {
                    text: "+ Nuevo Concepto"
                    highlighted: true
                    visible: AppController.currentRole === "admin"
                    onClicked: openNewConceptDialog("REMUNERATIVO")
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // LIVE DYNAMIC PAYSTUB DOCUMENT (SECCIONES DINÁMICAS)
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: window.panelBg
            radius: 8
            border.color: window.borderColor

            ScrollView {
                anchors.fill: parent
                anchors.margins: 15
                clip: true

                ColumnLayout {
                    width: parent.width - 30
                    spacing: 20

                    // Header Mockup
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 50
                        color: window.cardBg
                        radius: 6
                        border.color: window.borderColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 20

                            Label {
                                text: "DOCUMENTO MODELO: RECIBO DE SUELDO (" + root.currentEsquema + ")"
                                font.bold: true
                                font.pixelSize: 13
                                color: window.accentColor
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: AppController.cellModel.count + " líneas configuradas"
                                font.pixelSize: 12
                                color: window.subtextColor
                            }
                        }
                    }

                    // Table Header Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        color: "#181825"
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Label { text: "Orden"; font.bold: true; font.pixelSize: 11; color: window.subtextColor; Layout.preferredWidth: 60 }
                            Label { text: "Cód. Variable"; font.bold: true; font.pixelSize: 11; color: window.subtextColor; Layout.preferredWidth: 110 }
                            Label { text: "Descripción del Concepto"; font.bold: true; font.pixelSize: 11; color: window.subtextColor; Layout.fillWidth: true }
                            Label { text: "Unidad / Cant."; font.bold: true; font.pixelSize: 11; color: window.subtextColor; Layout.preferredWidth: 100 }
                            Label { text: "Base Imponible"; font.bold: true; font.pixelSize: 11; color: window.subtextColor; Layout.preferredWidth: 120 }
                            Label { text: "Fórmula / Cálculo Monto"; font.bold: true; font.pixelSize: 11; color: window.subtextColor; Layout.preferredWidth: 160 }
                            Label { text: "Acciones"; font.bold: true; font.pixelSize: 11; color: window.subtextColor; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                        }
                    }

                    // ── Dynamic Paystub Sections Repeater ───────────────────
                    Repeater {
                        model: root.sectionsList.length > 0 ? root.sectionsList : [
                            { codigo: "REMUNERATIVO", titulo: "HABERES REMUNERATIVOS (Con Aporte)" },
                            { codigo: "NO_REMUNERATIVO", titulo: "HABERES NO REMUNERATIVOS (Sin Aporte)" },
                            { codigo: "DESCUENTO", titulo: "RETENCIONES Y DESCUENTOS" },
                            { codigo: "APORTE_PATRONAL", titulo: "APORTES PATRONALES (Contribuciones)" }
                        ]

                        delegate: PaystubSectionBlock {
                            sectionTitle: modelData.titulo || modelData.codigo
                            sectionCode: modelData.codigo
                            sectionColor: root.getSectionColor(modelData.codigo)
                            esquemaCodigo: root.currentEsquema
                            onAddRequested: openNewConceptDialog(modelData.codigo)
                            onEditRequested: function(cellData) { openEditConceptDialog(cellData) }
                        }
                    }
                }
            }
        }
    }

    // ── Dialog Modals ───────────────────────────────────────────────
    ConceptDialog {
        id: conceptDialog
        onConceptSaved: root.refreshCells()
    }

    SchemaConfigDialog {
        id: schemaConfigDialog
    }
}
