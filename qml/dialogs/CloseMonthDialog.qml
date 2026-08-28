import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

AppDialog {
    id: root

    title: "Gestión de Cierres de Período y Liquidación Batch"
    dialogWidth: 640
    dialogHeight: -1
    standardButtons: Dialog.NoButton

    property int anio: AppController.selectedYear
    property int mes: AppController.selectedMonth
    property string monthName: {
        var names = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                     "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
        return (mes >= 1 && mes <= 12) ? names[mes - 1] : ""
    }

    // Target Selection state
    property var targetsList: []
    property int selectedTargetIndex: 0
    property string currentTargetType: ""      // "Q1", "Q2", "M"
    property string currentEsquemaTipo: ""     // "jornal" | "mensual"
    property bool currentTargetIsClosed: false
    property bool currentTargetCanClose: false
    property bool currentTargetCanReopen: false

    // Validation State
    property bool isValidated: false
    property var validationResult: null
    property string exportFolder: ""
    property string statusMsg: ""
    property bool isProcessing: false

    function refreshTargets() {
        var list = []
        var qList = AppController.activeQuincenas
        for (var i = 0; i < qList.length; i++) {
            var qName = qList[i]
            var closed = AppController.isCierreClosed(qName, "jornal")
            var canClose = AppController.canCloseTarget(qName, "jornal")
            var canReopen = AppController.canReopenTarget(qName, "jornal")
            list.push({
                "label": "Jornaleros — " + qName,
                "tipo": qName,
                "esquemaTipo": "jornal",
                "isClosed": closed,
                "canClose": canClose,
                "canReopen": canReopen,
                "statusText": closed ? "🔒 Cerrada" : (canClose ? "🟢 Lista para liquidar" : "⏳ Pendiente (requiere anterior)")
            })
        }

        var mClosed = AppController.isCierreClosed("M", "mensual")
        var mCanClose = AppController.canCloseTarget("M", "mensual")
        var mCanReopen = AppController.canReopenTarget("M", "mensual")
        list.push({
            "label": "Mensuales — Período Completo (M)",
            "tipo": "M",
            "esquemaTipo": "mensual",
            "isClosed": mClosed,
            "canClose": mCanClose,
            "canReopen": mCanReopen,
            "statusText": mClosed ? "🔒 Cerrado" : "🟢 Listo para liquidar"
        })

        targetsList = list
        if (selectedTargetIndex >= list.length) {
            selectedTargetIndex = 0
        }
        updateSelectedTarget()
    }

    function updateSelectedTarget() {
        if (selectedTargetIndex >= 0 && selectedTargetIndex < targetsList.length) {
            var item = targetsList[selectedTargetIndex]
            currentTargetType = item.tipo
            currentEsquemaTipo = item.esquemaTipo
            currentTargetIsClosed = item.isClosed
            currentTargetCanClose = item.canClose
            currentTargetCanReopen = item.canReopen

            // Dates defaults
            if (currentTargetIsClosed) {
                var cData = AppController.getCierre(currentTargetType, currentEsquemaTipo)
                dpFechaCierre.selectedDateString = cData.fecha_cierre || AppController.fechaCierreMes
                dpFechaPago.selectedDateString = cData.fecha_pago || AppController.fechaPago
            } else {
                if (currentTargetType === "Q1") {
                    dpFechaCierre.selectedDateString = AppController.fechaCierreQ1
                } else if (currentTargetType === "Q2") {
                    dpFechaCierre.selectedDateString = AppController.fechaCierreQ2
                } else {
                    dpFechaCierre.selectedDateString = AppController.fechaCierreMes
                }
                dpFechaPago.selectedDateString = AppController.fechaPago
            }
        }
        isValidated = false
        validationResult = null
        statusMsg = ""
    }

    onAboutToShow: {
        anio = AppController.selectedYear
        mes = AppController.selectedMonth
        refreshTargets()
    }

    Connections {
        target: AppController
        function onPeriodClosedChanged() {
            root.refreshTargets()
        }
        function onBatchCloseCompleted(ok, msg) {
            root.refreshTargets()
        }
        function onSelectedMonthChanged() {
            root.mes = AppController.selectedMonth
            root.refreshTargets()
        }
        function onSelectedYearChanged() {
            root.anio = AppController.selectedYear
            root.refreshTargets()
        }
    }

    contentItem: ColumnLayout {
        spacing: 14

        // Header Description Banner
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: bannerLayout.implicitHeight + 16
            radius: 8
            color: Theme.isDark ? Qt.rgba(245/255, 158/255, 11/255, 0.12) : Qt.rgba(245/255, 158/255, 11/255, 0.08)
            border.color: Qt.rgba(245/255, 158/255, 11/255, 0.35)
            border.width: 1

            RowLayout {
                id: bannerLayout
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Label {
                    text: "🔒"
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignTop
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: "Liquidación y Cierre de Período: " + root.monthName + " " + root.anio
                        font.bold: true
                        font.pixelSize: 13
                        color: Theme.textColor
                    }

                    Label {
                        text: "El cierre ejecuta la liquidación batch de todos los empleados del tipo seleccionado, persiste los recibos oficiales, genera el backup y congela las variables en modo solo lectura."
                        font.pixelSize: 11
                        color: Theme.subtextColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Target Selector Panel
        SectionPanel {
            Layout.fillWidth: true
            title: "1. Selección de Quincena o Período a Liquidar"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: "Tipo de Liquidación:"
                        color: Theme.textColor
                        font.pixelSize: 12
                        Layout.preferredWidth: 150
                    }

                    StyledComboBox {
                        id: cbTarget
                        Layout.fillWidth: true
                        model: root.targetsList
                        textRole: "label"
                        currentIndex: root.selectedTargetIndex
                        onActivated: {
                            root.selectedTargetIndex = currentIndex
                            root.updateSelectedTarget()
                        }
                    }

                    BadgePill {
                        text: root.selectedTargetIndex >= 0 && root.selectedTargetIndex < root.targetsList.length
                              ? root.targetsList[root.selectedTargetIndex].statusText
                              : ""
                        variant: root.currentTargetIsClosed ? "warning" : (root.currentTargetCanClose ? "success" : "secondary")
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: "Fecha Oficial de Cierre:"
                        color: Theme.textColor
                        font.pixelSize: 12
                        Layout.preferredWidth: 150
                    }

                    StyledDatePicker {
                        id: dpFechaCierre
                        Layout.fillWidth: true
                        enabled: !root.currentTargetIsClosed
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: "Fecha de Pago de Haberes:"
                        color: Theme.textColor
                        font.pixelSize: 12
                        Layout.preferredWidth: 150
                    }

                    StyledDatePicker {
                        id: dpFechaPago
                        Layout.fillWidth: true
                        enabled: !root.currentTargetIsClosed
                    }
                }
            }
        }

        // Validation & Summary Panel
        SectionPanel {
            Layout.fillWidth: true
            title: "2. Validación y Previsualización Batch"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    StyledButton {
                        text: "🔍 Validar Liquidación de Empleados"
                        variant: "secondary"
                        enabled: !root.currentTargetIsClosed && root.currentTargetCanClose && !root.isProcessing
                        onClicked: {
                            root.isProcessing = true
                            var res = AppController.validateBatch(
                                root.currentEsquemaTipo,
                                root.currentTargetType,
                                dpFechaCierre.selectedDateString,
                                dpFechaPago.selectedDateString
                            )
                            root.validationResult = res
                            root.isValidated = true
                            root.isProcessing = false
                        }
                    }

                    Label {
                        text: root.currentTargetIsClosed
                              ? "⚠️ Este período ya se encuentra cerrado. Para recalcular debe reabrirlo."
                              : (!root.currentTargetCanClose ? "⚠️ Debe cerrar la quincena anterior antes de continuar." : "")
                        color: Theme.accentColor
                        font.pixelSize: 11
                        visible: root.currentTargetIsClosed || !root.currentTargetCanClose
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }

                // Validation OK Summary
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: summaryLayout.implicitHeight + 16
                    radius: 6
                    visible: root.isValidated && root.validationResult && root.validationResult.valido === true
                    color: Theme.isDark ? Qt.rgba(34/255, 197/255, 94/255, 0.12) : Qt.rgba(34/255, 197/255, 94/255, 0.08)
                    border.color: Qt.rgba(34/255, 197/255, 94/255, 0.4)

                    ColumnLayout {
                        id: summaryLayout
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Label {
                            text: "✅ Validación Exitosa: " + (root.validationResult ? root.validationResult.empleados_procesados : 0) + " empleados listos para liquidar sin errores."
                            font.bold: true
                            font.pixelSize: 12
                            color: Theme.textColor
                        }

                        RowLayout {
                            spacing: 16
                            Label {
                                text: "Total Bruto: $" + (root.validationResult ? Number(root.validationResult.total_remunerativo + root.validationResult.total_no_remunerativo).toLocaleString(Qt.locale(), 'f', 2) : "0")
                                font.pixelSize: 11
                                color: Theme.textColor
                            }
                            Label {
                                text: "Total Retenciones: $" + (root.validationResult ? Number(root.validationResult.total_descuentos).toLocaleString(Qt.locale(), 'f', 2) : "0")
                                font.pixelSize: 11
                                color: Theme.textColor
                            }
                            Label {
                                text: "Total Neto a Cobrar: $" + (root.validationResult ? Number(root.validationResult.total_neto).toLocaleString(Qt.locale(), 'f', 2) : "0")
                                font.bold: true
                                font.pixelSize: 11
                                color: Theme.accentColor
                            }
                        }
                    }
                }

                // Validation Errors Summary
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Math.max(errContentCol.implicitHeight + 20, 90), 200)
                    radius: 6
                    visible: root.isValidated && root.validationResult && root.validationResult.valido === false
                    color: Theme.isDark ? Qt.rgba(239/255, 68/255, 68/255, 0.15) : Qt.rgba(239/255, 68/255, 68/255, 0.08)
                    border.color: Qt.rgba(239/255, 68/255, 68/255, 0.4)
                    clip: true

                    ColumnLayout {
                        id: errContentCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Label {
                            text: "❌ Se encontraron errores de cálculo en los siguientes empleados:"
                            font.bold: true
                            font.pixelSize: 12
                            color: "#ef4444"
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            ListView {
                                id: lvErrors
                                width: parent.width
                                spacing: 4
                                model: root.validationResult ? root.validationResult.errores_por_empleado : []
                                delegate: Label {
                                    width: lvErrors.width - 12
                                    text: "• Leg. " + modelData.legajo + " - " + modelData.nombre + ": " + (modelData.errores ? modelData.errores.join(", ") : "")
                                    font.pixelSize: 11
                                    color: Theme.textColor
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }

        // Export PDF Folder Section
        SectionPanel {
            Layout.fillWidth: true
            title: "3. Exportación Masiva de Recibos PDF (Opcional)"
            visible: root.isValidated && root.validationResult && root.validationResult.valido === true

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Label {
                    text: "Carpeta Destino:"
                    color: Theme.textColor
                    font.pixelSize: 12
                    Layout.preferredWidth: 120
                }

                StyledTextField {
                    id: tfExportFolder
                    Layout.fillWidth: true
                    text: root.exportFolder
                    placeholderText: "Seleccionar carpeta para guardar todos los PDFs..."
                    readOnly: true
                }

                StyledButton {
                    text: "📁 Explorar..."
                    variant: "secondary"
                    onClicked: {
                        var folder = AppController.selectFolder("Seleccionar carpeta para exportar recibos PDF", "")
                        if (folder !== "") {
                            root.exportFolder = folder
                        }
                    }
                }
            }
        }

        // Status message
        Label {
            text: root.statusMsg
            visible: root.statusMsg !== ""
            color: Theme.accentColor
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Layout.topMargin: 4

            StyledButton {
                text: "🔓 Reabrir este Cierre"
                variant: "danger"
                visible: root.currentTargetIsClosed && AppController.currentRole === "admin" && root.currentTargetCanReopen
                onClicked: {
                    var ok = AppController.reopenCierre(root.currentTargetType, root.currentEsquemaTipo)
                    if (ok) {
                        root.refreshTargets()
                        root.statusMsg = "Cierre reabierto exitosamente."
                    }
                }
            }

            Item { Layout.fillWidth: true }

            StyledButton {
                text: "Cerrar Ventana"
                variant: "secondary"
                onClicked: root.close()
            }

            StyledButton {
                text: "🔒 Confirmar y Ejecutar Cierre"
                variant: "primary"
                enabled: !root.currentTargetIsClosed && root.isValidated && root.validationResult && root.validationResult.valido === true && !root.isProcessing
                onClicked: {
                    root.isProcessing = true
                    var res = AppController.executeBatchClose(
                        root.currentEsquemaTipo,
                        root.currentTargetType,
                        dpFechaCierre.selectedDateString,
                        dpFechaPago.selectedDateString,
                        root.exportFolder
                    )
                    root.isProcessing = false
                    if (res.ok) {
                        root.refreshTargets()
                        root.statusMsg = res.mensaje || "Cierre completado con éxito."
                        root.isValidated = false
                    } else {
                        root.statusMsg = "Error: " + (res.mensaje || "Fallo en el cierre.")
                    }
                }
            }
        }
    }
}
