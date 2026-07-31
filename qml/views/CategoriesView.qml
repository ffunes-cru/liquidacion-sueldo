import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../dialogs"

Item {
    id: root

    function openNewCategory() {
        categoryDialog.catId = -1
        categoryDialog.nombre = ""
        categoryDialog.valorHora = "0.0"
        categoryDialog.open()
    }

    function openEditCategory(catData) {
        categoryDialog.catId = catData.catId
        categoryDialog.nombre = catData.name
        categoryDialog.valorHora = catData.valorHora.toString()
        categoryDialog.open()
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
                    text: "Categorías Jornaleras"
                    font.pixelSize: 18
                    font.bold: true
                    color: window.textColor
                }

                Label {
                    text: AppController.categoryModel.count + " registradas"
                    font.pixelSize: 12
                    color: window.subtextColor
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "+ Nueva Categoría"
                    highlighted: true
                    visible: AppController.currentRole === "admin"
                    onClicked: openNewCategory()
                }
            }
        }

        // Main Categories List
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
                    id: catListView
                    model: AppController.categoryModel
                    spacing: 8

                    delegate: Rectangle {
                        width: catListView.width - 20
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
                                var item = {
                                    catId: model.catId,
                                    name: model.name,
                                    valorHora: model.valorHora
                                }
                                openEditCategory(item)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 15

                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: Qt.alpha(window.accentColor, 0.2)
                                border.color: window.accentColor

                                Label {
                                    anchors.centerIn: parent
                                    text: "#" + model.catId
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: window.accentColor
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: model.name
                                    font.bold: true
                                    font.pixelSize: 14
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
                                text: "$ " + Number(model.valorHora).toFixed(2) + " / hora"
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
                                        var item = {
                                            catId: model.catId,
                                            name: model.name,
                                            valorHora: model.valorHora
                                        }
                                        openEditCategory(item)
                                    }
                                }

                                Button {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    text: "🗑️"
                                    flat: true
                                    onClicked: {
                                        AppController.categoryModel.removeCategory(model.catId)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    CategoryDialog {
        id: categoryDialog
    }
}
