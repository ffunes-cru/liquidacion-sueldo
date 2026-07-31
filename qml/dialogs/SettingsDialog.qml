import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Dialog {
    id: root

    title: "Configuración General del Sistema"
    modal: true
    anchors.centerIn: parent
    width: 520
    height: 420
    standardButtons: Dialog.Close

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    background: Rectangle {
        color: window.panelBg
        radius: 10
        border.color: window.borderColor
        border.width: 1
    }

    enter: Transition {
        NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: 200; easing.type: Easing.OutBack }
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 180 }
    }
    exit: Transition {
        NumberAnimation { property: "scale"; from: 1.0; to: 0.85; duration: 150; easing.type: Easing.InQuad }
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150 }
    }

    property string statusMsg: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 15

        // ── Apariencia ──────────────────────────────────────────────
        Label {
            text: "Apariencia"
            font.bold: true
            font.pixelSize: 15
            color: window.accentColor
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Modo Oscuro (Dark Theme):"
                color: window.textColor
                Layout.fillWidth: true
            }
            Switch {
                checked: AppController.darkMode
                onToggled: AppController.darkMode = checked
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Modo de Vista por Defecto:"
                color: window.textColor
                Layout.fillWidth: true
            }
            ComboBox {
                model: ["Administrador", "Usuario Operativo"]
                currentIndex: AppController.currentRole === "admin" ? 0 : 1
                onActivated: AppController.currentRole = (currentIndex === 0) ? "admin" : "user"
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: window.borderColor }

        // ── Datos ───────────────────────────────────────────────────
        Label {
            text: "Gestión de Datos"
            font.bold: true
            font.pixelSize: 15
            color: window.accentColor
        }

        Button {
            Layout.fillWidth: true
            text: "📤 Exportar Datos a Excel (.xlsx)"
            onClicked: {
                var path = AppController.exportDataXlsx("")
                root.statusMsg = path !== "" ? "Exportado a: " + path : "Error al exportar"
            }
        }

        Button {
            Layout.fillWidth: true
            text: "📥 Importar Datos desde Excel (.xlsx)"
            onClicked: {
                var ok = AppController.importDataXlsx("")
                root.statusMsg = ok ? "Importación exitosa. Reinicie la app para ver los cambios." : "Error al importar"
            }
        }

        Button {
            Layout.fillWidth: true
            text: "📤 Exportar Datos a CSV"
            onClicked: {
                var path = AppController.exportDataCsv("")
                root.statusMsg = path !== "" ? "Exportado a: " + path : "Error al exportar CSV"
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: window.borderColor }

        // ── Backup ──────────────────────────────────────────────────
        Button {
            Layout.fillWidth: true
            text: "💾 Crear Copia de Seguridad de BD (Backup)"
            onClicked: {
                var bp = AppController.createBackup()
                root.statusMsg = bp !== "" ? "Backup creado: " + bp : "Error al crear backup"
            }
        }

        // ── Status ──────────────────────────────────────────────────
        Label {
            text: root.statusMsg
            visible: root.statusMsg !== ""
            color: window.accentColor
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }
    }
}
