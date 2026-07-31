import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "views"
import "dialogs"

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    visible: true
    title: qsTr("Sistema de Liquidación de Sueldos y Costo Laboral")

    // Sleek Dark Theme Palette (Default & Enforced)
    readonly property bool isDark: true
    readonly property color bgColor: "#1e1e2e"
    readonly property color panelBg: "#252538"
    readonly property color cardBg: "#2b2b40"
    readonly property color inputBg: "#1e1e2e"
    readonly property color accentColor: "#74c7ec"
    readonly property color textColor: "#cdd6f4"
    readonly property color subtextColor: "#a6adc8"
    readonly property color dangerColor: "#f38ba8"
    readonly property color borderColor: "#383852"

    background: Rectangle {
        color: window.bgColor
    }

    // All tabs definition — controlled mapping for role visibility
    // Each entry: { label, adminOnly, viewIndex }
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

    // Map from TabBar position to StackLayout index
    property int activeViewIndex: 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header Bar ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 60
            color: window.panelBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 15

                Label {
                    text: "Liquidación de Sueldos"
                    font.pixelSize: 20
                    font.bold: true
                    color: window.accentColor
                }

                Label {
                    text: "(C++ / QML)"
                    font.pixelSize: 13
                    color: window.subtextColor
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "Modo:"
                    font.pixelSize: 14
                    color: window.textColor
                }

                ComboBox {
                    id: roleCombo
                    model: ["Administrador", "Usuario Operativo"]
                    currentIndex: AppController.currentRole === "admin" ? 0 : 1
                    onActivated: {
                        AppController.currentRole = (currentIndex === 0) ? "admin" : "user"
                        // Reset to first tab on role change
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
            background: Rectangle { color: window.panelBg }

            Repeater {
                model: window.visibleTabIndices

                TabButton {
                    property int defIndex: modelData
                    contentItem: Text {
                        text: window.tabDefinitions[defIndex].label
                        color: parent.checked ? window.accentColor : window.textColor
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

            // 0: Empleados
            EmployeesView { Layout.fillWidth: true; Layout.fillHeight: true }

            // 1: Empresa
            CompanyView { Layout.fillWidth: true; Layout.fillHeight: true }

            // 2: Categorías
            CategoriesView { Layout.fillWidth: true; Layout.fillHeight: true }

            // 3: Esquemas
            SchemasView { Layout.fillWidth: true; Layout.fillHeight: true }

            // 4: Campos Globales
            GlobalVarsView { Layout.fillWidth: true; Layout.fillHeight: true }

            // 5: Estructura Recibo
            ReceiptStructureView { Layout.fillWidth: true; Layout.fillHeight: true }

            // 6: Vista Previa
            PreviewView { Layout.fillWidth: true; Layout.fillHeight: true }

            // 7: Historial
            ReceiptHistoryView { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }

    // ── Dialogs (outside layout, anchored to window) ─────────
    SettingsDialog {
        id: settingsDialog
    }
}
