import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../dialogs"

Item {
    id: root

    function openNewVariable() {
        globalVarDialog.varId = -1
        globalVarDialog.code = ""
        globalVarDialog.value = ""
        globalVarDialog.description = ""
        globalVarDialog.open()
    }

    function openEditVariable(itemData) {
        globalVarDialog.varId = itemData.varId
        globalVarDialog.code = itemData.code
        globalVarDialog.value = itemData.value
        globalVarDialog.description = itemData.description
        globalVarDialog.open()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // Header Action Bar
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
                    text: "Variables Globales del Sistema"
                    font.pixelSize: 18
                    font.bold: true
                    color: window.textColor
                }

                Label {
                    text: AppController.globalVarsModel.count + " registradas"
                    font.pixelSize: 12
                    color: window.subtextColor
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "+ Nueva Variable Global"
                    highlighted: true
                    visible: AppController.currentRole === "admin"
                    onClicked: openNewVariable()
                }
            }
        }

        // Main Global Variables List
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

                ListView {
                    id: varListView
                    model: AppController.globalVarsModel
                    spacing: 8

                    delegate: Rectangle {
                        width: varListView.width - 20
                        height: 56
                        radius: 6
                        color: mouseArea.containsMouse ? (window.isDark ? "#303045" : "#f0f0f5") : window.cardBg
                        border.color: window.borderColor
                        border.width: 1

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onDoubleClicked: {
                                var itemData = {
                                    varId: model.varId,
                                    code: model.code,
                                    value: model.value,
                                    description: model.description
                                }
                                openEditVariable(itemData)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 15

                            Rectangle {
                                implicitWidth: 120
                                implicitHeight: 28
                                radius: 4
                                color: window.inputBg
                                border.color: window.accentColor

                                Label {
                                    anchors.centerIn: parent
                                    text: model.code
                                    font.family: "Monospace"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: window.accentColor
                                    elide: Text.ElideRight
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: model.description || "Sin descripción"
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: window.textColor
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: "Doble clic para editar"
                                    font.pixelSize: 11
                                    color: window.subtextColor
                                }
                            }

                            Label {
                                text: model.value
                                font.bold: true
                                font.pixelSize: 15
                                color: "#a6e3a1"
                            }

                            RowLayout {
                                spacing: 6
                                visible: AppController.currentRole === "admin"

                                Button {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    text: "✏️"
                                    flat: true
                                    onClicked: {
                                        var itemData = {
                                            varId: model.varId,
                                            code: model.code,
                                            value: model.value,
                                            description: model.description
                                        }
                                        openEditVariable(itemData)
                                    }
                                }

                                Button {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    text: "🗑️"
                                    flat: true
                                    onClicked: {
                                        AppController.globalVarsModel.removeVariable(model.varId)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    GlobalVarDialog {
        id: globalVarDialog
    }
}
