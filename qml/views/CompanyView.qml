import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property string statusMessage: ""
    property bool isError: false

    Component.onCompleted: {
        loadCompanyData()
    }

    function loadCompanyData() {
        var comp = AppController.getCompany()
        txtRazonSocial.text = comp.razon_social || ""
        txtCuit.text = comp.cuit || ""
        txtDireccion.text = comp.direccion || ""
        txtLugarDePago.text = comp.lugar_pago || ""
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        clip: true

        ColumnLayout {
            width: Math.min(root.width - 40, 700)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            // ── Title Section ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Datos Institucionales de la Empresa"
                    font.pixelSize: 22
                    font.bold: true
                    color: window.textColor
                }
                Item { Layout.fillWidth: true }
            }

            // ── Company Data Card ──────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: companyGrid.implicitHeight + 40
                color: window.panelBg
                radius: 8
                border.color: window.borderColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 25
                    spacing: 20

                    Label {
                        text: "Información Fiscal y Domicilio"
                        font.pixelSize: 16
                        font.bold: true
                        color: window.accentColor
                    }

                    GridLayout {
                        id: companyGrid
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 18
                        columnSpacing: 20

                        Label {
                            text: "Razón Social:"
                            color: window.textColor
                            font.pixelSize: 14
                        }
                        TextField {
                            id: txtRazonSocial
                            Layout.fillWidth: true
                            placeholderText: "Empresa S.A."
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 6
                                border.color: txtRazonSocial.activeFocus ? window.accentColor : window.borderColor
                            }
                        }

                        Label {
                            text: "C.U.I.T.:"
                            color: window.textColor
                            font.pixelSize: 14
                        }
                        TextField {
                            id: txtCuit
                            Layout.fillWidth: true
                            placeholderText: "30-12345678-9"
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 6
                                border.color: txtCuit.activeFocus ? window.accentColor : window.borderColor
                            }
                        }

                        Label {
                            text: "Dirección Real:"
                            color: window.textColor
                            font.pixelSize: 14
                        }
                        TextField {
                            id: txtDireccion
                            Layout.fillWidth: true
                            placeholderText: "Av. Corrientes 1234, CABA"
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 6
                                border.color: txtDireccion.activeFocus ? window.accentColor : window.borderColor
                            }
                        }

                        Label {
                            text: "Lugar de Pago:"
                            color: window.textColor
                            font.pixelSize: 14
                        }
                        TextField {
                            id: txtLugarDePago
                            Layout.fillWidth: true
                            placeholderText: "Buenos Aires, Argentina"
                            color: window.textColor
                            background: Rectangle {
                                color: window.inputBg
                                radius: 6
                                border.color: txtLugarDePago.activeFocus ? window.accentColor : window.borderColor
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Guardar Datos de Empresa"
                            highlighted: true
                            onClicked: {
                                var ok = AppController.saveCompany(
                                    txtRazonSocial.text.trim(),
                                    txtDireccion.text.trim(),
                                    txtCuit.text.trim(),
                                    txtLugarDePago.text.trim()
                                )
                                if (ok) {
                                    root.isError = false
                                    root.statusMessage = "Datos de empresa guardados exitosamente."
                                } else {
                                    root.isError = true
                                    root.statusMessage = "Error al guardar datos de la empresa."
                                }
                            }
                        }
                    }
                }
            }

            // ── Status Banner ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 45
                visible: root.statusMessage !== ""
                color: root.isError ? "#44232b" : "#1e3a34"
                radius: 6
                border.color: root.isError ? window.dangerColor : "#a6e3a1"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Label {
                        text: root.statusMessage
                        color: root.isError ? window.dangerColor : "#a6e3a1"
                        font.pixelSize: 13
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Button {
                        text: "X"
                        flat: true
                        onClicked: root.statusMessage = ""
                    }
                }
            }
        }
    }
}
