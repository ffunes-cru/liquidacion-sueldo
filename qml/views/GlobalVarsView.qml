import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property int selectedVarId: -1
    property int selectedRow: -1

    function loadVariable(row) {
        if (row < 0 || row >= AppController.globalVarsModel.count) {
            clearForm()
            return
        }
        selectedRow = row
        var idx = AppController.globalVarsModel.index(row, 0)
        selectedVarId = AppController.globalVarsModel.data(idx, 257) // IdRole
        var code = AppController.globalVarsModel.data(idx, 258) // CodeRole
        var val = AppController.globalVarsModel.data(idx, 259) // ValueRole
        var desc = AppController.globalVarsModel.data(idx, 260) // DescriptionRole

        txtCodigo.text = code || ""
        txtValor.text = val !== undefined ? val.toString() : ""
        txtDescripcion.text = desc || ""
    }

    function clearForm() {
        selectedRow = -1
        selectedVarId = -1
        txtCodigo.text = ""
        txtValor.text = ""
        txtDescripcion.text = ""
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════════════
        // LEFT PANE: Global Variables List
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 420
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
                        text: "Variables Globales del Sistema"
                        font.pixelSize: 16
                        font.bold: true
                        color: window.textColor
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: AppController.globalVarsModel.count + " vars"
                        font.pixelSize: 12
                        color: window.subtextColor
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: varListView
                        model: AppController.globalVarsModel
                        spacing: 6

                        delegate: Rectangle {
                            width: varListView.width
                            height: 60
                            radius: 6
                            color: root.selectedVarId === model.varId ? (window.isDark ? "#3b3b58" : "#e4e4e9") :
                                   (mouseArea.containsMouse ? (window.isDark ? "#303045" : "#f0f0f5") : window.cardBg)
                            border.color: root.selectedVarId === model.varId ? window.accentColor : window.borderColor
                            border.width: 1

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.selectedVarId = model.varId
                                    root.selectedRow = index
                                    txtCodigo.text = model.code
                                    txtValor.text = model.value
                                    txtDescripcion.text = model.description
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        text: model.code
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: window.textColor
                                    }

                                    Label {
                                        text: model.description || "Sin descripción"
                                        font.pixelSize: 12
                                        color: window.subtextColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Label {
                                    text: model.value
                                    font.bold: true
                                    font.pixelSize: 14
                                    color: window.accentColor
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
                        text: "Nueva Variable"
                        visible: AppController.currentRole === "admin"
                        onClicked: {
                            root.clearForm()
                            txtCodigo.forceActiveFocus()
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: "Eliminar"
                        visible: AppController.currentRole === "admin"
                        enabled: root.selectedVarId > 0
                        onClicked: {
                            if (root.selectedVarId > 0) {
                                AppController.globalVarsModel.removeVariable(root.selectedVarId)
                                root.clearForm()
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // RIGHT PANE: Variable Form / Editor
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: window.panelBg
            radius: 8
            border.color: window.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                Label {
                    text: root.selectedVarId > 0 ? "Editar Variable #" + root.selectedVarId : "Nueva Variable Global"
                    font.pixelSize: 18
                    font.bold: true
                    color: window.textColor
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 220
                    color: window.cardBg
                    radius: 6
                    border.color: window.borderColor

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        columns: 2
                        rowSpacing: 15
                        columnSpacing: 15

                        Label { text: "Código de Variable:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtCodigo
                            placeholderText: "Ej: TOPE_JUBILATORIO"
                            Layout.fillWidth: true
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 4
                                border.color: parent.activeFocus ? window.accentColor : window.borderColor
                            }
                        }

                        Label { text: "Valor:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtValor
                            placeholderText: "Ej: 150000.00"
                            Layout.fillWidth: true
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 4
                                border.color: parent.activeFocus ? window.accentColor : window.borderColor
                            }
                        }

                        Label { text: "Descripción:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtDescripcion
                            placeholderText: "Descripción o tope tope de base imponible..."
                            Layout.fillWidth: true
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 4
                                border.color: parent.activeFocus ? window.accentColor : window.borderColor
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Guardar Variable Global"
                        highlighted: true
                        visible: AppController.currentRole === "admin"
                        onClicked: {
                            if (txtCodigo.text.trim() !== "") {
                                AppController.globalVarsModel.saveVariable(
                                    root.selectedVarId > 0 ? root.selectedVarId : 0,
                                    txtCodigo.text.trim(),
                                    txtValor.text.trim(),
                                    txtDescripcion.text.trim()
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
