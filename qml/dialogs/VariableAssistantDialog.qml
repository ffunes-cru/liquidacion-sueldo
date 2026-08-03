import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

AppDialog {
    id: root

    property string esquemaCodigo: "MENSUAL"
    signal variableSelected(string code)

    title: "Asistente de Variables para Fórmulas"
    dialogWidth: 540
    dialogHeight: 480
    standardButtons: Dialog.Close

    contentItem: ColumnLayout {
        spacing: 10

        StyledTextField {
            id: txtFilter
            placeholderText: "Buscar variable o función..."
            Layout.fillWidth: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: varListView
                model: AppController.getAvailableFormulaVariables(root.esquemaCodigo)
                spacing: 6

                delegate: Rectangle {
                    width: varListView.width
                    height: 48
                    radius: 6
                    color: mouseArea.containsMouse ? Theme.cardBg : Theme.inputBg
                    border.color: Theme.borderColor

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.variableSelected(modelData.code)
                            root.close()
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        BadgePill {
                            text: modelData.category ? modelData.category.substring(0, 1) : "V"
                            badgeColor: modelData.category === "Función Motor" ? Theme.infoColor :
                                        (modelData.category === "Acumulador" ? Theme.dangerColor :
                                        (modelData.category === "Variable Global" ? Theme.warningColor : Theme.successColor))
                            circular: true
                            implicitWidth: 26
                            implicitHeight: 26
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Label {
                                text: modelData.code
                                font.family: "Monospace"
                                font.bold: true
                                font.pixelSize: 13
                                color: Theme.textColor
                            }

                            Label {
                                text: modelData.description
                                font.pixelSize: 11
                                color: Theme.subtextColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        StyledButton {
                            variant: "secondary"
                            text: "Insertar"
                            onClicked: {
                                root.variableSelected(modelData.code)
                                root.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
