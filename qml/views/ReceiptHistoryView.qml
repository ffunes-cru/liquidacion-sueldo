import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property int selectedReceiptId: -1
    property var receiptDetails: null
    property string statusMsg: ""

    Component.onCompleted: {
        if (AppController.employeeModel.count > 0) {
            var firstId = AppController.employeeModel.get(0).id
            cbFilterEmployee.currentIndex = 0
            AppController.receiptHistoryModel.employeeId = firstId
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════════════
        // LEFT PANE: Employee Filter & Receipt History List
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 380
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
                        text: "Historial de Recibos"
                        font.pixelSize: 16
                        font.bold: true
                        color: window.textColor
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: AppController.receiptHistoryModel.count + " recibos"
                        font.pixelSize: 12
                        color: window.subtextColor
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Label {
                        text: "Empleado:"
                        color: window.textColor
                        font.pixelSize: 13
                    }
                    ComboBox {
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
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: historyListView
                        model: AppController.receiptHistoryModel
                        spacing: 6

                        delegate: Rectangle {
                            width: historyListView.width
                            height: 60
                            radius: 6
                            color: root.selectedReceiptId === model.receiptId ? (window.isDark ? "#3b3b58" : "#e4e4e9") :
                                   (mouseArea.containsMouse ? (window.isDark ? "#303045" : "#f0f0f5") : window.cardBg)
                            border.color: root.selectedReceiptId === model.receiptId ? window.accentColor : window.borderColor
                            border.width: 1

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.selectedReceiptId = model.receiptId
                                    root.receiptDetails = AppController.receiptHistoryModel.getReceipt(model.receiptId)
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
                                        text: model.periodo || ("Período " + model.mes + "/" + model.anio)
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: window.textColor
                                    }

                                    Label {
                                        text: "Emisión: " + (model.fechaEmision || "N/A")
                                        font.pixelSize: 12
                                        color: window.subtextColor
                                    }
                                }

                                Label {
                                    text: "#" + model.receiptId
                                    font.bold: true
                                    font.pixelSize: 13
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
                        text: "Eliminar Recibo"
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
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // RIGHT PANE: Selected Receipt Detail Viewer
        // ═══════════════════════════════════════════════════════════════
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

                ColumnLayout {
                    width: parent.width - 30
                    spacing: 15

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: root.selectedReceiptId > 0 ? "Recibo Histórico #" + root.selectedReceiptId : "Seleccione un recibo del historial"
                            font.pixelSize: 18
                            font.bold: true
                            color: window.textColor
                        }
                        Item { Layout.fillWidth: true }

                        Button {
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

                    Label {
                        text: root.statusMsg
                        visible: root.statusMsg !== ""
                        color: window.accentColor
                        font.pixelSize: 12
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: detailGrid.implicitHeight + 20
                        visible: root.receiptDetails !== null
                        color: window.cardBg
                        radius: 6
                        border.color: window.borderColor

                        GridLayout {
                            id: detailGrid
                            anchors.fill: parent
                            anchors.margins: 12
                            columns: 2
                            rowSpacing: 10
                            columnSpacing: 15

                            Label { text: "Empleado:"; color: window.subtextColor; font.pixelSize: 13 }
                            Label {
                                text: root.receiptDetails ? (root.receiptDetails["nombre_completo"] || root.receiptDetails["empleado_id"]) : ""
                                color: window.textColor; font.bold: true; font.pixelSize: 14
                            }

                            Label { text: "Período:"; color: window.subtextColor; font.pixelSize: 13 }
                            Label {
                                text: root.receiptDetails ? root.receiptDetails["periodo"] : ""
                                color: window.accentColor; font.bold: true; font.pixelSize: 14
                            }

                            Label { text: "Esquema:"; color: window.subtextColor; font.pixelSize: 13 }
                            Label {
                                text: root.receiptDetails ? root.receiptDetails["esquema_codigo"] : ""
                                color: window.textColor; font.pixelSize: 13
                            }

                            Label { text: "Fecha Emisión:"; color: window.subtextColor; font.pixelSize: 13 }
                            Label {
                                text: root.receiptDetails ? root.receiptDetails["fecha_emision"] : ""
                                color: window.textColor; font.pixelSize: 13
                            }
                        }
                    }

                    // JSON / Liquidation Payload Preview
                    Label {
                        text: "Datos Almacenados (Payload JSON)"
                        visible: root.receiptDetails !== null
                        font.pixelSize: 14
                        font.bold: true
                        color: window.accentColor
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 300
                        visible: root.receiptDetails !== null
                        color: window.inputBg
                        radius: 6
                        border.color: window.borderColor

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true

                            TextArea {
                                text: root.receiptDetails ? root.receiptDetails["datos_json"] : ""
                                color: "#a6e3a1"
                                font.family: "Monospace"
                                font.pixelSize: 12
                                readOnly: true
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}
