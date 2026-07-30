import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property int selectedCatId: -1
    property int selectedRow: -1

    function loadCategory(row) {
        if (row < 0 || row >= AppController.categoryModel.count) {
            clearForm()
            return
        }
        selectedRow = row
        var cat = AppController.categoryModel.data(AppController.categoryModel.index(row, 0), 256)
        selectedCatId = AppController.categoryModel.data(AppController.categoryModel.index(row, 0), 257)
        var name = AppController.categoryModel.data(AppController.categoryModel.index(row, 0), 258)
        var valor = AppController.categoryModel.data(AppController.categoryModel.index(row, 0), 259)

        txtNombre.text = name || ""
        txtValorHora.text = valor !== undefined ? valor.toString() : "0.0"
    }

    function clearForm() {
        selectedRow = -1
        selectedCatId = -1
        txtNombre.text = ""
        txtValorHora.text = "0.0"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════════════
        // LEFT PANE: Category List
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
                        text: "Categorías Jornaleras"
                        font.pixelSize: 16
                        font.bold: true
                        color: window.textColor
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: AppController.categoryModel.count + " cat."
                        font.pixelSize: 12
                        color: window.subtextColor
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: catListView
                        model: AppController.categoryModel
                        spacing: 6

                        delegate: Rectangle {
                            width: catListView.width
                            height: 52
                            radius: 6
                            color: root.selectedCatId === model.catId ? (window.isDark ? "#3b3b58" : "#e4e4e9") :
                                   (mouseArea.containsMouse ? (window.isDark ? "#303045" : "#f0f0f5") : window.cardBg)
                            border.color: root.selectedCatId === model.catId ? window.accentColor : window.borderColor
                            border.width: 1

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.selectedCatId = model.catId
                                    root.selectedRow = index
                                    txtNombre.text = model.name
                                    txtValorHora.text = model.valorHora.toString()
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Label {
                                    text: model.name
                                    font.bold: true
                                    font.pixelSize: 14
                                    color: window.textColor
                                    Layout.fillWidth: true
                                }

                                Label {
                                    text: "$ " + Number(model.valorHora).toFixed(2)
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
                        text: "Nueva Categoría"
                        onClicked: {
                            root.clearForm()
                            txtNombre.forceActiveFocus()
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: "Eliminar"
                        enabled: root.selectedCatId > 0
                        onClicked: {
                            if (root.selectedCatId > 0) {
                                AppController.categoryModel.removeCategory(root.selectedCatId)
                                root.clearForm()
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // RIGHT PANE: Category Editor Form
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
                    text: root.selectedCatId > 0 ? "Editar Categoría #" + root.selectedCatId : "Nueva Categoría Jornalera"
                    font.pixelSize: 18
                    font.bold: true
                    color: window.textColor
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 140
                    color: window.cardBg
                    radius: 6
                    border.color: window.borderColor

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        columns: 2
                        rowSpacing: 15
                        columnSpacing: 15

                        Label { text: "Nombre de Categoría:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtNombre
                            placeholderText: "Ej: Maestranza A Jornal"
                            Layout.fillWidth: true
                            color: window.textColor
                        }

                        Label { text: "Valor por Hora ($):"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtValorHora
                            placeholderText: "5540.61"
                            Layout.fillWidth: true
                            color: window.textColor
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Guardar Categoría"
                        highlighted: true
                        onClicked: {
                            var val = parseFloat(txtValorHora.text) || 0.0
                            if (txtNombre.text.trim() !== "") {
                                AppController.categoryModel.saveCategory(
                                    root.selectedCatId > 0 ? root.selectedCatId : 0,
                                    txtNombre.text.trim(),
                                    val
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
