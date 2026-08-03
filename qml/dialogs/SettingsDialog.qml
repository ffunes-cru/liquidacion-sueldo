import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

AppDialog {
    id: root

    title: "Configuración General del Sistema"
    dialogWidth: 520
    dialogHeight: -1
    standardButtons: Dialog.Close

    property string statusMsg: ""
    signal aboutRequested()

    contentItem: ColumnLayout {
        spacing: 12

        // ── Apariencia ──────────────────────────────────────────
        Label {
            text: "Apariencia"
            font.bold: true
            font.pixelSize: 15
            color: Theme.accentColor
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "Modo Oscuro (Dark Theme):"
                color: Theme.textColor
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
                color: Theme.textColor
                Layout.fillWidth: true
            }
            ComboBox {
                model: ["Administrador", "Usuario Operativo"]
                currentIndex: AppController.currentRole === "admin" ? 0 : 1
                onActivated: AppController.currentRole = (currentIndex === 0) ? "admin" : "user"
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderColor }

        // ── Datos ───────────────────────────────────────────────
        Label {
            text: "Gestión de Datos"
            font.bold: true
            font.pixelSize: 15
            color: Theme.accentColor
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

        Button {
            Layout.fillWidth: true
            text: "💾 Crear Copia de Seguridad de BD (Backup)"
            onClicked: {
                var bp = AppController.createBackup()
                root.statusMsg = bp !== "" ? "Backup creado: " + bp : "Error al crear backup"
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderColor }

        // ── Acerca de & Licencias ──────────────────────────────
        Label {
            text: "Licencias y Créditos"
            font.bold: true
            font.pixelSize: 15
            color: Theme.accentColor
        }

        Button {
            Layout.fillWidth: true
            text: "ℹ️ Acerca del Sistema y Licencia GPLv3..."
            onClicked: {
                root.close()
                root.aboutRequested()
            }
        }

        // ── Status ──────────────────────────────────────────────
        Label {
            text: root.statusMsg
            visible: root.statusMsg !== ""
            color: Theme.accentColor
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
