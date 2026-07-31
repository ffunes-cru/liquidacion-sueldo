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
        { label: "Estructura Recibo", adminOnly: true,  viewIndex: 5 },
        { label: "Vista Previa",      adminOnly: false, viewIndex: 6 },
        { label: "Historial",         adminOnly: false, viewIndex: 7 }
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
            implicitHeight: 60
            color: Theme.panelBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 15

                Label {
                    text: "Liquidación de Sueldos"
                    font.pixelSize: 20
                    font.bold: true
                    color: Theme.accentColor
                }

                Label {
                    text: "(C++ / QML)"
                    font.pixelSize: 13
                    color: Theme.subtextColor
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "Modo:"
                    font.pixelSize: 14
                    color: Theme.textColor
                }

                ComboBox {
                    id: roleCombo
                    model: ["Administrador", "Usuario Operativo"]
                    currentIndex: AppController.currentRole === "admin" ? 0 : 1
                    onActivated: {
                        AppController.currentRole = (currentIndex === 0) ? "admin" : "user"
                        mainTabBar.currentIndex = 0
                        window.activeViewIndex = window.visibleTabIndices[0]
                    }
                }

                Button {
                    text: "⚙️ Configuración"
                    onClicked: settingsDialog.open()
                }
            }
        }

        // ── Navigation TabBar ───────────────────────────────────
        TabBar {
            id: mainTabBar
            Layout.fillWidth: true
            background: Rectangle { color: Theme.panelBg }

            Repeater {
                model: window.visibleTabIndices

                TabButton {
                    property int defIndex: modelData
                    contentItem: Text {
                        text: window.tabDefinitions[defIndex].label
                        color: parent.checked ? Theme.accentColor : Theme.textColor
                        font.bold: parent.checked
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex < window.visibleTabIndices.length) {
                    var defIdx = window.visibleTabIndices[currentIndex]
                    window.activeViewIndex = window.tabDefinitions[defIdx].viewIndex
                }
            }
        }

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
            ReceiptStructureView { Layout.fillWidth: true; Layout.fillHeight: true }
            PreviewView { Layout.fillWidth: true; Layout.fillHeight: true }
            ReceiptHistoryView { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }

    // ── Dialogs ─────────────────────────────────────────────────
    SettingsDialog {
        id: settingsDialog
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
