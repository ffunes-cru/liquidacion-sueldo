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
                spacing: 15

                Label {
                    text: "Liquidación de Sueldos"
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.accentColor
                }

                Label {
                    text: "(C++ / QML)"
                    font.pixelSize: 12
                    color: Theme.subtextColor
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "Modo:"
                    font.pixelSize: 13
                    color: Theme.subtextColor
                }

                StyledComboBox {
                    id: roleCombo
                    implicitWidth: 170
                    model: ["Administrador", "Usuario Operativo"]
                    currentIndex: AppController.currentRole === "admin" ? 0 : 1
                    onActivated: {
                        AppController.currentRole = (currentIndex === 0) ? "admin" : "user"
                        mainTabBar.currentIndex = 0
                        window.activeViewIndex = window.visibleTabIndices[0]
                    }
                }

                StyledButton {
                    variant: "secondary"
                    text: "⚙️ Configuración"
                    onClicked: settingsDialog.open()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderColor }

        // ── Navigation TabBar Area ──────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 50
            color: Theme.panelBg

            TabBar {
                id: mainTabBar
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                spacing: 6
                background: Rectangle { color: "transparent" }

                Repeater {
                    model: window.visibleTabIndices

                    StyledTabButton {
                        property int defIndex: modelData
                        text: window.tabDefinitions[defIndex].label
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < window.visibleTabIndices.length) {
                        var defIdx = window.visibleTabIndices[currentIndex]
                        window.activeViewIndex = window.tabDefinitions[defIdx].viewIndex
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderColor }

        // ── Main Content Area ───────────────────────────────────
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: window.activeViewIndex

            EmployeesView { Layout.fillWidth: true; Layout.fillHeight: true }
            CompanyView { Layout.fillWidth: true; Layout.fillHeight: true }
            CategoriesView { Layout.fillWidth: true; Layout.fillHeight: true }
            SchemasView { Layout.fillWidth: true; Layout.fillHeight: true }
            GlobalVarsView { Layout.fillWidth: true; Layout.fillHeight: true }
            CustomFunctionsView { Layout.fillWidth: true; Layout.fillHeight: true }
            ReceiptStructureView { Layout.fillWidth: true; Layout.fillHeight: true }
            PreviewView { Layout.fillWidth: true; Layout.fillHeight: true }
            ReceiptHistoryView { Layout.fillWidth: true; Layout.fillHeight: true }
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
