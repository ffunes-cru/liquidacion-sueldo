import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

AppDialog {
    id: root

    title: "🔍 Seleccionar Empleado para Liquidación"
    dialogWidth: 620
    dialogHeight: 560
    standardButtons: Dialog.Close

    signal employeeSelected(int employeeId, var employeeData)

    onOpened: {
        txtSearch.text = ""
        AppController.employeeModel.filterText = ""
        txtSearch.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Search Input
        StyledTextField {
            id: txtSearch
            Layout.fillWidth: true
            placeholderText: "🔍 Buscar por legajo, nombre o CUIL..."
            onTextChanged: AppController.employeeModel.filterText = text
        }

        // ListView of Employees
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.cardBg
            radius: 8
            border.color: Theme.borderColor
            border.width: 1

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                ListView {
                    id: empListView
                    model: AppController.employeeModel
                    spacing: 8

                    delegate: Rectangle {
                        width: empListView.width - 16
                        height: 54
                        radius: 6
                        color: empMouseArea.containsMouse ? Theme.hoverBg : Theme.panelBg
                        border.color: Theme.borderColor
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                Label {
                                    text: model.nombre || ""
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: Theme.textColor
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: "CUIL: " + (model.cuil || "N/A") + " | " + (model.esquema || model.esquema_codigo || "MENSUAL") + " (" + (model.tipoLiquidacion || model.tipo_liquidacion || "mensual") + ")"
                                    font.pixelSize: 11
                                    color: Theme.subtextColor
                                    elide: Text.ElideRight
                                }
                            }

                            StyledButton {
                                variant: "primary"
                                text: "Seleccionar"
                                Layout.alignment: Qt.AlignRight
                                onClicked: {
                                    var empData = AppController.employeeModel.get(index)
                                    root.employeeSelected(model.employeeId, empData)
                                    root.close()
                                }
                            }
                        }

                        MouseArea {
                            id: empMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var empData = AppController.employeeModel.get(index)
                                root.employeeSelected(model.employeeId, empData)
                                root.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
