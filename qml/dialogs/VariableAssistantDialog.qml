import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Dialog {
    id: root

    property string esquemaCodigo: "MENSUAL"
    signal variableSelected(string code)

    title: "Asistente de Variables para Fórmulas"
    modal: true
    width: 540
    height: 480
    standardButtons: Dialog.Close

    background: Rectangle {
        color: window.panelBg
        radius: 10
        border.color: window.borderColor
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        TextField {
            id: txtFilter
            placeholderText: "Buscar variable o función..."
            Layout.fillWidth: true
            color: window.textColor
            background: Rectangle {
                color: window.inputBg
                radius: 6
                border.color: parent.activeFocus ? window.accentColor : window.borderColor
            }
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
                    color: mouseArea.containsMouse ? window.cardBg : window.inputBg
                    border.color: window.borderColor

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

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 4
                            color: modelData.category === "Función Motor" ? "#89b4fa" :
                                   (modelData.category === "Acumulador" ? "#f38ba8" :
                                   (modelData.category === "Variable Global" ? "#fab387" : "#a6e3a1"))

                            Label {
                                anchors.centerIn: parent
                                text: modelData.category ? modelData.category.substring(0, 1) : "V"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#11111b"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Label {
                                text: modelData.code
                                font.family: "Monospace"
                                font.bold: true
                                font.pixelSize: 13
                                color: window.textColor
                            }

                            Label {
                                text: modelData.description
                                font.pixelSize: 11
                                color: window.subtextColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Button {
                            text: "Insertar"
                            flat: true
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
