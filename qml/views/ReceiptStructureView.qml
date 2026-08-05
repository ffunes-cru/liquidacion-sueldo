import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"
import "../dialogs"

Item {
    id: root

    property string currentEsquema: "MENSUAL"
    property bool isDragging: false
    property int draggedRowIndex: -1
    property int dropTargetIndex: -1
    property var ghostData: ({ title: "", variable: "", color: Qt.color("#2ECC71"), isSeparator: false })

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

    function openNewConceptDialog(secCode, afterIndex) {
        conceptDialog.cellId = -1
        conceptDialog.esquemaCodigo = currentEsquema
        conceptDialog.seccionCodigo = secCode || "COMPOSICION"
        conceptDialog.tipoCalculo = "formula"
        conceptDialog.codigoVariable = ""
        conceptDialog.descripcion = ""
        conceptDialog.condicion = "1"
        conceptDialog.formulaMonto = ""
        conceptDialog.formulaUnidad = ""
        conceptDialog.formulaBase = ""

        var count = AppController.cellModel.count
        if (afterIndex !== undefined && afterIndex >= 0 && afterIndex < count) {
            var currOrd = AppController.cellModel.get(afterIndex).orden
            if (afterIndex + 1 < count) {
                var nextOrd = AppController.cellModel.get(afterIndex + 1).orden
                var midOrd = Math.floor((currOrd + nextOrd) / 2)
                conceptDialog.orden = (midOrd > currOrd) ? midOrd : (currOrd + 5)
            } else {
                conceptDialog.orden = currOrd + 10
            }
        } else {
            conceptDialog.orden = (count + 1) * 10
        }

        conceptDialog.simplePorcentaje = "0.0"
        conceptDialog.simpleBaseVariable = ""
        conceptDialog.simpleMontoFijo = "0.0"
        conceptDialog.visibleRecibo = true
        conceptDialog.enGrafico = false
        conceptDialog.esGraficoTotal = false
        conceptDialog.open()
    }

    function openEditConceptDialog(cellData) {
        conceptDialog.cellId = cellData.cellId || cellData.id
        conceptDialog.esquemaCodigo = currentEsquema
        conceptDialog.seccionCodigo = cellData.seccionCodigo || cellData.seccion_codigo || "REMUNERATIVO"
        conceptDialog.tipoCalculo = cellData.tipoCalculo || cellData.tipo_calculo || "formula"
        conceptDialog.codigoVariable = cellData.codigoVariable || cellData.codigo_variable || ""
        conceptDialog.descripcion = cellData.descripcion || ""
        conceptDialog.condicion = cellData.condicion || "1"
        conceptDialog.formulaMonto = cellData.formulaMonto || cellData.formula_monto || ""
        conceptDialog.formulaUnidad = cellData.formulaUnidad || cellData.formula_unidad || ""
        conceptDialog.formulaBase = cellData.formulaBase || cellData.formula_base || ""
        conceptDialog.orden = cellData.orden || 10
        conceptDialog.simplePorcentaje = (cellData.simplePorcentaje !== undefined ? cellData.simplePorcentaje : (cellData.simple_porcentaje !== undefined ? cellData.simple_porcentaje : 0.0)).toString()
        conceptDialog.simpleBaseVariable = cellData.simpleBaseVariable || cellData.simple_base_variable || ""
        conceptDialog.simpleMontoFijo = (cellData.simpleMontoFijo !== undefined ? cellData.simpleMontoFijo : (cellData.simple_monto_fijo !== undefined ? cellData.simple_monto_fijo : 0.0)).toString()
        var vis = (cellData.visibleRecibo !== undefined) ? cellData.visibleRecibo : cellData.visible_recibo;
        conceptDialog.visibleRecibo = (vis === true || vis === 1 || vis === "1" || vis === "true");
        var eg = (cellData.enGrafico !== undefined) ? cellData.enGrafico : cellData.en_grafico;
        conceptDialog.enGrafico = (eg === true || eg === 1 || eg === "1" || eg === "true");
        var egt = (cellData.esGraficoTotal !== undefined) ? cellData.esGraficoTotal : cellData.es_grafico_total;
        conceptDialog.esGraficoTotal = (egt === true || egt === 1 || egt === "1" || egt === "true");
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

    // ── Free Floating Drag Ghost Card Overlay ─────────────────────────
    Rectangle {
        id: dragGhost
        z: 9999
        visible: root.isDragging
        width: Math.min(520, paystubListView.width * 0.75)
        height: 46
        radius: 8
        color: Qt.rgba(root.ghostData.color.r, root.ghostData.color.g, root.ghostData.color.b, 0.90)
        border.color: root.ghostData.color
        border.width: 2
        rotation: -2
        opacity: 0.92

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 10

            Text {
                text: "⠿"
                font.pixelSize: 18; font.bold: true; color: "#FFFFFF"
            }

            BadgePill {
                text: root.ghostData.variable
                badgeColor: root.ghostData.color
                visible: !root.ghostData.isSeparator && root.ghostData.variable !== ""
                Layout.preferredWidth: 120
            }

            Label {
                text: root.ghostData.title
                font.bold: true; font.pixelSize: 13; color: "#FFFFFF"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Label {
                text: "📍 SOLTAR"
                font.bold: true; font.pixelSize: 10; color: "#FFFFFF"
            }
        }
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

            StyledButton {
                variant: "secondary"
                text: "📋 Esquema: " + root.currentEsquema
                onClicked: selectSchemaDialog.open()
            }

            StyledButton {
                variant: "secondary"
                text: "➕ Agregar Separador"
                visible: AppController.currentRole === "admin"
                onClicked: separatorTitleDialog.openNew()
            }

            StyledButton {
                variant: "primary"
                text: "+ Nuevo Concepto"
                visible: AppController.currentRole === "admin"
                onClicked: openNewConceptDialog("COMPOSICION")
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

                    // ── Dynamic Linear Items List ─────────────────────
                    ListView {
                        id: paystubListView
                        Layout.fillWidth: true
                        implicitHeight: contentHeight
                        interactive: false
                        spacing: 8
                        model: AppController.cellModel

                        // Snap Line Insertion Indicator
                        Rectangle {
                            id: snapLine
                            z: 500
                            visible: root.isDragging && root.dropTargetIndex >= 0
                            width: paystubListView.width
                            height: 4
                            radius: 2
                            color: "#00E5FF" // Neon Cyan
                            y: root.dropTargetIndex * 58

                            Rectangle {
                                anchors.centerIn: parent
                                width: 120; height: 18; radius: 9
                                color: "#00E5FF"
                                Label {
                                    anchors.centerIn: parent
                                    text: "📍 INSERTAR AQUÍ"
                                    font.bold: true; font.pixelSize: 9; color: "#0A1118"
                                }
                            }
                        }

                        delegate: Component {
                            Loader {
                                width: paystubListView.width
                                property int itemIndex: index
                                property int itemId: model.cellId !== undefined ? model.cellId : model.id
                                property string itemSeccionCodigo: model.seccionCodigo !== undefined ? model.seccionCodigo : ""
                                property string itemCodigoVariable: model.codigoVariable !== undefined ? model.codigoVariable : ""
                                property string itemDescripcion: model.descripcion !== undefined ? model.descripcion : ""
                                property int itemOrden: model.orden !== undefined ? model.orden : 10
                                property string itemTipoCalculo: model.tipoCalculo !== undefined ? model.tipoCalculo : "formula"
                                property double itemSimplePorcentaje: model.simplePorcentaje !== undefined ? model.simplePorcentaje : 0
                                property string itemSimpleBaseVariable: model.simpleBaseVariable !== undefined ? model.simpleBaseVariable : ""
                                property double itemSimpleMontoFijo: model.simpleMontoFijo !== undefined ? model.simpleMontoFijo : 0
                                property string itemFormulaUnidad: model.formulaUnidad !== undefined ? model.formulaUnidad : ""
                                property string itemFormulaBase: model.formulaBase !== undefined ? model.formulaBase : ""
                                property string itemFormulaMonto: model.formulaMonto !== undefined ? model.formulaMonto : ""
                                property string itemColorHex: model.colorHex !== undefined ? model.colorHex : ""
                                property bool itemVisibleRecibo: model.visibleRecibo !== undefined ? model.visibleRecibo : true
                                property bool itemEnGrafico: model.enGrafico !== undefined ? model.enGrafico : false
                                property bool itemEsGraficoTotal: model.esGraficoTotal !== undefined ? model.esGraficoTotal : false

                                sourceComponent: (itemTipoCalculo === "separator" || itemCodigoVariable.indexOf("SEP_") === 0) ? separatorComponent : conceptComponent
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

        Item {
            width: parent.width
            height: 50
            opacity: (root.isDragging && root.draggedRowIndex === itemIndex) ? 0.35 : 1.0

            property color cardAccentColor: itemColorHex !== "" ? Qt.color(itemColorHex) : Theme.accentColor

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Qt.rgba(cardAccentColor.r, cardAccentColor.g, cardAccentColor.b, 0.22)
                border.color: cardAccentColor
                border.width: 1.5

                MouseArea {
                    id: sepCardDragArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: sepCardDragArea.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    onPressed: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            colorPaletteDialog.openForCell(itemId, itemColorHex || "#8B5CF6");
                            return;
                        }
                        root.draggedRowIndex = itemIndex;
                        root.dropTargetIndex = itemIndex;
                        root.ghostData = {
                            title: "SECCIÓN: " + (itemDescripcion || "GENERAL").toUpperCase(),
                            variable: "",
                            color: cardAccentColor,
                            isSeparator: true
                        };
                        root.isDragging = true;
                        var p = mapToItem(root, mouse.x, mouse.y);
                        dragGhost.x = p.x - (dragGhost.width / 2);
                        dragGhost.y = p.y - (dragGhost.height / 2);
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed && root.isDragging) {
                            var p = mapToItem(root, mouse.x, mouse.y);
                            dragGhost.x = p.x - (dragGhost.width / 2);
                            dragGhost.y = p.y - (dragGhost.height / 2);

                            var mapped = mapToItem(paystubListView, mouse.x, mouse.y);
                            var hoverIdx = paystubListView.indexAt(mapped.x, mapped.y);
                            if (hoverIdx < 0) {
                                hoverIdx = Math.max(0, Math.min(AppController.cellModel.count - 1, Math.floor((mapped.y + 25) / 58)));
                            }
                            root.dropTargetIndex = hoverIdx;
                        }
                    }

                    onReleased: function() {
                        if (root.isDragging) {
                            if (root.dropTargetIndex >= 0 && root.dropTargetIndex !== root.draggedRowIndex) {
                                AppController.cellModel.moveCell(root.draggedRowIndex, root.dropTargetIndex);
                            }
                            root.isDragging = false;
                            root.draggedRowIndex = -1;
                            root.dropTargetIndex = -1;
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 8
                    z: 5

                    Label {
                        text: "⠿"
                        font.pixelSize: 18
                        font.bold: true
                        color: sepCardDragArea.pressed ? cardAccentColor : (sepCardDragArea.containsMouse ? Theme.textColor : Theme.subtextColor)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Label {
                        text: "🔷  SECCIÓN: " + (itemDescripcion || "GENERAL").toUpperCase()
                        font.bold: true; font.pixelSize: 13; color: Theme.textColor
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitWidth: 110; implicitHeight: 28; radius: 4
                        color: btnAddConceptArea.containsMouse ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.3) : Qt.rgba(255, 255, 255, 0.08)
                        border.color: Theme.borderColor

                        RowLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: "➕"; font.pixelSize: 11 }
                            Text { text: "Concepto"; font.pixelSize: 11; font.bold: true; color: Theme.textColor }
                        }

                        MouseArea {
                            id: btnAddConceptArea
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.openNewConceptDialog(itemSeccionCodigo || "COMPOSICION", itemIndex)
                        }
                    }

                    Rectangle {
                        implicitWidth: 30; implicitHeight: 28; radius: 4
                        color: btnSepEditArea.containsMouse ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.3) : Qt.rgba(255, 255, 255, 0.08)
                        border.color: Theme.borderColor

                        Text { anchors.centerIn: parent; text: "✏️"; font.pixelSize: 13 }

                        MouseArea {
                            id: btnSepEditArea
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: separatorTitleDialog.openEdit(itemId, itemDescripcion)
                        }
                    }

                    Rectangle {
                        implicitWidth: 30; implicitHeight: 28; radius: 4
                        color: btnSepDelArea.containsMouse ? Qt.rgba(Theme.dangerColor.r, Theme.dangerColor.g, Theme.dangerColor.b, 0.35) : Qt.rgba(255, 255, 255, 0.08)
                        border.color: Theme.borderColor

                        Text { anchors.centerIn: parent; text: "🗑️"; font.pixelSize: 13 }

                        MouseArea {
                            id: btnSepDelArea
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                confirmDeleteCellDialog.targetId = itemId
                                confirmDeleteCellDialog.targetDesc = itemDescripcion || "Título Separador"
                                confirmDeleteCellDialog.open()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Dynamic Concept Row Component ───────────────────────────
    Component {
        id: conceptComponent

        Item {
            id: conceptItem
            width: parent.width
            height: 50
            opacity: (root.isDragging && root.draggedRowIndex === itemIndex) ? 0.35 : (!itemVisibleRecibo ? 0.55 : 1.0)

            property bool isTotalItem: (itemCodigoVariable.indexOf("total_") === 0) || (itemDescripcion.toUpperCase().indexOf("TOTAL") !== -1)
            property string secUpper: (itemSeccionCodigo || "").toUpperCase()

            property string calcType: {
                var rawType = (parent && typeof parent.itemTipoCalculo !== "undefined" && parent.itemTipoCalculo !== null) ? parent.itemTipoCalculo : (typeof tipoCalculo !== "undefined" ? tipoCalculo : "formula");
                rawType = (rawType || "").toLowerCase();

                if (rawType === "porcentaje" || rawType === "percentage" || rawType === "simple") return "percentage";
                if (rawType === "fijo" || rawType === "fixed") return "fixed";

                var pVal = (parent && typeof parent.itemSimplePorcentaje !== "undefined") ? parent.itemSimplePorcentaje : (typeof simplePorcentaje !== "undefined" ? simplePorcentaje : 0);
                if (pVal && Number(pVal) > 0) return "percentage";

                var fVal = (parent && typeof parent.itemSimpleMontoFijo !== "undefined") ? parent.itemSimpleMontoFijo : (typeof simpleMontoFijo !== "undefined" ? simpleMontoFijo : 0);
                if (fVal && Number(fVal) > 0) return "fixed";

                return "formula";
            }

            property var percVal: {
                var p = (parent && typeof parent.itemSimplePorcentaje !== "undefined") ? parent.itemSimplePorcentaje : (typeof simplePorcentaje !== "undefined" ? simplePorcentaje : 0);
                return Number(p) || 0;
            }

            property string percBase: {
                var b = (parent && typeof parent.itemSimpleBaseVariable !== "undefined") ? parent.itemSimpleBaseVariable : (typeof simpleBaseVariable !== "undefined" ? simpleBaseVariable : "");
                return b || "";
            }

            property var fixedVal: {
                var f = (parent && typeof parent.itemSimpleMontoFijo !== "undefined") ? parent.itemSimpleMontoFijo : (typeof simpleMontoFijo !== "undefined" ? simpleMontoFijo : 0);
                return Number(f) || 0;
            }

            property string formUnit: {
                var u = (parent && typeof parent.itemFormulaUnidad !== "undefined") ? parent.itemFormulaUnidad : (typeof formulaUnidad !== "undefined" ? formulaUnidad : "");
                return u || "";
            }

            property string formBase: {
                var b = (parent && typeof parent.itemFormulaBase !== "undefined") ? parent.itemFormulaBase : (typeof formulaBase !== "undefined" ? formulaBase : "");
                return b || "";
            }

            property color themeColor: {
                if (itemColorHex !== "") return Qt.color(itemColorHex)
                if (secUpper.indexOf("REMUNERATIVO") !== -1 && secUpper.indexOf("NO_REMUNERATIVO") === -1 && secUpper.indexOf("NO REMUNERATIVO") === -1)
                    return Qt.color("#00E5FF") // Neon Cyan
                if (secUpper.indexOf("NO_REMUNERATIVO") !== -1 || secUpper.indexOf("NO REMUNERATIVO") !== -1)
                    return Qt.color("#10B981") // Emerald Green
                if (secUpper.indexOf("DESCUENTO") !== -1 || secUpper.indexOf("DEDUCCION") !== -1 || secUpper.indexOf("RETENCION") !== -1)
                    return Qt.color("#EF4444") // Coral Red
                if (secUpper.indexOf("COSTO") !== -1 || secUpper.indexOf("PATRONAL") !== -1 || secUpper.indexOf("APORTE") !== -1)
                    return Qt.color("#8B5CF6") // Purple
                return Theme.accentColor
            }

            Rectangle {
                anchors.fill: parent
                radius: 6

                color: conceptItem.isTotalItem ? Qt.rgba(conceptItem.themeColor.r, conceptItem.themeColor.g, conceptItem.themeColor.b, 0.15) : Theme.panelBg
                border.color: conceptItem.isTotalItem ? conceptItem.themeColor : Theme.borderColor
                border.width: conceptItem.isTotalItem ? 2 : 1

                // Left 4px section/custom color accent bar
                Rectangle {
                    width: conceptItem.isTotalItem ? 6 : 4
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 2
                    color: conceptItem.themeColor
                }

                MouseArea {
                    id: conceptCardDragArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: conceptCardDragArea.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    onPressed: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            colorPaletteDialog.openForCell(itemId, itemColorHex || "#00E5FF");
                            return;
                        }
                        root.draggedRowIndex = itemIndex;
                        root.dropTargetIndex = itemIndex;
                        root.ghostData = {
                            title: itemDescripcion || itemCodigoVariable,
                            variable: itemCodigoVariable || "",
                            color: conceptItem.themeColor,
                            isSeparator: false
                        };
                        root.isDragging = true;
                        var p = mapToItem(root, mouse.x, mouse.y);
                        dragGhost.x = p.x - (dragGhost.width / 2);
                        dragGhost.y = p.y - (dragGhost.height / 2);
                    }

                    onPositionChanged: function(mouse) {
                        if (pressed && root.isDragging) {
                            var p = mapToItem(root, mouse.x, mouse.y);
                            dragGhost.x = p.x - (dragGhost.width / 2);
                            dragGhost.y = p.y - (dragGhost.height / 2);

                            var mapped = mapToItem(paystubListView, mouse.x, mouse.y);
                            var hoverIdx = paystubListView.indexAt(mapped.x, mapped.y);
                            if (hoverIdx < 0) {
                                hoverIdx = Math.max(0, Math.min(AppController.cellModel.count - 1, Math.floor((mapped.y + 25) / 58)));
                            }
                            root.dropTargetIndex = hoverIdx;
                        }
                    }

                    onReleased: function() {
                        if (root.isDragging) {
                            if (root.dropTargetIndex >= 0 && root.dropTargetIndex !== root.draggedRowIndex) {
                                AppController.cellModel.moveCell(root.draggedRowIndex, root.dropTargetIndex);
                            }
                            root.isDragging = false;
                            root.draggedRowIndex = -1;
                            root.dropTargetIndex = -1;
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 10
                    spacing: 10
                    z: 5

                    Label {
                        text: "⠿"
                        font.pixelSize: 18
                        font.bold: true
                        color: conceptCardDragArea.pressed ? conceptItem.themeColor : (conceptCardDragArea.containsMouse ? Theme.textColor : Theme.subtextColor)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    BadgePill {
                        text: itemCodigoVariable || ""
                        badgeColor: conceptItem.themeColor
                        Layout.preferredWidth: 140
                    }

                    Label {
                        text: itemDescripcion || ""
                        font.bold: conceptItem.isTotalItem
                        font.pixelSize: conceptItem.isTotalItem ? 14 : 13
                        color: conceptItem.isTotalItem ? conceptItem.themeColor : Theme.textColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    BadgePill {
                        visible: !itemVisibleRecibo
                        text: "Oculto"
                        badgeColor: Theme.subtextColor
                    }

                    BadgePill {
                        visible: itemEnGrafico
                        text: "Gráfico"
                        badgeColor: Theme.accentColor
                    }

                    BadgePill {
                        visible: itemEsGraficoTotal
                        text: "Total Gráfico"
                        badgeColor: Theme.warningColor
                    }

                    Label {
                        text: {
                            if (conceptItem.calcType === "percentage") {
                                return "% " + conceptItem.percVal
                            } else if (conceptItem.calcType === "fixed") {
                                return "Fijo"
                            } else {
                                return conceptItem.formUnit !== "" ? conceptItem.formUnit : "-"
                            }
                        }
                        font.family: "Monospace"; font.pixelSize: 11
                        color: conceptItem.calcType === "percentage" ? "#00E5FF" : Theme.subtextColor
                        Layout.preferredWidth: 100
                        elide: Text.ElideRight
                    }

                    Label {
                        text: {
                            if (conceptItem.calcType === "percentage") {
                                return conceptItem.percBase !== "" ? conceptItem.percBase : "-"
                            } else if (conceptItem.calcType === "fixed") {
                                return "$ " + conceptItem.fixedVal
                            } else {
                                return conceptItem.formBase !== "" ? conceptItem.formBase : "-"
                            }
                        }
                        font.family: "Monospace"; font.pixelSize: 11
                        color: conceptItem.calcType === "fixed" ? "#10B981" : (conceptItem.calcType === "percentage" ? "#00E5FF" : Theme.subtextColor)
                        Layout.preferredWidth: 120
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        spacing: 6
                        Layout.preferredWidth: 68

                        Rectangle {
                            implicitWidth: 30; implicitHeight: 28; radius: 4
                            color: btnConceptEditArea.containsMouse ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.3) : Qt.rgba(255, 255, 255, 0.08)
                            border.color: Theme.borderColor

                            Text { anchors.centerIn: parent; text: "✏️"; font.pixelSize: 13 }

                            MouseArea {
                                id: btnConceptEditArea
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.openEditConceptDialog(AppController.cellModel.get(itemIndex))
                            }
                        }

                        Rectangle {
                            implicitWidth: 30; implicitHeight: 28; radius: 4
                            color: btnConceptDelArea.containsMouse ? Qt.rgba(Theme.dangerColor.r, Theme.dangerColor.g, Theme.dangerColor.b, 0.35) : Qt.rgba(255, 255, 255, 0.08)
                            border.color: Theme.borderColor

                            Text { anchors.centerIn: parent; text: "🗑️"; font.pixelSize: 13 }

                            MouseArea {
                                id: btnConceptDelArea
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    confirmDeleteCellDialog.targetId = itemId
                                    confirmDeleteCellDialog.targetDesc = itemDescripcion || itemCodigo
                                    confirmDeleteCellDialog.open()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ConfirmDialog {
        id: confirmDeleteCellDialog
        property int targetId: -1
        property string targetDesc: ""
        title: "🗑️ Eliminar del Esquema"
        message: "¿Está seguro de eliminar '" + targetDesc + "' del esquema de liquidación?"
        confirmButtonText: "Sí, Eliminar"
        confirmButtonVariant: "danger"
        onConfirmed: {
            if (targetId > 0) AppController.cellModel.removeCell(targetId)
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
                StyledButton {
                    variant: "secondary"
                    text: "Cancelar"
                    onClicked: separatorTitleDialog.close()
                }
                StyledButton {
                    variant: "primary"
                    text: "💾 Guardar Separador"
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

    // ── Color Palette Popover Dialog ───────────────────────────
    AppDialog {
        id: colorPaletteDialog

        property int targetCellId: -1
        property string activeColor: "#00E5FF"

        title: "🎨 Selección de Color de Tarjeta / Separador"
        dialogWidth: 420
        dialogHeight: 240
        standardButtons: Dialog.Close

        function openForCell(cellId, currentColorHex) {
            targetCellId = cellId;
            activeColor = currentColorHex || "#00E5FF";
            open();
        }

        contentItem: ColumnLayout {
            spacing: 15

            Label {
                text: "Haz click derecho en cualquier elemento para cambiar su color destacado:"
                color: Theme.subtextColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: [
                        { name: "Cyan", hex: "#00E5FF" },
                        { name: "Verde", hex: "#10B981" },
                        { name: "Rojo", hex: "#EF4444" },
                        { name: "Púrpura", hex: "#8B5CF6" },
                        { name: "Gris Dark", hex: "#1E293B" },
                        { name: "Por Defecto", hex: "" }
                    ]

                    delegate: Rectangle {
                        width: 50; height: 50; radius: 8
                        color: modelData.hex !== "" ? Qt.color(modelData.hex) : Theme.cardBg
                        border.color: (colorPaletteDialog.activeColor === modelData.hex) ? "#FFFFFF" : Theme.borderColor
                        border.width: (colorPaletteDialog.activeColor === modelData.hex) ? 3 : 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.hex === "" ? "✖" : "✓"
                            font.bold: true
                            font.pixelSize: 16
                            color: "#FFFFFF"
                            visible: colorPaletteDialog.activeColor === modelData.hex || modelData.hex === ""
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (colorPaletteDialog.targetCellId > 0) {
                                    AppController.cellModel.updateCellColor(colorPaletteDialog.targetCellId, modelData.hex);
                                }
                                colorPaletteDialog.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
