import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

MasterDetailView {
    id: root

    masterWidth: 380
    masterTitle: "Funciones Personalizadas"
    masterCountSuffix: "funciones"
    masterModel: AppController.customFunctionModel

    property int selectedFuncId: -1
    property var selectedFuncData: null

    Component.onCompleted: {
        if (AppController.customFunctionModel.count > 0) {
            selectFunctionAtRow(0)
        }
    }

    function selectFunctionAtRow(row) {
        if (row >= 0 && row < AppController.customFunctionModel.count) {
            selectedIndex = row
            var fn = AppController.customFunctionModel.get(row)
            selectedFuncData = fn
            selectedFuncId = fn.funcId || fn.id || -1
        }
    }

    // ── Master Delegate ─────────────────────────────────────────
    masterDelegate: Component {
        CrudDelegate {
            height: 60
            primaryText: (model.funcName || "") + "(" + (model.funcParams || "") + ")"
            secondaryText: model.funcDescription || "Sin descripción"
            badgeText: model.funcEsquema ? model.funcEsquema : "GLOBAL"
            badgeColor: Theme.accentColor
            showAdminActions: true
            showDuplicate: false
            itemId: model.funcId

            color: root.selectedIndex === index ? Theme.selectedBg : Theme.cardBg
            border.color: root.selectedIndex === index ? Theme.accentColor : Theme.borderColor

            onClicked: root.selectFunctionAtRow(index)

            onEditRequested: function(data) {
                var bodyText = data.funcBody || data.body || ""
                funcDialog.currentBodyText = bodyText
                funcDialog.openEdit({
                    funcId: model.funcId,
                    name: model.funcName,
                    params: model.funcParams,
                    body: bodyText,
                    description: model.funcDescription,
                    esquema: model.funcEsquema || ""
                })
            }
            onDeleteRequested: function(id) {
                AppController.customFunctionModel.removeFunction(id)
                if (AppController.customFunctionModel.count > 0) root.selectFunctionAtRow(0)
                else { root.selectedFuncId = -1; root.selectedFuncData = null }
            }
        }
    }

    // ── Master Footer ───────────────────────────────────────────
    masterFooter: ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Button {
            Layout.fillWidth: true
            text: "+ Nueva Función JS"
            highlighted: true
            visible: AppController.currentRole === "admin"
            onClicked: {
                funcDialog.currentBodyText = ""
                funcDialog.openNew()
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // DETAIL CONTENT (Right Panel: Function Editor & Documentation)
    // ══════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: 15

        // Function Information Card & Code Viewer
        SectionPanel {
            visible: root.selectedFuncId > 0
            title: root.selectedFuncData ? (root.selectedFuncData.funcName + "(" + (root.selectedFuncData.funcParams || "") + ")") : "Función Personalizada"
            padding: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Descripción:"
                        font.bold: true
                        color: Theme.subtextColor
                    }
                    Label {
                        text: root.selectedFuncData ? (root.selectedFuncData.funcDescription || "Sin descripción") : ""
                        color: Theme.textColor
                        Layout.fillWidth: true
                    }
                    Button {
                        text: "✏️ Editar Función"
                        visible: AppController.currentRole === "admin"
                        onClicked: {
                            if (root.selectedFuncData) {
                                var bodyText = root.selectedFuncData.funcBody || root.selectedFuncData.body || ""
                                funcDialog.currentBodyText = bodyText
                                funcDialog.openEdit({
                                    funcId: root.selectedFuncData.funcId || root.selectedFuncData.id,
                                    name: root.selectedFuncData.funcName || root.selectedFuncData.name,
                                    params: root.selectedFuncData.funcParams || root.selectedFuncData.params,
                                    body: bodyText,
                                    description: root.selectedFuncData.funcDescription || root.selectedFuncData.description,
                                    esquema: root.selectedFuncData.funcEsquema || root.selectedFuncData.esquema || ""
                                })
                            }
                        }
                    }
                }

                Label {
                    text: "Cuerpo de la Función (JavaScript / QJSEngine):"
                    font.bold: true
                    color: Theme.subtextColor
                    font.pixelSize: 12
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: Qt.rgba(0, 0, 0, 0.2)
                    border.color: Theme.borderColor
                    radius: 6

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 8
                        contentWidth: txtBodyViewer.implicitWidth
                        contentHeight: txtBodyViewer.implicitHeight
                        clip: true

                        TextArea.flickable: TextArea {
                            id: txtBodyViewer
                            readOnly: true
                            text: root.selectedFuncData ? root.selectedFuncData.funcBody : ""
                            font.family: "Monospace"
                            font.pixelSize: 13
                            color: Theme.accentColor
                            wrapMode: TextEdit.Wrap
                        }
                    }
                }
            }
        }

        // Documentation on Environment `env`
        SectionPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "📘 Entorno JS disponible (Objeto 'env')"
            padding: 16

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width - 20
                    spacing: 12

                    Label {
                        text: "En tus funciones podés acceder al objeto global <b>env</b> y sus colecciones para realizar iteraciones o cálculos avanzados:"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: Theme.textColor
                        font.pixelSize: 13
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: colHelp.implicitHeight + 20
                        color: Qt.rgba(0, 0, 0, 0.15)
                        border.color: Theme.borderColor
                        radius: 6

                        ColumnLayout {
                            id: colHelp
                            anchors.fill: parent
                            anchors.margins: 10

                            Text {
                                Layout.fillWidth: true
                                text: `<b>env.empleado</b>: { id, nombre, legajo, tipo_liquidacion, fecha_ingreso, antiguedad_anios, cuil, categoria: { nombre, valor_hora } }<br>
<b>env.quincenas</b>: Array de objetos por quincena [ { code: "Q1", bruto, horas_trabajadas, basico, ... }, { code: "Q2", ... } ]<br>
<b>env.historial</b>: Array de recibos históricos procesados [ { mes, anio, periodo, bruto, neto, ... } ]<br>
<b>env.globals</b>: Diccionario con variables globales (ej: env.globals.TOPE_JUBILATORIO)<br>
<b>env.fecha_calculo</b>, <b>env.mes</b>, <b>env.anio</b>: Datos del cálculo actual.`
                                color: Theme.textColor
                                font.pixelSize: 12
                                font.family: "Monospace"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Label {
                        text: "<b>Funciones Personalizadas Registradas en el Sistema:</b>"
                        font.pixelSize: 13
                        color: Theme.textColor
                    }

                    Repeater {
                        model: AppController.customFunctionModel

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: colFunc.implicitHeight + 16
                            color: Qt.rgba(0, 0, 0, 0.25)
                            border.color: Theme.borderColor
                            radius: 6

                            ColumnLayout {
                                id: colFunc
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                Label {
                                    text: "⚡ <b>" + (model.funcName || model.name) + "</b>(" + (model.funcParams || model.params || "") + ")"
                                    color: Theme.accentColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Label {
                                    visible: (model.funcDescription || model.description || "") !== ""
                                    text: model.funcDescription || model.description || ""
                                    color: Theme.subtextColor
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: model.funcBody || model.body || ""
                                    color: Theme.successColor
                                    font.pixelSize: 11
                                    font.family: "Monospace"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }

        // Empty state when no function is selected
        Label {
            visible: root.selectedFuncId <= 0
            text: "Seleccione una función de la lista para ver su definición y documentación."
            color: Theme.subtextColor
            font.italic: true
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: 40
        }
    }

    // ── Form Dialog for Creating / Editing Custom Function ─────
    FormDialog {
        id: funcDialog
        entityName: "Función Personalizada"
        dialogWidth: 600

        property string currentBodyText: ""

        formFields: [
            { key: "name",        label: "Nombre Función:",     placeholder: "Ej: sum_Q", type: "text" },
            { key: "params",      label: "Parámetros (coma):", placeholder: "Ej: variable_code", type: "text" },
            { key: "description", label: "Descripción:",       placeholder: "Ej: Suma una variable en todas las quincenas del mes", type: "text" }
        ]

        extraContent: ColumnLayout {
            spacing: 8
            Layout.fillWidth: true

            Label {
                text: "Cuerpo de la Función (JavaScript):"
                font.bold: true
                color: Theme.textColor
                font.pixelSize: 13
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                clip: true

                TextArea {
                    id: txtBody
                    placeholderText: "var ret = 0;\nfor (var i = 0; i < env.quincenas.length; i++) {\n    ret += env.quincenas[i][variable_code] || 0;\n}\nreturn ret;"
                    font.family: "Monospace"
                    font.pixelSize: 13
                    color: Theme.textColor
                    wrapMode: TextEdit.Wrap
                    background: Rectangle {
                        color: Theme.inputBg
                        border.color: Theme.borderColor
                        radius: 6
                    }
                }
            }
        }

        onOpened: {
            txtBody.text = funcDialog.currentBodyText
        }

        onFormAccepted: function(values) {
            var funcId = funcDialog.itemId > 0 ? funcDialog.itemId : 0
            var name = values.name ? values.name.trim() : ""
            var params = values.params ? values.params.trim() : ""
            var description = values.description ? values.description.trim() : ""
            var body = txtBody.text ? txtBody.text.trim() : ""

            // Code validation
            var err = AppController.validateVariableCode(name)
            if (err !== "") {
                statusBanner.showError(err)
                return
            }

            if (name !== "" && body !== "") {
                var resId = AppController.customFunctionModel.saveFunction(funcId, name, params, body, description, "")
                if (resId > 0) {
                    root.selectFunctionAtRow(root.selectedIndex >= 0 ? root.selectedIndex : 0)
                }
            }
        }
    }
}
