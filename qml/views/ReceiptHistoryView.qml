import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

MasterDetailView {
    id: root

    masterWidth: 380
    masterTitle: "Historial de Recibos"
    masterCountSuffix: "recibos"
    masterModel: AppController.receiptHistoryModel

    property int selectedReceiptId: -1
    property var receiptDetails: null
    property string statusMsg: ""

    Component.onCompleted: {
        if (AppController.employeeModel.count > 0) {
            cbFilterEmployee.currentIndex = 0
            var firstId = AppController.employeeModel.get(0).id
            AppController.receiptHistoryModel.employeeId = firstId
        }
    }

    // ── Master Delegate ─────────────────────────────────────────
    masterDelegate: Component {
        CrudDelegate {
            height: 60
            primaryText: model.periodo || ("Período " + model.mes + "/" + model.anio)
            secondaryText: "Emisión: " + (model.fechaEmision || "N/A")
            badgeText: "#" + model.receiptId
            showAdminActions: false
            valueText: ""

            color: root.selectedReceiptId === model.receiptId ? Theme.selectedBg :
                   (mouseArea.containsMouse ? Theme.hoverBg : Theme.cardBg)
            border.color: root.selectedReceiptId === model.receiptId ? Theme.accentColor : Theme.borderColor

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.selectedReceiptId = model.receiptId
                    root.receiptDetails = AppController.receiptHistoryModel.getReceipt(model.receiptId)
                }
            }
        }
    }

    // ── Master Footer ───────────────────────────────────────────
    masterFooter: [
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: "Empleado:"
                color: Theme.textColor
                font.pixelSize: 13
            }

            StyledComboBox {
                id: cbFilterEmployee
                Layout.fillWidth: true
                model: AppController.employeeModel
                textRole: "nombre"
                valueRole: "employeeId"
                onActivated: {
                    var empId = currentValue !== undefined ? currentValue : -1
                    AppController.receiptHistoryModel.employeeId = empId
                    root.selectedReceiptId = -1
                    root.receiptDetails = null
                }
            }
        },

        StyledButton {
            Layout.fillWidth: true
            variant: "danger"
            text: "🗑️ Eliminar Recibo"
            visible: AppController.currentRole === "admin"
            enabled: root.selectedReceiptId > 0
            onClicked: {
                if (root.selectedReceiptId > 0) {
                    AppController.receiptHistoryModel.removeReceipt(root.selectedReceiptId)
                    root.selectedReceiptId = -1
                    root.receiptDetails = null
                }
            }
        }
    ]

    // ══════════════════════════════════════════════════════════════
    // DETAIL CONTENT (Right Panel)
    // ══════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: 15

        // Title + Export button
        RowLayout {
            Layout.fillWidth: true

            Label {
                text: root.selectedReceiptId > 0
                      ? "Recibo Histórico #" + root.selectedReceiptId
                      : "Seleccione un recibo del historial"
                font.pixelSize: 18
                font.bold: true
                color: Theme.textColor
            }

            Item { Layout.fillWidth: true }

            StyledButton {
                variant: "secondary"
                text: "📄 Exportar PDF"
                visible: root.receiptDetails !== null
                onClicked: {
                    if (root.receiptDetails) {
                        try {
                            var jsonStr = root.receiptDetails["datos_json"]
                            var parsedData = JSON.parse(jsonStr)
                            var empId = root.receiptDetails["empleado_id"] || cbFilterEmployee.currentValue
                            var pdfPath = AppController.exportReceiptPdf(empId, parsedData, "")
                            if (pdfPath !== "") {
                                root.statusMsg = "Recibo PDF exportado: " + pdfPath
                            }
                        } catch(e) {
                            root.statusMsg = "Error al parsear datos JSON del recibo."
                        }
                    }
                }
            }
        }

        StatusBanner {
            message: root.statusMsg
            isError: false
            autoDismissMs: 5000
            onDismissed: root.statusMsg = ""
        }

        // Receipt metadata card
        SectionPanel {
            visible: root.receiptDetails !== null

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 15

                Label { text: "Empleado:"; color: Theme.subtextColor; font.pixelSize: 13 }
                Label {
                    text: root.receiptDetails ? (root.receiptDetails["nombre_completo"] || root.receiptDetails["empleado_id"]) : ""
                    color: Theme.textColor; font.bold: true; font.pixelSize: 14
                }

                Label { text: "Período:"; color: Theme.subtextColor; font.pixelSize: 13 }
                Label {
                    text: root.receiptDetails ? root.receiptDetails["periodo"] : ""
                    color: Theme.accentColor; font.bold: true; font.pixelSize: 14
                }

                Label { text: "Esquema:"; color: Theme.subtextColor; font.pixelSize: 13 }
                Label {
                    text: root.receiptDetails ? root.receiptDetails["esquema_codigo"] : ""
                    color: Theme.textColor; font.pixelSize: 13
                }

                Label { text: "Fecha Emisión:"; color: Theme.subtextColor; font.pixelSize: 13 }
                Label {
                    text: root.receiptDetails ? root.receiptDetails["fecha_emision"] : ""
                    color: Theme.textColor; font.pixelSize: 13
                }
            }
        }

        // JSON payload preview
        Label {
            text: "Datos Almacenados (Payload JSON)"
            visible: root.receiptDetails !== null
            font.pixelSize: 14
            font.bold: true
            color: Theme.accentColor
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.receiptDetails !== null
            color: Theme.inputBg
            radius: 6
            border.color: Theme.borderColor

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true

                TextArea {
                    text: root.receiptDetails ? root.receiptDetails["datos_json"] : ""
                    color: Theme.successColor
                    font.family: "Monospace"
                    font.pixelSize: 12
                    readOnly: true
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
