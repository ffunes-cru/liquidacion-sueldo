import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"
import "../dialogs"

Item {
    id: root

    property string currentEsquema: "MENSUAL"

    Component.onCompleted: {
        refreshSchemas()
    }

    function refreshSchemas() {
        AppController.schemaModel.refresh()
        var schemas = AppController.listSchemas()
        if (schemas.length > 0) {
            var found = false
            for (var i = 0; i < schemas.length; i++) {
                var code = schemas[i].codigo || schemas[i].code
                if (code === currentEsquema) {
                    found = true
                    break
                }
            }
            if (!found) {
                currentEsquema = schemas[0].codigo || schemas[0].code || "MENSUAL"
            }
        }
        refreshCells()
    }

    function refreshCells() {
        AppController.cellModel.esquemaCodigo = currentEsquema
        AppController.cellModel.refresh()
    }

    function openNewConceptDialog(secCode) {
        conceptDialog.cellId = -1
        conceptDialog.esquemaCodigo = currentEsquema
        conceptDialog.seccionCodigo = secCode || "REMUNERATIVO"
        conceptDialog.codigoVariable = ""
        conceptDialog.descripcion = ""
        conceptDialog.condicion = "1"
        conceptDialog.formulaMonto = ""
        conceptDialog.formulaUnidad = ""
        conceptDialog.formulaBase = ""
        conceptDialog.orden = (AppController.cellModel.count + 1) * 10
        conceptDialog.simplePorcentaje = "0.0"
        conceptDialog.simpleBaseVariable = ""
        conceptDialog.simpleMontoFijo = "0.0"
        conceptDialog.visibleRecibo = true
        conceptDialog.open()
    }

    function openEditConceptDialog(cellData) {
        conceptDialog.cellId = cellData.cellId || cellData.id
        conceptDialog.esquemaCodigo = currentEsquema
        conceptDialog.seccionCodigo = cellData.seccionCodigo || cellData.seccion_codigo || "REMUNERATIVO"
        conceptDialog.codigoVariable = cellData.codigoVariable || cellData.codigo_variable || ""
        conceptDialog.descripcion = cellData.descripcion || ""
        conceptDialog.condicion = cellData.condicion || "1"
        conceptDialog.formulaMonto = cellData.formulaMonto || cellData.formula_monto || ""
        conceptDialog.formulaUnidad = cellData.formulaUnidad || cellData.formula_unidad || ""
        conceptDialog.formulaBase = cellData.formulaBase || cellData.formula_base || ""
        conceptDialog.orden = cellData.orden || 10
        conceptDialog.simplePorcentaje = (cellData.simplePorcentaje || cellData.simple_porcentaje || 0.0).toString()
        conceptDialog.simpleBaseVariable = cellData.simpleBaseVariable || cellData.simple_base_variable || ""
        conceptDialog.simpleMontoFijo = (cellData.simpleMontoFijo || cellData.simple_monto_fijo || 0.0).toString()
        conceptDialog.visibleRecibo = cellData.visibleRecibo !== undefined ? cellData.visibleRecibo : true
        conceptDialog.open()
    }

    function addSeparator(titleStr) {
        var t = titleStr ? titleStr.trim() : "Nueva Sección / Separador"
        var newOrd = (AppController.cellModel.count + 1) * 10
        AppController.cellModel.saveCell(
            0, "COMPOSICION", "SEP_" + newOrd, t, "1", "", "", "",
            newOrd, currentEsquema, "separator", 0, "", 0, true
        )
        refreshCells()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════
        // TOP CONTROL BAR
        // ═══════════════════════════════════════════════════════
        ActionBar {
            title: "Estructura del Recibo de Sueldo"

            Button {
                text: "📋 Esquema: " + root.currentEsquema
                highlighted: true
                onClicked: selectSchemaDialog.open()
            }

            Button {
                text: "➕ Agregar Separador"
                visible: AppController.currentRole === "admin"
                onClicked: separatorTitleDialog.openNew()
            }

            Button {
                text: "+ Nuevo Concepto"
                highlighted: true
                visible: AppController.currentRole === "admin"
                onClicked: openNewConceptDialog("REMUNERATIVO")
            }
        }

        // ═══════════════════════════════════════════════════════
        // DYNAMIC LINEAR PAYSTUB STRUCTURE
        // ═══════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.panelBg
            radius: 8
            border.color: Theme.borderColor

            ScrollView {
                anchors.fill: parent
                anchors.margins: 15
                clip: true

                ColumnLayout {
                    width: parent.width - 30
                    spacing: 12

                    // Header Info Card
                    SectionPanel {
                        padding: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20

                            Label {
                                text: "DOCUMENTO MODELO: RECIBO DE SUELDO (" + root.currentEsquema + ")"
                                font.bold: true; font.pixelSize: 13; color: Theme.accentColor
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: AppController.cellModel.count + " elementos (conceptos y separadores)"
                                font.pixelSize: 12; color: Theme.subtextColor
                            }
                        }
                    }

                    // Table Header Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        color: Theme.headerBg
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 10

                            Label { text: "Orden"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 60 }
                            Label { text: "Cód. Variable"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 120 }
                            Label { text: "Descripción del Concepto / Sección"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.fillWidth: true }
                            Label { text: "Unidad / Cant."; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 100 }
                            Label { text: "Base Imponible"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 120 }
                            Label { text: "Fórmula / Cálculo Monto"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 160 }
                            Label { text: "Acciones"; font.bold: true; font.pixelSize: 11; color: Theme.subtextColor; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
                        }
                    }

                    // ── Dynamic Linear Items List ─────────────────────
                    ListView {
                        id: paystubListView
                        Layout.fillWidth: true
                        implicitHeight: contentHeight
                        interactive: false
                        spacing: 8
                        model: AppController.cellModel

                        delegate: Component {
                            Loader {
                                width: paystubListView.width
                                property int itemIndex: index
                                property int itemId: model.cellId || model.id
                                property string itemSeccionCodigo: model.seccionCodigo || ""
                                property string itemCodigoVariable: model.codigoVariable || ""
                                property string itemDescripcion: model.descripcion || ""
                                property int itemOrden: model.orden || 10
                                property string itemTipoCalculo: model.tipoCalculo || "formula"
                                property double itemSimplePorcentaje: model.simplePorcentaje || 0
                                property double itemSimpleMontoFijo: model.simpleMontoFijo || 0
                                property string itemFormulaUnidad: model.formulaUnidad || ""
                                property string itemFormulaBase: model.formulaBase || ""
                                property string itemFormulaMonto: model.formulaMonto || ""

                                sourceComponent: model.tipoCalculo === "separator" ? separatorComponent : conceptComponent
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Dynamic Separator Component ─────────────────────────────
    Component {
        id: separatorComponent

        Rectangle {
            width: parent.width
            height: 40
            radius: 6
            color: Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.15)
            border.color: Theme.accentColor
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8

                Button {
                    implicitWidth: 26; implicitHeight: 26
                    text: "▲"; flat: true
                    enabled: itemIndex > 0
                    onClicked: AppController.cellModel.moveCellUp(itemIndex)
                }
                Button {
                    implicitWidth: 26; implicitHeight: 26
                    text: "▼"; flat: true
                    enabled: itemIndex < AppController.cellModel.count - 1
                    onClicked: AppController.cellModel.moveCellDown(itemIndex)
                }

                Label {
                    text: "⚫  " + (itemDescripcion || "SECCIÓN")
                    font.bold: true; font.pixelSize: 14; color: Theme.textColor
                    Layout.fillWidth: true
                }

                Button {
                    text: "+ Concepto"
                    flat: true
                    visible: AppController.currentRole === "admin"
                    onClicked: root.openNewConceptDialog(itemSeccionCodigo || "REMUNERATIVO")
                }

                Button {
                    implicitWidth: 28; implicitHeight: 28
                    text: "✏️"; flat: true
                    visible: AppController.currentRole === "admin"
                    onClicked: separatorTitleDialog.openEdit(itemId, itemDescripcion)
                }

                Button {
                    implicitWidth: 28; implicitHeight: 28
                    text: "🗑️"; flat: true
                    visible: AppController.currentRole === "admin"
                    onClicked: AppController.cellModel.removeCell(itemId)
                }
            }
        }
    }

    // ── Dynamic Concept Row Component ───────────────────────────
    Component {
        id: conceptComponent

        Rectangle {
            width: parent.width
            height: 48
            radius: 6
            color: Theme.cardBg
            border.color: Theme.borderColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 8

                Button {
                    implicitWidth: 24; implicitHeight: 24
                    text: "▲"; flat: true
                    enabled: itemIndex > 0
                    onClicked: AppController.cellModel.moveCellUp(itemIndex)
                }
                Button {
                    implicitWidth: 24; implicitHeight: 24
                    text: "▼"; flat: true
                    enabled: itemIndex < AppController.cellModel.count - 1
                    onClicked: AppController.cellModel.moveCellDown(itemIndex)
                }

                Label {
                    text: itemOrden.toString()
                    font.pixelSize: 11; color: Theme.subtextColor
                    Layout.preferredWidth: 25
                }

                BadgePill {
                    text: itemCodigoVariable || ""
                    badgeColor: Theme.accentColor
                    Layout.preferredWidth: 110
                }

                Label {
                    text: itemDescripcion || ""
                    font.bold: true; font.pixelSize: 13; color: Theme.textColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Label {
                    text: itemFormulaUnidad || "-"
                    font.family: "Monospace"; font.pixelSize: 11; color: Theme.subtextColor
                    Layout.preferredWidth: 90
                    elide: Text.ElideRight
                }

                Label {
                    text: itemFormulaBase || "-"
                    font.family: "Monospace"; font.pixelSize: 11; color: Theme.subtextColor
                    Layout.preferredWidth: 110
                    elide: Text.ElideRight
                }

                BadgePill {
                    text: itemTipoCalculo === "simple" ? (itemSimplePorcentaje + "% / $" + itemSimpleMontoFijo) : (itemFormulaMonto || "Fórmula")
                    badgeColor: itemTipoCalculo === "simple" ? Theme.warningColor : Theme.successColor
                    Layout.preferredWidth: 150
                }

                AdminActions {
                    showDuplicate: false
                    onEditClicked: root.openEditConceptDialog(AppController.cellModel.get(itemIndex))
                    onDeleteClicked: AppController.cellModel.removeCell(itemId)
                }
            }
        }
    }

    // ── Dialogs ──────────────────────────────────────────────────
    ConceptDialog {
        id: conceptDialog
        onConceptSaved: root.refreshCells()
    }

    SchemaConfigDialog {
        id: schemaConfigDialog
    }

    // Dynamic Separator Title Prompt Dialog
    AppDialog {
        id: separatorTitleDialog
        title: editCellId > 0 ? "Editar Título de Sección" : "Nuevo Separador de Sección"
        dialogWidth: 420

        property int editCellId: -1

        function openNew() {
            editCellId = -1
            fldSepTitle.value = ""
            open()
        }

        function openEdit(cellId, currentTitle) {
            editCellId = cellId
            fldSepTitle.value = currentTitle || ""
            open()
        }

        contentItem: ColumnLayout {
            spacing: 12

            FormField {
                id: fldSepTitle
                label: "Título de Sección:"
                placeholder: "Ej: Haberes Remunerativos"
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Cancelar"
                    onClicked: separatorTitleDialog.close()
                }
                Button {
                    text: "Guardar Separador"
                    highlighted: true
                    onClicked: {
                        var title = fldSepTitle.value.trim()
                        if (title !== "") {
                            if (separatorTitleDialog.editCellId > 0) {
                                var existingMap = AppController.cellModel.get(AppController.cellModel.count)
                                AppController.cellModel.saveCell(
                                    separatorTitleDialog.editCellId, "COMPOSICION", "SEP_" + separatorTitleDialog.editCellId,
                                    title, "1", "", "", "", 10, root.currentEsquema, "separator", 0, "", 0, true
                                )
                            } else {
                                root.addSeparator(title)
                            }
                            separatorTitleDialog.close()
                            root.refreshCells()
                        }
                    }
                }
            }
        }
    }

    // ── Dialog for Selecting Schema ──────────────────────────────
    AppDialog {
        id: selectSchemaDialog
        title: "Seleccionar Esquema de Cálculo"
        dialogWidth: 520
        dialogHeight: 380
        standardButtons: Dialog.Close

        onOpened: {
            AppController.schemaModel.refresh()
            schemaListView.model = AppController.listSchemas()
        }

        contentItem: ColumnLayout {
            spacing: 12

            Label {
                text: "Seleccione el Esquema de Cálculo a visualizar o configurar:"
                color: Theme.textColor
                font.pixelSize: 13
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: schemaListView
                    spacing: 8

                    delegate: Rectangle {
                        width: schemaListView.width - 12
                        height: 56
                        color: ((modelData.codigo || modelData.code) === root.currentEsquema) ? Theme.selectedBg : (mouseArea.containsMouse ? Theme.hoverBg : Theme.cardBg)
                        border.color: ((modelData.codigo || modelData.code) === root.currentEsquema) ? Theme.accentColor : Theme.borderColor
                        border.width: ((modelData.codigo || modelData.code) === root.currentEsquema) ? 2 : 1
                        radius: 8

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: (modelData.codigo || modelData.code || "") + " - " + (modelData.nombre || modelData.name || "")
                                    color: Theme.textColor
                                    font.bold: true
                                    font.pixelSize: 14
                                }

                                Label {
                                    text: "Tipo Liquidación: " + (modelData.tipo_liquidacion || modelData.tipoLiquidacion || "mensual")
                                    color: Theme.subtextColor
                                    font.pixelSize: 12
                                }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var code = modelData.codigo
                                if (code) {
                                    root.currentEsquema = code
                                    root.refreshCells()
                                    selectSchemaDialog.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
