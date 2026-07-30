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
            width: root.width - 40
            spacing: 20

            // ── Title Section ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Configuración de la Empresa"
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
                    anchors.margins: 20
                    spacing: 15

                    Label {
                        text: "Datos Institucionales"
                        font.pixelSize: 16
                        font.bold: true
                        color: window.accentColor
                    }

                    GridLayout {
                        id: companyGrid
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 15
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
                            text: "Dirección:"
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

            // ── System Operations Card ─────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sysOpsColumn.implicitHeight + 40
                color: window.panelBg
                radius: 8
                border.color: window.borderColor

                ColumnLayout {
                    id: sysOpsColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    Label {
                        text: "Operaciones del Sistema"
                        font.pixelSize: 16
                        font.bold: true
                        color: window.accentColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Label {
                                text: "Copia de Seguridad (Backup)"
                                font.bold: true
                                color: window.textColor
                                font.pixelSize: 14
                            }
                            Label {
                                text: "Genera un archivo de respaldo SQLite con la fecha y hora actual."
                                color: window.subtextColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        Button {
                            text: "Crear Backup"
                            onClicked: {
                                var backupPath = AppController.createBackup()
                                root.isError = false
                                root.statusMessage = "Backup creado en: " + backupPath
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: window.borderColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Label {
                                text: "Cierre Mensual / Reiniciar Nuevo Mes"
                                font.bold: true
                                color: window.textColor
                                font.pixelSize: 14
                            }
                            Label {
                                text: "Crea una copia de seguridad automática y limpia las variables de empleados para el nuevo mes de liquidación."
                                color: window.subtextColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        Button {
                            text: "Reiniciar Nuevo Mes"
                            onClicked: {
                                var backupPath = AppController.resetNewMonth()
                                root.isError = false
                                root.statusMessage = "Nuevo mes reiniciado. Backup de seguridad guardado en: " + backupPath
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: window.borderColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Label {
                                text: "Modo Oscuro (Dark Theme)"
                                font.bold: true
                                color: window.textColor
                                font.pixelSize: 14
                            }
                            Label {
                                text: "Alterna la apariencia de la interfaz."
                                color: window.subtextColor
                                font.pixelSize: 12
                            }
                        }

                        Switch {
                            checked: AppController.darkMode
                            onToggled: AppController.darkMode = checked
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
