import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "views"

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
                    }
                }
            }
        }

        // ── Navigation TabBar ───────────────────────────────────
        TabBar {
            id: mainTabBar
            Layout.fillWidth: true
            background: Rectangle { color: window.panelBg }

            TabButton {
                contentItem: Text {
                    text: "Empleados"
                    color: parent.checked ? window.accentColor : window.textColor
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            TabButton {
                visible: AppController.currentRole === "admin"
                contentItem: Text {
                    text: "Empresa"
                    color: parent.checked ? window.accentColor : window.textColor
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            TabButton {
                visible: AppController.currentRole === "admin"
                contentItem: Text {
                    text: "Categorías"
                    color: parent.checked ? window.accentColor : window.textColor
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            TabButton {
                visible: AppController.currentRole === "admin"
                contentItem: Text {
                    text: "Esquemas"
                    color: parent.checked ? window.accentColor : window.textColor
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            TabButton {
                contentItem: Text {
                    text: "Campos Globales"
                    color: parent.checked ? window.accentColor : window.textColor
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            TabButton {
                visible: AppController.currentRole === "admin"
                contentItem: Text {
                    text: "Estructura Recibo"
                    color: parent.checked ? window.accentColor : window.textColor
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            TabButton {
                contentItem: Text {
                    text: "Vista Previa"
                    color: parent.checked ? window.accentColor : window.textColor
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            TabButton {
                contentItem: Text {
                    text: "Historial"
                    color: parent.checked ? window.accentColor : window.textColor
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // ── Main Content Area ───────────────────────────────────
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: mainTabBar.currentIndex

            // 0: Empleados View (Full CRUD)
            EmployeesView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // 1: Empresa View (Full CRUD)
            CompanyView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // 2: Categorías View (Full CRUD)
            CategoriesView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // 3: Esquemas View (Full CRUD + Schema Fields Model)
            SchemasView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // 4: Campos Globales View (Full CRUD)
            GlobalVarsView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // 5: Estructura Recibo View (Full CRUD Celdas Calculo)
            ReceiptStructureView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // 6: Vista Previa View (Live Liquidation & PDF/Export)
            PreviewView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // 7: Historial View (Saved Receipts History)
            ReceiptHistoryView {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
