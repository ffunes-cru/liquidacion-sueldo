import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

AppDialog {
    id: root

    title: "Actualización del Sistema"
    dialogWidth: 620
    dialogHeight: -1
    standardButtons: Dialog.NoButton

    readonly property var updater: AppController.updateService

    contentItem: ColumnLayout {
        spacing: 16

        // ── Banner Header ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + 20
            radius: 8
            color: Theme.isDark ? Qt.rgba(59/255, 130/255, 246/255, 0.12) : Qt.rgba(59/255, 130/255, 246/255, 0.08)
            border.color: Theme.accentColor
            border.width: 1

            RowLayout {
                id: headerRow
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                Rectangle {
                    width: 48
                    height: 48
                    radius: 10
                    color: Theme.accentColor

                    Label {
                        anchors.centerIn: parent
                        text: "🚀"
                        font.pixelSize: 24
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Label {
                        text: root.updater.isReadyToInstall
                              ? "¡Actualización lista para instalar!"
                              : (root.updater.isUpdateAvailable
                                 ? "¡Nueva versión disponible: v" + root.updater.latestVersion + "!"
                                 : "Búsqueda de Actualizaciones")
                        font.pixelSize: 16
                        font.bold: true
                        color: Theme.textColor
                    }

                    Label {
                        text: root.updater.isReadyToInstall
                              ? "Los archivos fueron descargados. Puede reiniciar ahora para aplicar los cambios de forma segura."
                              : (root.updater.releaseName !== "" ? root.updater.releaseName : "Mejoras de rendimiento, estabilidad y nuevas funciones.")
                        font.pixelSize: 12
                        color: Theme.subtextColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // ── Version Comparison Card ─────────────────────────────────
        SectionPanel {
            title: "Detalles de la Versión"
            padding: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                ColumnLayout {
                    spacing: 2
                    Label { text: "Versión Actual:"; font.pixelSize: 11; color: Theme.subtextColor }
                    Label {
                        text: "v" + root.updater.currentVersion
                        font.bold: true
                        font.pixelSize: 14
                        color: Theme.textColor
                    }
                }

                Label {
                    text: "➔"
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.accentColor
                }

                ColumnLayout {
                    spacing: 2
                    Label { text: "Nueva Versión:"; font.pixelSize: 11; color: Theme.subtextColor }
                    RowLayout {
                        spacing: 6
                        Label {
                            text: "v" + (root.updater.latestVersion !== "" ? root.updater.latestVersion : "---")
                            font.bold: true
                            font.pixelSize: 14
                            color: Theme.successColor
                        }
                        BadgePill {
                            text: "Recomendada"
                            badgeColor: Theme.successColor
                            fontSize: 10
                            visible: root.updater.isUpdateAvailable
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    spacing: 2
                    visible: root.updater.releaseDate !== ""
                    Label { text: "Fecha de Lanzamiento:"; font.pixelSize: 11; color: Theme.subtextColor }
                    Label {
                        text: root.updater.releaseDate
                        font.pixelSize: 12
                        color: Theme.textColor
                    }
                }
            }
        }

        // ── Changelog / Release Notes ───────────────────────────────
        Label {
            text: "Novedades y Cambios:"
            font.bold: true
            font.pixelSize: 13
            color: Theme.textColor
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.min(160, txtNotes.implicitHeight + 24)
            color: Theme.panelBg
            radius: 6
            border.color: Theme.borderColor
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true

                TextEdit {
                    id: txtNotes
                    width: parent.width
                    text: root.updater.releaseNotes !== ""
                          ? root.updater.releaseNotes
                          : "• Mejoras generales del motor de liquidación y exportación PDF.\n• Corrección de estabilidad y cálculos de cierres."
                    color: Theme.textColor
                    font.pixelSize: 12
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.WordWrap
                    textFormat: TextEdit.PlainText
                }
            }
        }

        // ── Download Progress Section ───────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.updater.isDownloading || root.updater.isReadyToInstall

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: root.updater.isReadyToInstall
                          ? "✓ Descarga completa"
                          : "Descargando actualización..."
                    font.bold: true
                    font.pixelSize: 12
                    color: root.updater.isReadyToInstall ? Theme.successColor : Theme.accentColor
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: (root.updater.downloadProgress * 100).toFixed(0) + "% " +
                          (root.updater.downloadSpeed !== "" ? "(" + root.updater.downloadSpeed + ")" : "")
                    font.pixelSize: 12
                    color: Theme.subtextColor
                    visible: root.updater.isDownloading
                }
            }

            ProgressBar {
                Layout.fillWidth: true
                implicitHeight: 8
                value: root.updater.downloadProgress
                from: 0.0
                to: 1.0

                background: Rectangle {
                    implicitHeight: 8
                    radius: 4
                    color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.08)
                }

                contentItem: Item {
                    implicitHeight: 8
                    Rectangle {
                        width: parent.width * parent.parent.visualPosition
                        height: parent.height
                        radius: 4
                        color: root.updater.isReadyToInstall ? Theme.successColor : Theme.accentColor
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }
            }
        }

        // ── Error / Status Banner ───────────────────────────────────
        StatusBanner {
            message: root.updater.errorMessage !== "" ? root.updater.errorMessage : root.updater.statusMessage
            isError: root.updater.errorMessage !== ""
            visible: message !== "" && !root.updater.isDownloading
        }

        // ── Action Buttons ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item { Layout.fillWidth: true }

            // State 1: Update Available -> Download
            StyledButton {
                text: "⏳ Recordar Más Tarde"
                variant: "secondary"
                visible: !root.updater.isDownloading && !root.updater.isReadyToInstall
                onClicked: {
                    root.updater.dismissUpdate()
                    root.close()
                }
            }

            StyledButton {
                text: "📥 Descargar Actualización"
                variant: "primary"
                visible: !root.updater.isDownloading && !root.updater.isReadyToInstall && root.updater.isUpdateAvailable
                onClicked: root.updater.startDownload()
            }

            // State 2: Downloading -> Cancel
            StyledButton {
                text: "❌ Cancelar Descarga"
                variant: "danger"
                visible: root.updater.isDownloading
                onClicked: root.updater.cancelDownload()
            }

            // State 3: Ready To Install -> Restart & Update
            StyledButton {
                text: "Cerrar"
                variant: "secondary"
                visible: root.updater.isReadyToInstall
                onClicked: root.close()
            }

            StyledButton {
                text: "🚀 Actualizar y Reiniciar Ahora"
                variant: "primary"
                visible: root.updater.isReadyToInstall
                onClicked: {
                    var ok = root.updater.installAndRestart()
                    if (!ok) {
                        // Error message handled by updater
                    }
                }
            }
        }
    }
}
