import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

AppDialog {
    id: root

    title: "Acerca del Sistema de Liquidación de Sueldos"
    dialogWidth: 560
    dialogHeight: 520
    standardButtons: Dialog.Close

    signal checkUpdatesRequested()

    contentItem: ColumnLayout {
        spacing: 14

        // ── Header / Banner ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                width: 56
                height: 56
                radius: 12
                color: Theme.accentColor

                Label {
                    anchors.centerIn: parent
                    text: "📊"
                    font.pixelSize: 28
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: "Sistema de Liquidación de Sueldos"
                    font.bold: true
                    font.pixelSize: 18
                    color: Theme.textColor
                }

                Label {
                    text: "Versión " + AppController.updateService.currentVersion + " (64-bit)"
                    font.pixelSize: 12
                    color: Theme.subtextColor
                }

                Label {
                    text: "Licenciado bajo GNU General Public License v3 (GPLv3)"
                    font.pixelSize: 11
                    color: Theme.accentColor
                    font.bold: true
                }
            }

            StyledButton {
                variant: "secondary"
                text: "🔍 Actualizaciones"
                onClicked: {
                    root.close()
                    root.checkUpdatesRequested()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderColor }

        // ── Tabs for Details & Credits ──────────────────────────────
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            currentIndex: 0

            TabButton { text: "Licencia GPLv3" }
            TabButton { text: "Créditos & Componentes" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // ── Tab 1: Licencia ─────────────────────────────────────
            ScrollView {
                clip: true

                ColumnLayout {
                    width: root.dialogWidth - 48
                    spacing: 10

                    Label {
                        text: "Licencia de Software Libre (GPLv3)"
                        font.bold: true
                        font.pixelSize: 14
                        color: Theme.textColor
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.subtextColor
                        font.pixelSize: 12
                        text: "Este programa es Software Libre: usted puede redistribuirlo y/o modificarlo bajo los términos de la Licencia Pública General GNU tal como fue publicada por la Free Software Foundation, ya sea la versión 3 de la Licencia o (a su elección) cualquier versión posterior.\n\nEste programa se distribuye con la esperanza de que sea útil, pero SIN NINGUNA GARANTÍA; ni siquiera la garantía implícita de MERCANTILIDAD o ADECUACIÓN PARA UN PROPÓSITO PARTICULAR. Consulte la Licencia Pública General GNU para obtener más detalles."
                    }

                    Label {
                        text: "Derechos de Autor (Copyright)"
                        font.bold: true
                        font.pixelSize: 13
                        color: Theme.textColor
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.subtextColor
                        font.pixelSize: 12
                        text: "Copyright © 2026 Todos los derechos reservados.\nLicencia oficial disponible en el archivo LICENSE del proyecto o en https://www.gnu.org/licenses/gpl-3.0.html"
                    }
                }
            }

            // ── Tab 2: Créditos & Submódulos ────────────────────────
            ScrollView {
                clip: true

                ColumnLayout {
                    width: root.dialogWidth - 48
                    spacing: 12

                    Label {
                        text: "Componentes y Librerías de Terceros"
                        font.bold: true
                        font.pixelSize: 14
                        color: Theme.textColor
                    }

                    // Qt Framework
                    Rectangle {
                        Layout.fillWidth: true
                        height: 54
                        color: Theme.cardBg
                        border.color: Theme.borderColor
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Label { text: "💚"; font.pixelSize: 20 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label { text: "Qt 6 Framework"; font.bold: true; font.pixelSize: 13; color: Theme.textColor }
                                Label { text: "Copyright © The Qt Company Ltd. (LGPLv3 / Commercial)"; font.pixelSize: 11; color: Theme.subtextColor }
                            }
                        }
                    }

                    // QXlsx
                    Rectangle {
                        Layout.fillWidth: true
                        height: 54
                        color: Theme.cardBg
                        border.color: Theme.borderColor
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Label { text: "📗"; font.pixelSize: 20 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label { text: "QXlsx Library (Excel Reader/Writer)"; font.bold: true; font.pixelSize: 13; color: Theme.textColor }
                                Label { text: "Copyright © QXlsx Project (MIT License)"; font.pixelSize: 11; color: Theme.subtextColor }
                            }
                        }
                    }

                    // SQLite
                    Rectangle {
                        Layout.fillWidth: true
                        height: 54
                        color: Theme.cardBg
                        border.color: Theme.borderColor
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Label { text: "🗄️"; font.pixelSize: 20 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label { text: "SQLite Database Engine"; font.bold: true; font.pixelSize: 13; color: Theme.textColor }
                                Label { text: "Copyright © D. Richard Hipp (Public Domain)"; font.pixelSize: 11; color: Theme.subtextColor }
                            }
                        }
                    }

                    // Open Fonts
                    Rectangle {
                        Layout.fillWidth: true
                        height: 54
                        color: Theme.cardBg
                        border.color: Theme.borderColor
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Label { text: "🔤"; font.pixelSize: 20 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label { text: "Google Fonts (Inter / Hack / Noto Sans)"; font.bold: true; font.pixelSize: 13; color: Theme.textColor }
                                Label { text: "SIL Open Font License 1.1 / Apache License 2.0"; font.pixelSize: 11; color: Theme.subtextColor }
                            }
                        }
                    }
                }
            }
        }
    }
}
