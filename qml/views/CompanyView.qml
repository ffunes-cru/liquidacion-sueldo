import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

Item {
    id: root

    property string statusMessage: ""
    property bool isError: false

    Component.onCompleted: loadCompanyData()

    function loadCompanyData() {
        var comp = AppController.getCompany()
        fieldRazonSocial.value = comp.razon_social || ""
        fieldCuit.value = comp.cuit || ""
        fieldDireccion.value = comp.direccion || ""
        fieldLugarPago.value = comp.lugar_de_pago || comp.lugar_pago || ""
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 20
        clip: true

        ColumnLayout {
            width: Math.min(scrollView.availableWidth > 0 ? scrollView.availableWidth : root.width - 40, 720)
            spacing: 20

            // ── Title ─────────────────────────────────────────────
            Label {
                text: "Datos Institucionales de la Empresa"
                font.pixelSize: 22
                font.bold: true
                color: Theme.textColor
            }

            // ── Company Data Card ─────────────────────────────────
            SectionPanel {
                title: "Información Fiscal y Domicilio"
                padding: 25

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    FormField {
                        id: fieldRazonSocial
                        label: "Razón Social:"
                        placeholder: "Empresa S.A."
                    }

                    FormField {
                        id: fieldCuit
                        label: "C.U.I.T.:"
                        placeholder: "30-12345678-9"
                    }

                    FormField {
                        id: fieldDireccion
                        label: "Dirección Real:"
                        placeholder: "Av. Corrientes 1234, CABA"
                    }

                    FormField {
                        id: fieldLugarPago
                        label: "Lugar de Pago:"
                        placeholder: "Buenos Aires, Argentina"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Guardar Datos de Empresa"
                            highlighted: true
                            onClicked: {
                                var ok = AppController.saveCompany(
                                    fieldRazonSocial.value.trim(),
                                    fieldDireccion.value.trim(),
                                    fieldCuit.value.trim(),
                                    fieldLugarPago.value.trim()
                                )
                                root.isError = !ok
                                root.statusMessage = ok
                                    ? "Datos de empresa guardados exitosamente."
                                    : "Error al guardar datos de la empresa."
                            }
                        }
                    }
                }
            }

            // ── Status Banner ─────────────────────────────────────
            StatusBanner {
                message: root.statusMessage
                isError: root.isError
                autoDismissMs: 5000
                onDismissed: root.statusMessage = ""
            }
        }
    }
}
