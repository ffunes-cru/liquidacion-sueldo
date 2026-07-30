import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property string selectedSchemaCode: ""
    property var schemaFieldsList: []

    function loadSchema(code, name, tipo) {
        selectedSchemaCode = code
        txtCode.text = code
        txtName.text = name
        cbTipoLiq.currentIndex = (tipo === "jornal") ? 1 : 0
        refreshSchemaFields()
    }

    function clearForm() {
        selectedSchemaCode = ""
        txtCode.text = ""
        txtName.text = ""
        cbTipoLiq.currentIndex = 0
        schemaFieldsList = []
    }

    function refreshSchemaFields() {
        if (selectedSchemaCode !== "") {
            schemaFieldsList = AppController.listSchemaFields(selectedSchemaCode)
        } else {
            schemaFieldsList = []
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ═══════════════════════════════════════════════════════════════
        // LEFT PANE: Schemas List
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
                        text: "Esquemas de Cálculo"
                        font.pixelSize: 16
                        font.bold: true
                        color: window.textColor
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: AppController.schemaModel.count + " esq."
                        font.pixelSize: 12
                        color: window.subtextColor
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: schemaListView
                        model: AppController.schemaModel
                        spacing: 6

                        delegate: Rectangle {
                            width: schemaListView.width
                            height: 52
                            radius: 6
                            color: root.selectedSchemaCode === model.code ? (window.isDark ? "#3b3b58" : "#e4e4e9") :
                                   (mouseArea.containsMouse ? (window.isDark ? "#303045" : "#f0f0f5") : window.cardBg)
                            border.color: root.selectedSchemaCode === model.code ? window.accentColor : window.borderColor
                            border.width: 1

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.loadSchema(model.code, model.name, model.tipoLiquidacion)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Label {
                                        text: model.code
                                        font.bold: true
                                        font.pixelSize: 14
                                        color: window.textColor
                                    }
                                    Label {
                                        text: model.name
                                        font.pixelSize: 12
                                        color: window.subtextColor
                                    }
                                }

                                Rectangle {
                                    width: 70
                                    height: 24
                                    radius: 12
                                    color: model.tipoLiquidacion === "jornal" ? "#fab387" : "#89b4fa"

                                    Label {
                                        anchors.centerIn: parent
                                        text: model.tipoLiquidacion === "jornal" ? "Jornal" : "Mensual"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#11111b"
                                    }
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
                        text: "Nuevo Esquema"
                        onClicked: {
                            root.clearForm()
                            txtCode.forceActiveFocus()
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: "Eliminar"
                        enabled: root.selectedSchemaCode !== "" && root.selectedSchemaCode !== "MENSUAL"
                        onClicked: {
                            if (root.selectedSchemaCode !== "") {
                                AppController.schemaModel.removeSchema(root.selectedSchemaCode)
                                root.clearForm()
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // RIGHT PANE: Schema Config & Input Fields Model
        // ═══════════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: window.panelBg
            radius: 8
            border.color: window.borderColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                Label {
                    text: root.selectedSchemaCode !== "" ? "Configurar Esquema: " + root.selectedSchemaCode : "Nuevo Esquema de Cálculo"
                    font.pixelSize: 18
                    font.bold: true
                    color: window.textColor
                }

                // ── Schema Basic Fields ───────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 110
                    color: window.cardBg
                    radius: 6
                    border.color: window.borderColor

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        columns: 4
                        rowSpacing: 10
                        columnSpacing: 15

                        Label { text: "Código:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtCode
                            placeholderText: "Ej: COMERCIO"
                            Layout.fillWidth: true
                            color: window.textColor
                        }

                        Label { text: "Nombre Descriptivo:"; color: window.textColor; font.pixelSize: 13 }
                        TextField {
                            id: txtName
                            placeholderText: "Ej: Comercio CCT 130/75"
                            Layout.fillWidth: true
                            color: window.textColor
                        }

                        Label { text: "Tipo Liquidación:"; color: window.textColor; font.pixelSize: 13 }
                        ComboBox {
                            id: cbTipoLiq
                            Layout.fillWidth: true
                            model: ["Mensual", "Jornalero"]
                        }

                        Item { Layout.columnSpan: 2 }
                    }
                }

                // ── Input Fields Model (schema_fields) ────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Modelo de Variables de Entrada (Inmutable para los Empleados):"
                        font.pixelSize: 14
                        font.bold: true
                        color: window.accentColor
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: "Agregar Variable al Modelo"
                        enabled: root.selectedSchemaCode !== ""
                        onClicked: addFieldDialog.open()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: window.cardBg
                    radius: 6
                    border.color: window.borderColor

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true

                        ListView {
                            id: fieldsListView
                            model: root.schemaFieldsList
                            spacing: 6

                            delegate: Rectangle {
                                width: fieldsListView.width - 20
                                height: 44
                                color: window.panelBg
                                radius: 4
                                border.color: window.borderColor

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 12

                                    Label {
                                        text: modelData.field_code
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: window.accentColor
                                        Layout.preferredWidth: 140
                                    }

                                    Label {
                                        text: modelData.field_label
                                        font.pixelSize: 13
                                        color: window.textColor
                                        Layout.fillWidth: true
                                    }

                                    Label {
                                        text: modelData.field_type
                                        font.pixelSize: 12
                                        color: window.subtextColor
                                        Layout.preferredWidth: 80
                                    }

                                    Label {
                                        text: "Default: " + modelData.default_value
                                        font.pixelSize: 12
                                        color: window.subtextColor
                                        Layout.preferredWidth: 100
                                    }

                                    Button {
                                        text: "Quitar"
                                        flat: true
                                        onClicked: {
                                            AppController.removeSchemaField(modelData.id)
                                            root.refreshSchemaFields()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Bottom Save Button Bar ──────────────────────────────
                RowLayout {
                    Layout.fillWidth: true

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Guardar Esquema"
                        highlighted: true
                        onClicked: {
                            if (txtCode.text.trim() !== "" && txtName.text.trim() !== "") {
                                AppController.schemaModel.saveSchema(
                                    root.selectedSchemaCode,
                                    txtCode.text.trim().toUpperCase(),
                                    txtName.text.trim(),
                                    cbTipoLiq.currentIndex === 1 ? "jornal" : "mensual"
                                )
                                root.clearForm()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Dialog to add field to schema_fields ──────────────────────────
    Dialog {
        id: addFieldDialog
        title: "Agregar Variable al Modelo del Esquema"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        width: 400

        ColumnLayout {
            spacing: 12
            anchors.fill: parent

            Label { text: "Código Variable (ej: horas_extras_50):"; color: window.textColor }
            TextField { id: dfCode; Layout.fillWidth: true }

            Label { text: "Etiqueta (ej: Horas Extras 50%):"; color: window.textColor }
            TextField { id: dfLabel; Layout.fillWidth: true }

            Label { text: "Tipo de Dato:"; color: window.textColor }
            ComboBox {
                id: dfType
                Layout.fillWidth: true
                model: ["number", "bool", "string"]
            }

            Label { text: "Valor por Defecto:"; color: window.textColor }
            TextField { id: dfDefault; text: "0"; Layout.fillWidth: true }
        }

        onAccepted: {
            if (dfCode.text.trim() !== "" && dfLabel.text.trim() !== "") {
                AppController.addSchemaField(
                    root.selectedSchemaCode,
                    dfCode.text.trim().toLowerCase(),
                    dfLabel.text.trim(),
                    dfType.currentText,
                    dfDefault.text.trim(),
                    10
                )
                root.refreshSchemaFields()
                dfCode.text = ""
                dfLabel.text = ""
            }
        }
    }
}
