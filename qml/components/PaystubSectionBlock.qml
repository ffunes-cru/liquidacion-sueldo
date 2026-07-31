import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

ColumnLayout {
    id: root

    property string sectionTitle: "SECCIÓN"
    property string sectionCode: "REMUNERATIVO"
    property color sectionColor: "#a6e3a1"
    property string esquemaCodigo: "MENSUAL"

    signal addRequested()
    signal editRequested(var cellData)

    Layout.fillWidth: true
    spacing: 8

    // Section Title Header Banner
    Rectangle {
        Layout.fillWidth: true
        height: 32
        color: Qt.darker(root.sectionColor, 3.0)
        radius: 4
        border.color: root.sectionColor
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: root.sectionColor
            }

            Label {
                text: root.sectionTitle
                font.bold: true
                font.pixelSize: 13
                color: root.sectionColor
            }

            Item { Layout.fillWidth: true }

            Button {
                implicitHeight: 24
                text: "+ Agregar"
                flat: true
                visible: AppController.currentRole === "admin"
                onClicked: root.addRequested()
            }
        }
    }

    // Concept Lines Repeater
    Repeater {
        model: AppController.cellModel

        delegate: Item {
            Layout.fillWidth: true
            implicitHeight: model.seccionCodigo === root.sectionCode ? 46 : 0
            visible: model.seccionCodigo === root.sectionCode

            Rectangle {
                anchors.fill: parent
                color: mouseArea.containsMouse ? (window.isDark ? "#2a2a3e" : "#f0f0f8") : window.cardBg
                radius: 6
                border.color: window.borderColor
                border.width: 1

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Graphical Reorder Buttons (▲ ▼) - NO SPINBOX NUMBERS!
                    ColumnLayout {
                        spacing: 0
                        visible: AppController.currentRole === "admin"

                        Button {
                            implicitWidth: 20
                            implicitHeight: 18
                            text: "▲"
                            flat: true
                            onClicked: AppController.cellModel.moveCellUp(index)
                        }
                        Button {
                            implicitWidth: 20
                            implicitHeight: 18
                            text: "▼"
                            flat: true
                            onClicked: AppController.cellModel.moveCellDown(index)
                        }
                    }

                    // Concept Code Pill Badge
                    Rectangle {
                        implicitWidth: 100
                        implicitHeight: 26
                        radius: 4
                        color: window.inputBg
                        border.color: window.accentColor

                        Label {
                            anchors.centerIn: parent
                            text: model.codigoVariable
                            font.family: "Monospace"
                            font.bold: true
                            font.pixelSize: 12
                            color: window.accentColor
                            elide: Text.ElideRight
                        }
                    }

                    // Concept Description
                    Label {
                        text: model.descripcion
                        font.bold: true
                        font.pixelSize: 13
                        color: window.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Formula Unidad
                    Label {
                        text: model.formulaUnidad || "1.0"
                        font.family: "Monospace"
                        font.pixelSize: 11
                        color: window.subtextColor
                        Layout.preferredWidth: 100
                        elide: Text.ElideRight
                    }

                    // Formula Base
                    Label {
                        text: model.formulaBase || "-"
                        font.family: "Monospace"
                        font.pixelSize: 11
                        color: window.subtextColor
                        Layout.preferredWidth: 120
                        elide: Text.ElideRight
                    }

                    // Formula Monto or %
                    Rectangle {
                        implicitWidth: 150
                        implicitHeight: 26
                        radius: 4
                        color: window.inputBg
                        border.color: window.borderColor

                        Label {
                            anchors.centerIn: parent
                            text: model.tipoCalculo === "simple" ?
                                  ("% " + model.simplePorcentaje + " (" + model.simpleBaseVariable + ")") :
                                  (model.formulaMonto || "0.0")
                            font.family: "Monospace"
                            font.bold: true
                            font.pixelSize: 12
                            color: root.sectionColor
                            elide: Text.ElideRight
                        }
                    }

                    // Action Buttons (Edit / Delete)
                    RowLayout {
                        spacing: 4
                        visible: AppController.currentRole === "admin"

                        Button {
                            implicitWidth: 30
                            implicitHeight: 28
                            text: "✏️"
                            flat: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Editar Concepto"
                            onClicked: {
                                var cellData = {
                                    cellId: model.cellId,
                                    seccionCodigo: model.seccionCodigo,
                                    codigoVariable: model.codigoVariable,
                                    descripcion: model.descripcion,
                                    condicion: model.condicion,
                                    formulaUnidad: model.formulaUnidad,
                                    formulaBase: model.formulaBase,
                                    formulaMonto: model.formulaMonto,
                                    orden: model.orden,
                                    esquemaCodigo: model.esquemaCodigo,
                                    tipoCalculo: model.tipoCalculo,
                                    simplePorcentaje: model.simplePorcentaje,
                                    simpleBaseVariable: model.simpleBaseVariable,
                                    simpleMontoFijo: model.simpleMontoFijo,
                                    visibleRecibo: model.visibleRecibo
                                }
                                root.editRequested(cellData)
                            }
                        }

                        Button {
                            implicitWidth: 30
                            implicitHeight: 28
                            text: "🗑️"
                            flat: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Eliminar Concepto"
                            onClicked: {
                                AppController.cellModel.removeCell(model.cellId)
                            }
                        }
                    }
                }
            }
        }
    }
}
