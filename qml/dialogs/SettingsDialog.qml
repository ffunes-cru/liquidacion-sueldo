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
            StyledSwitch {
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
            StyledComboBox {
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

        StyledButton {
            Layout.fillWidth: true
            variant: "secondary"
            text: "📤 Exportar Datos a Excel (.xlsx)"
            onClicked: {
                var savePath = AppController.selectSaveFile("Exportar Datos a Excel", "liquidacion_datos.xlsx", "Archivos Excel (*.xlsx)")
                if (savePath !== "") {
                    var path = AppController.exportDataXlsx(savePath)
                    root.statusMsg = path !== "" ? "Exportado exitosamente a: " + path : "Error al exportar a Excel."
                }
            }
        }

        StyledButton {
            Layout.fillWidth: true
            variant: "secondary"
            text: "📥 Importar Datos desde Excel (.xlsx)"
            onClicked: {
                var openPath = AppController.selectOpenFile("Importar Datos desde Excel", "", "Archivos Excel (*.xlsx)")
                if (openPath !== "") {
                    var ok = AppController.importDataXlsx(openPath)
                    root.statusMsg = ok ? "Importación exitosa. Los datos han sido cargados." : "Error al importar desde Excel."
                }
            }
        }

        StyledButton {
            Layout.fillWidth: true
            variant: "secondary"
            text: "📤 Exportar Datos a CSV"
            onClicked: {
                var folder = AppController.selectFolder("Seleccionar Carpeta para Exportar CSV", "")
                if (folder !== "") {
                    var path = AppController.exportDataCsv(folder)
                    root.statusMsg = path !== "" ? "Exportado exitosamente en la carpeta: " + path : "Error al exportar CSV."
                }
            }
        }

        StyledButton {
            Layout.fillWidth: true
            variant: "secondary"
            text: "💾 Crear Copia de Seguridad de BD (Backup)"
            onClicked: {
                var savePath = AppController.selectSaveFile("Guardar Copia de Seguridad (Backup)", "backup_liquidacion.db", "Base de Datos SQLite (*.db *.sqlite)")
                if (savePath !== "") {
                    var bp = AppController.createBackup(savePath)
                    root.statusMsg = bp !== "" ? "Backup creado exitosamente en: " + bp : "Error al crear backup."
                }
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

        StyledButton {
            Layout.fillWidth: true
            variant: "primary"
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
