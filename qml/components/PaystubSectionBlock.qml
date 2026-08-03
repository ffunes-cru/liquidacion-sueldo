import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

ColumnLayout {
    id: root

    property string sectionTitle: "SECCIÓN"
    property string sectionCode: "REMUNERATIVO"
    property color sectionColor: Theme.successColor
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
                width: 10; height: 10; radius: 5
                color: root.sectionColor
            }

            Label {
                text: root.sectionTitle
                font.bold: true; font.pixelSize: 13
                color: root.sectionColor
            }

            Item { Layout.fillWidth: true }

            StyledButton {
                variant: "ghost"
                text: "➕ Agregar"
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
                color: mouseArea.containsMouse ? Theme.hoverBg : Theme.cardBg
                radius: 6
                border.color: Theme.borderColor
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

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

                    // Reorder Buttons
                    ColumnLayout {
                        spacing: 0
                        visible: AppController.currentRole === "admin"

                        StyledButton {
                            implicitWidth: 22; implicitHeight: 18
                            variant: "ghost"
                            text: "▲"
                            onClicked: AppController.cellModel.moveCellUp(index)
                        }
                        StyledButton {
                            implicitWidth: 22; implicitHeight: 18
                            variant: "ghost"
                            text: "▼"
                            onClicked: AppController.cellModel.moveCellDown(index)
                        }
                    }

                    // Concept Code Pill
                    BadgePill {
                        text: model.codigoVariable
                        badgeColor: Theme.accentColor
                        implicitWidth: 100
                    }

                    // Description
                    Label {
                        text: model.descripcion
                        font.bold: true; font.pixelSize: 13
                        color: Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Formula Unidad
                    Label {
                        text: model.formulaUnidad || "1.0"
                        font.family: "Monospace"; font.pixelSize: 11
                        color: Theme.subtextColor
                        Layout.preferredWidth: 100; elide: Text.ElideRight
                    }

                    // Formula Base
                    Label {
                        text: model.formulaBase || "-"
                        font.family: "Monospace"; font.pixelSize: 11
                        color: Theme.subtextColor
                        Layout.preferredWidth: 120; elide: Text.ElideRight
                    }

                    // Formula Monto or %
                    BadgePill {
                        text: model.tipoCalculo === "simple"
                              ? ("% " + model.simplePorcentaje + " (" + model.simpleBaseVariable + ")")
                              : (model.formulaMonto || "0.0")
                        badgeColor: root.sectionColor
                        implicitWidth: 150
                        fontSize: 12
                    }

                    // Admin Actions
                    AdminActions {
                        onEditClicked: {
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
                                visibleRecibo: (model.visibleRecibo !== undefined) ? model.visibleRecibo : model.visible_recibo
                            }
                            root.editRequested(cellData)
                        }
                        onDeleteClicked: {
                            AppController.cellModel.removeCell(model.cellId)
                        }
                    }
                }
            }
        }
    }
}
