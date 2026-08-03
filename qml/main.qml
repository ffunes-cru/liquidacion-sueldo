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

                // App Brand Title
                ColumnLayout {
                    spacing: 2
                    Label {
                        text: "SISTEMA DE LIQUIDACIÓN"
                        font.pixelSize: 16
                        font.bold: true
                        color: Theme.textColor
                    }
                    Label {
                        text: "Sueldos & Costo Laboral"
                        font.pixelSize: 11
                        color: Theme.subtextColor
                    }
                }

                // Role Selector Pill
                RoleSelector {
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

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
    }

    AboutDialog {
        id: aboutDialog
    }

    CalculationErrorDialog {
        id: calcErrorDialog
    }

    Connections {
        target: AppController
        function onCalculationErrorOccurred(errors) {
            calcErrorDialog.showErrors(errors)
        }
    }
}
