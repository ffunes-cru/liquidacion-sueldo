import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

Item {
    id: root

    property string statusMessage: ""
    property bool isError: false

    property var initialData: ({})
    readonly property bool hasUnsavedChanges: {
        return (fieldRazonSocial.value !== (initialData.razon_social || "")) ||
               (fieldCuit.value !== (initialData.cuit || "")) ||
               (fieldDireccion.value !== (initialData.direccion || "")) ||
               (fieldLugarPago.value !== (initialData.lugar_pago || ""))
    }

    Component.onCompleted: loadCompanyData()

    function loadCompanyData() {
        var comp = AppController.getCompany()
        var lp = comp.lugar_de_pago || comp.lugar_pago || ""
        initialData = {
            razon_social: comp.razon_social || "",
            cuit: comp.cuit || "",
            direccion: comp.direccion || "",
            lugar_pago: lp
        }
        fieldRazonSocial.value = comp.razon_social || ""
        fieldCuit.value = comp.cuit || ""
        fieldDireccion.value = comp.direccion || ""
        fieldLugarPago.value = lp
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
                        spacing: 10

                        BadgePill {
                            visible: root.hasUnsavedChanges
                            text: "● Hay cambios sin guardar"
                            variant: "warning"
                        }

                        Item { Layout.fillWidth: true }

                        StyledButton {
                            variant: root.hasUnsavedChanges ? "primary" : "secondary"
                            text: "💾 Guardar Datos de Empresa"
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
                                if (ok) {
                                    initialData = {
                                        razon_social: fieldRazonSocial.value.trim(),
                                        cuit: fieldCuit.value.trim(),
                                        direccion: fieldDireccion.value.trim(),
                                        lugar_pago: fieldLugarPago.value.trim()
                                    }
                                }
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
