import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "views"
import "dialogs"
import "components"

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    visible: true
    title: qsTr("Sistema de Liquidación de Sueldos y Costo Laboral")

    background: Rectangle {
        color: Theme.bgColor
    }

    // All tabs definition — controlled mapping for role visibility
    readonly property var tabDefinitions: [
        { label: "Empleados",         adminOnly: false, viewIndex: 0 },
        { label: "Empresa",           adminOnly: true,  viewIndex: 1 },
        { label: "Categorías",        adminOnly: true,  viewIndex: 2 },
        { label: "Esquemas",          adminOnly: true,  viewIndex: 3 },
        { label: "Campos Globales",   adminOnly: false, viewIndex: 4 },
        { label: "Funciones JS",      adminOnly: true,  viewIndex: 5 },
        { label: "Estructura Recibo", adminOnly: true,  viewIndex: 6 },
        { label: "Vista Previa",      adminOnly: false, viewIndex: 7 },
        { label: "Historial",         adminOnly: false, viewIndex: 8 }
    ]

    // Filtered list of visible tab indices
    property var visibleTabIndices: {
        var result = []
        for (var i = 0; i < tabDefinitions.length; i++) {
            if (!tabDefinitions[i].adminOnly || AppController.currentRole === "admin") {
                result.push(i)
            }
        }
        return result
    }

    property int activeViewIndex: 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header Bar ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 56
            color: Theme.panelBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 16

                // Global Period Selector
                Rectangle {
                    implicitHeight: 38
                    implicitWidth: periodRow.implicitWidth + 16
                    radius: 8
                    color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
                    border.color: Theme.borderColor
                    border.width: 1

                    RowLayout {
                        id: periodRow
                        anchors.centerIn: parent
                        spacing: 8

                        Label {
                            text: "📅 Período:"
                            font.bold: true
                            font.pixelSize: 12
                            color: Theme.subtextColor
                        }

                        StyledComboBox {
                            id: monthCombo
                            implicitWidth: 125
                            implicitHeight: 30
                            model: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                                    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
                            currentIndex: AppController.selectedMonth - 1
                            onActivated: AppController.selectedMonth = currentIndex + 1
                        }

                        // Year Selector with buttons and direct text edit
                        RowLayout {
                            spacing: 2
                            StyledButton {
                                text: "◀"
                                implicitWidth: 26
                                implicitHeight: 30
                                variant: "secondary"
                                onClicked: AppController.selectedYear -= 1
                            }
                            Rectangle {
                                implicitWidth: 54
                                implicitHeight: 30
                                color: Theme.inputBg
                                border.color: Theme.borderColor
                                border.width: 1
                                radius: 4

                                TextInput {
                                    id: yearInput
                                    anchors.centerIn: parent
                                    text: AppController.selectedYear.toString()
                                    color: Theme.textColor
                                    font.bold: true
                                    font.pixelSize: 13
                                    validator: IntValidator { bottom: 2000; top: 2099 }
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    onEditingFinished: {
                                        var y = parseInt(text)
                                        if (y >= 2000 && y <= 2099) {
                                            AppController.selectedYear = y
                                        } else {
                                            text = AppController.selectedYear.toString()
                                        }
                                    }
                                }
                            }
                            StyledButton {
                                text: "▶"
                                implicitWidth: 26
                                implicitHeight: 30
                                variant: "secondary"
                                onClicked: AppController.selectedYear += 1
                            }
                        }

                        // Closed / Open Period Badges (Granular chips)
                        RowLayout {
                            spacing: 4
                            visible: !AppController.isCurrentPeriodClosed
                            Repeater {
                                model: AppController.activeQuincenas
                                delegate: BadgePill {
                                    property bool closed: {
                                        var _ = AppController.periodCierres;
                                        return AppController.isCierreClosed(modelData, "jornal");
                                    }
                                    text: modelData + (closed ? " 🔒" : " 🟢")
                                    variant: closed ? "warning" : "secondary"
                                }
                            }
                            BadgePill {
                                property bool mClosed: {
                                    var _ = AppController.periodCierres;
                                    return AppController.isMClosed;
                                }
                                text: "M" + (mClosed ? " 🔒" : " 🟢")
                                variant: mClosed ? "warning" : "secondary"
                            }
                        }

                        BadgePill {
                            text: "🔒 Mes Completo Cerrado"
                            variant: "warning"
                            visible: AppController.isCurrentPeriodClosed
                        }
                    }
                }

                // Manage Closures Button
                StyledButton {
                    text: AppController.isCurrentPeriodClosed ? "🔒 Ver / Reabrir Cierres" : "📋 Gestionar Cierres"
                    variant: AppController.isCurrentPeriodClosed ? "secondary" : "primary"
                    onClicked: closeMonthDialog.open()
                }

                Item { Layout.fillWidth: true }

                // Update notification banner button
                StyledButton {
                    visible: AppController.updateService.isUpdateAvailable
                    variant: "primary"
                    text: "✨ Actualización v" + AppController.updateService.latestVersion + " disponible"
                    onClicked: updateDialog.open()
                }

                // Settings Gear Button
                StyledButton {
                    variant: "secondary"
                    text: "⚙️ Configuración"
                    onClicked: settingsDialog.open()
                }
            }

            // Header Bottom Separator
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.borderColor
            }
        }

        // ── Navigation Bar (Tab Buttons) ────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 46
            color: Theme.headerBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 4

                Repeater {
                    model: visibleTabIndices

                    delegate: StyledTabButton {
                        property var def: tabDefinitions[modelData]
                        text: def.label
                        checked: activeViewIndex === def.viewIndex
                        onClicked: activeViewIndex = def.viewIndex
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Tab Bar Bottom Line
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.borderColor
            }
        }

        // ── Content Area (StackLayout for Views) ───────────────
        StackLayout {
            id: viewStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: activeViewIndex

            EmployeesView         { Layout.fillWidth: true; Layout.fillHeight: true }
            CompanyView           { Layout.fillWidth: true; Layout.fillHeight: true }
            CategoriesView        { Layout.fillWidth: true; Layout.fillHeight: true }
            SchemasView           { Layout.fillWidth: true; Layout.fillHeight: true }
            GlobalVarsView        { Layout.fillWidth: true; Layout.fillHeight: true }
            CustomFunctionsView   { Layout.fillWidth: true; Layout.fillHeight: true }
            ReceiptStructureView  { Layout.fillWidth: true; Layout.fillHeight: true }
            PreviewView           { Layout.fillWidth: true; Layout.fillHeight: true }
            ReceiptHistoryView    { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }

    // ── Dialogs ─────────────────────────────────────────────────
    SettingsDialog {
        id: settingsDialog
        onAboutRequested: aboutDialog.open()
        onCheckUpdatesRequested: {
            updateDialog.open()
            AppController.updateService.checkForUpdates(false)
        }
    }

    AboutDialog {
        id: aboutDialog
        onCheckUpdatesRequested: {
            updateDialog.open()
            AppController.updateService.checkForUpdates(false)
        }
    }

    UpdateDialog {
        id: updateDialog
    }

    CalculationErrorDialog {
        id: calcErrorDialog
    }

    CloseMonthDialog {
        id: closeMonthDialog
    }

    Connections {
        target: AppController
        function onCalculationErrorOccurred(errors) {
            calcErrorDialog.showErrors(errors)
        }
    }

    Connections {
        target: AppController.updateService
        function onUpdateAvailablePrompt() {
            updateDialog.open()
        }
    }
}
