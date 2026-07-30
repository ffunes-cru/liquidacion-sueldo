import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property var liquidationResult: null
    property int selectedEmployeeId: -1
    property string statusMsg: ""

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════════════
        // LEFT PANE: Calculation Parameters & Actions
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 360
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
                    implicitHeight: paramGrid.implicitHeight + 20
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
                    text: "💾 Guardar en Historial de Recibos"
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
        // RIGHT PANE: Liquidated Receipt Preview Card
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
                    spacing: 15

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Vista Previa del Recibo de Sueldo"
                            font.pixelSize: 18
                            font.bold: true
                            color: window.textColor
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // Summary KPI Cards
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Total Remunerativo
                        Rectangle {
                            Layout.fillWidth: true
                            height: 70
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
                            height: 70
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
                            height: 70
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

                    // Concepts Breakdown Table
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: conceptListColumn.implicitHeight + 20
                        color: window.cardBg
                        radius: 6
                        border.color: window.borderColor

                        ColumnLayout {
                            id: conceptListColumn
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Concepto / Descripción"; font.bold: true; color: window.subtextColor; Layout.fillWidth: true; font.pixelSize: 12 }
                                Label { text: "Unidad"; font.bold: true; color: window.subtextColor; Layout.preferredWidth: 60; font.pixelSize: 12 }
                                Label { text: "Base Imponible"; font.bold: true; color: window.subtextColor; Layout.preferredWidth: 100; font.pixelSize: 12 }
                                Label { text: "Haberes ($)"; font.bold: true; color: window.subtextColor; Layout.preferredWidth: 100; font.pixelSize: 12 }
                                Label { text: "Descuentos ($)"; font.bold: true; color: window.subtextColor; Layout.preferredWidth: 100; font.pixelSize: 12 }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: window.borderColor }

                            Repeater {
                                model: root.liquidationResult ? root.liquidationResult["conceptos"] : []
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Label {
                                        text: modelData["descripcion"] + " (" + modelData["codigo_variable"] + ")"
                                        color: window.textColor
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        text: modelData["unidad"] !== undefined ? Number(modelData["unidad"]).toFixed(2) : ""
                                        color: window.subtextColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 60
                                    }

                                    Label {
                                        text: modelData["base"] !== undefined && modelData["base"] > 0 ? "$ " + Number(modelData["base"]).toFixed(2) : ""
                                        color: window.subtextColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Label {
                                        text: modelData["seccion"] === "REMUNERATIVO" || modelData["seccion"] === "NO_REMUNERATIVO" ? "$ " + Number(modelData["monto"]).toFixed(2) : ""
                                        color: "#a6e3a1"
                                        font.bold: true
                                        font.pixelSize: 13
                                        Layout.preferredWidth: 100
                                    }

                                    Label {
                                        text: modelData["seccion"] === "DESCUENTO" ? "$ " + Number(modelData["monto"]).toFixed(2) : ""
                                        color: "#f38ba8"
                                        font.bold: true
                                        font.pixelSize: 13
                                        Layout.preferredWidth: 100
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
