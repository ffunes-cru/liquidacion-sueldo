import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    // ── Core properties ─────────────────────────────────────────
    property string title: "Gestión de Elementos"
    property string newButtonText: "+ Nuevo"
    property var model: null
    property Component delegateComponent: null

    // ── Search ──────────────────────────────────────────────────
    property bool searchEnabled: false
    property string searchPlaceholder: "Buscar..."
    property string searchText: ""

    // ── Empty state ─────────────────────────────────────────────
    property string emptyStateText: "No hay registros"
    property string emptyStateIcon: "📋"

    // ── Counter ─────────────────────────────────────────────────
    property string counterSuffix: "registrados"

    // ── Signals ─────────────────────────────────────────────────
    signal createRequested()
    signal editRequested(var itemData)
    signal deleteRequested(int itemId)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // Header Action Bar
        ActionBar {
            title: root.title
            subtitle: (root.model && root.model.count !== undefined ? root.model.count : 0) + " " + root.counterSuffix

            Button {
                text: root.newButtonText
                highlighted: true
                visible: AppController.currentRole === "admin"
                onClicked: root.createRequested()
            }
        }

        // Search Bar (optional)
        Rectangle {
            visible: root.searchEnabled
            Layout.fillWidth: true
            implicitHeight: visible ? 44 : 0
            color: Theme.panelBg
            radius: 8
            border.color: Theme.borderColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Label {
                    text: "🔍"
                    font.pixelSize: 16
                }

                StyledTextField {
                    Layout.fillWidth: true
                    placeholderText: root.searchPlaceholder
                    text: root.searchText
                    onTextChanged: root.searchText = text
                }
            }
        }

        // Main Items List Container
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.panelBg
            radius: 8
            border.color: Theme.borderColor

            // Empty state
            ColumnLayout {
                visible: !root.model || root.model.count === 0
                anchors.centerIn: parent
                spacing: 10

                Label {
                    text: root.emptyStateIcon
                    font.pixelSize: 48
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.5
                }

                Label {
                    text: root.emptyStateText
                    font.pixelSize: 14
                    color: Theme.subtextColor
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            ScrollView {
                id: mainScroll
                anchors.fill: parent
                anchors.margins: 15
                clip: true
                visible: root.model && root.model.count > 0

                ListView {
                    id: listView
                    width: mainScroll.width - 10
                    model: root.model
                    delegate: root.delegateComponent
                    spacing: 8

                    // Forward signals from CrudDelegate children
                    Connections {
                        target: null
                        enabled: false
                    }
                }
            }
        }
    }
}
