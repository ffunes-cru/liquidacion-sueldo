import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property int selectedCellId: -1
    property int selectedRow: -1

    Component.onCompleted: {
        AppController.cellModel.refresh()
    }

    function clearForm() {
        selectedRow = -1
        selectedCellId = -1
        txtCodigoVariable.text = ""
        txtDescripcion.text = ""
        txtCondicion.text = ""
        txtFormulaUnidad.text = ""
        txtFormulaBase.text = ""
        txtFormulaMonto.text = ""
        cbTipoCalculo.currentIndex = 0
        txtSimplePorcentaje.text = "0.0"
        txtSimpleBaseVar.text = ""
        txtSimpleMontoFijo.text = "0.0"
        sbOrden.value = (AppController.cellModel.count + 1) * 10
        chkVisibleRecibo.checked = true
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════════════
        // LEFT PANE: Filter & Calculation Cells List
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 460
            color: window.panelBg
            radius: 8
            border.color: window.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Celdas de Cálculo"
                        font.pixelSize: 16
                        font.bold: true
                        color: window.textColor
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: AppController.cellModel.count + " celdas"
                        font.pixelSize: 12
                        color: window.subtextColor
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Label {
                        text: "Esquema:"
                        color: window.textColor
                        font.pixelSize: 13
                    }
                    ComboBox {
                        id: cbFilterSchema
                        Layout.fillWidth: true
                        model: AppController.schemaModel
                        textRole: "code"
                        onActivated: {
                            AppController.cellModel.esquemaCodigo = currentText
                        }
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: cellListView
                        model: AppController.cellModel
                        spacing: 6

                        delegate: Rectangle {
                            width: cellListView.width
                            height: 65
                            radius: 6
                            color: root.selectedCellId === model.cellId ? (window.isDark ? "#3b3b58" : "#e4e4e9") :
                                   (mouseArea.containsMouse ? (window.isDark ? "#303045" : "#f0f0f5") : window.cardBg)
                            border.color: root.selectedCellId === model.cellId ? window.accentColor : window.borderColor
                            border.width: 1

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.selectedCellId = model.cellId
                                    root.selectedRow = index
                                    txtCodigoVariable.text = model.codigoVariable || ""
                                    txtDescripcion.text = model.descripcion || ""
                                    txtCondicion.text = model.condicion || ""
                                    txtFormulaUnidad.text = model.formulaUnidad || ""
                                    txtFormulaBase.text = model.formulaBase || ""
                                    txtFormulaMonto.text = model.formulaMonto || ""
                                    sbOrden.value = model.orden || 0
                                    chkVisibleRecibo.checked = model.visibleRecibo

                                    // Seccion Combo
                                    for (var i = 0; i < cbSeccion.count; i++) {
                                        if (cbSeccion.textAt(i) === model.seccionCodigo) {
                                            cbSeccion.currentIndex = i
                                            break
                                        }
                                    }
                                    // Tipo Calculo Combo
                                    cbTipoCalculo.currentIndex = (model.tipoCalculo === "simple") ? 1 : 0
                                    txtSimplePorcentaje.text = (model.simplePorcentaje || 0.0).toString()
                                    txtSimpleBaseVar.text = model.simpleBaseVariable || ""
                                    txtSimpleMontoFijo.text = (model.simpleMontoFijo || 0.0).toString()
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: model.seccionCodigo === "REMUNERATIVO" ? "#a6e3a1" :
                                           (model.seccionCodigo === "DESCUENTO" ? "#f38ba8" :
                                           (model.seccionCodigo === "APORTE_PATRONAL" ? "#fab387" : "#89b4fa"))

                                    Label {
                                        anchors.centerIn: parent
                                        text: model.seccionCodigo.substring(0, 1)
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: "#11111b"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Label {
                                            text: model.descripcion
                                            font.bold: true
                                            font.pixelSize: 13
                                            color: window.textColor
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Label {
                                            text: "[" + model.codigoVariable + "]"
                                            font.pixelSize: 12
                                            color: window.accentColor
                                        }
                                    }

                                    RowLayout {
                                        Label {
                                            text: "Sec: " + model.seccionCodigo
                                            font.pixelSize: 11
                                            color: window.subtextColor
                                        }
                                        Label { text: "•"; font.pixelSize: 10; color: window.subtextColor }
                                        Label {
                                            text: "Ord: " + model.orden
                                            font.pixelSize: 11
                                            color: window.subtextColor
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        Layout.fillWidth: true
                        text: "Nueva Celda"
                        visible: AppController.currentRole === "admin"
                        onClicked: {
                            root.clearForm()
                            txtCodigoVariable.forceActiveFocus()
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: "Eliminar"
                        visible: AppController.currentRole === "admin"
                        enabled: root.selectedCellId > 0
                        onClicked: {
                            if (root.selectedCellId > 0) {
                                AppController.cellModel.removeCell(root.selectedCellId)
                                root.clearForm()
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // RIGHT PANE: Concept/Cell Editor Form
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
                    spacing: 12

                    Label {
                        text: root.selectedCellId > 0 ? "Editar Celda de Cálculo #" + root.selectedCellId : "Nueva Celda de Cálculo"
                        font.pixelSize: 18
                        font.bold: true
                        color: window.textColor
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: cellGrid.implicitHeight + 20
                        color: window.cardBg
                        radius: 6
                        border.color: window.borderColor

                        GridLayout {
                            id: cellGrid
                            anchors.fill: parent
                            anchors.margins: 12
                            columns: 4
                            rowSpacing: 10
                            columnSpacing: 12

                            Label { text: "Esquema:"; color: window.textColor; font.pixelSize: 13 }
                            ComboBox {
                                id: cbEsquema
                                Layout.fillWidth: true
                                model: AppController.schemaModel
                                textRole: "code"
                            }

                            Label { text: "Sección:"; color: window.textColor; font.pixelSize: 13 }
                            ComboBox {
                                id: cbSeccion
                                Layout.fillWidth: true
                                model: ["REMUNERATIVO", "DESCUENTO", "APORTE_PATRONAL", "NO_REMUNERATIVO"]
                            }

                            Label { text: "Cód. Variable:"; color: window.textColor; font.pixelSize: 13 }
                            TextField {
                                id: txtCodigoVariable
                                placeholderText: "Ej: JUBILACION"
                                Layout.fillWidth: true
                                color: window.textColor
                            }

                            Label { text: "Descripción:"; color: window.textColor; font.pixelSize: 13 }
                            TextField {
                                id: txtDescripcion
                                placeholderText: "Ej: Jubilación Ley 24.241"
                                Layout.fillWidth: true
                                color: window.textColor
                            }

                            Label { text: "Condición:"; color: window.textColor; font.pixelSize: 13 }
                            TextField {
                                id: txtCondicion
                                placeholderText: "1 (o expresión p.ej basico > 0)"
                                Layout.fillWidth: true
                                color: window.textColor
                                Layout.columnSpan: 3
                            }

                            Label { text: "Tipo Cálculo:"; color: window.textColor; font.pixelSize: 13 }
                            ComboBox {
                                id: cbTipoCalculo
                                Layout.fillWidth: true
                                model: ["Fórmula Completa (Fórmula)", "Simple (% / Fijo)"]
                            }

                            Label { text: "Orden:"; color: window.textColor; font.pixelSize: 13 }
                            SpinBox {
                                id: sbOrden
                                from: 1
                                to: 9999
                                value: 100
                                stepSize: 10
                                editable: true
                            }

                            Label { text: "Visible en Recibo:"; color: window.textColor; font.pixelSize: 13 }
                            CheckBox {
                                id: chkVisibleRecibo
                                checked: true
                            }
                        }
                    }

                    // ── Formula or Simple Calculator Details ──────────────
                    Label {
                        text: cbTipoCalculo.currentIndex === 0 ? "Fórmulas C++ / ExprTk" : "Configuración Simplificada"
                        font.pixelSize: 14
                        font.bold: true
                        color: window.accentColor
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: formulaColumn.implicitHeight + 20
                        color: window.cardBg
                        radius: 6
                        border.color: window.borderColor

                        ColumnLayout {
                            id: formulaColumn
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            // Formula layout
                            ColumnLayout {
                                visible: cbTipoCalculo.currentIndex === 0
                                Layout.fillWidth: true
                                spacing: 8

                                Label { text: "Fórmula Monto ($):"; color: window.textColor; font.pixelSize: 13 }
                                TextField {
                                    id: txtFormulaMonto
                                    placeholderText: "Ej: basico * 0.11"
                                    Layout.fillWidth: true
                                    color: window.textColor
                                }

                                Label { text: "Fórmula Unidad / Cantidad:"; color: window.textColor; font.pixelSize: 13 }
                                TextField {
                                    id: txtFormulaUnidad
                                    placeholderText: "Ej: 11"
                                    Layout.fillWidth: true
                                    color: window.textColor
                                }

                                Label { text: "Fórmula Base Imponible:"; color: window.textColor; font.pixelSize: 13 }
                                TextField {
                                    id: txtFormulaBase
                                    placeholderText: "Ej: basico"
                                    Layout.fillWidth: true
                                    color: window.textColor
                                }
                            }

                            // Simple Layout
                            GridLayout {
                                visible: cbTipoCalculo.currentIndex === 1
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 10
                                columnSpacing: 10

                                Label { text: "Porcentaje (%):"; color: window.textColor; font.pixelSize: 13 }
                                TextField {
                                    id: txtSimplePorcentaje
                                    placeholderText: "11.0"
                                    Layout.fillWidth: true
                                    color: window.textColor
                                }

                                Label { text: "Variable Base:"; color: window.textColor; font.pixelSize: 13 }
                                TextField {
                                    id: txtSimpleBaseVar
                                    placeholderText: "total_remunerativo"
                                    Layout.fillWidth: true
                                    color: window.textColor
                                }

                                Label { text: "Monto Fijo ($):"; color: window.textColor; font.pixelSize: 13 }
                                TextField {
                                    id: txtSimpleMontoFijo
                                    placeholderText: "0.0"
                                    Layout.fillWidth: true
                                    color: window.textColor
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Guardar Celda de Cálculo"
                            highlighted: true
                            visible: AppController.currentRole === "admin"
                            onClicked: {
                                var schemaCode = cbEsquema.currentText || "MENSUAL"
                                var secCode = cbSeccion.currentText || "REMUNERATIVO"
                                var calcType = (cbTipoCalculo.currentIndex === 1) ? "simple" : "formula"

                                if (txtCodigoVariable.text.trim() !== "") {
                                    AppController.cellModel.saveCell(
                                        root.selectedCellId > 0 ? root.selectedCellId : 0,
                                        secCode,
                                        txtCodigoVariable.text.trim(),
                                        txtDescripcion.text.trim(),
                                        txtCondicion.text.trim(),
                                        txtFormulaUnidad.text.trim(),
                                        txtFormulaBase.text.trim(),
                                        txtFormulaMonto.text.trim(),
                                        sbOrden.value,
                                        schemaCode,
                                        calcType,
                                        parseFloat(txtSimplePorcentaje.text) || 0.0,
                                        txtSimpleBaseVar.text.trim(),
                                        parseFloat(txtSimpleMontoFijo.text) || 0.0,
                                        chkVisibleRecibo.checked
                                    )
                                    root.clearForm()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
