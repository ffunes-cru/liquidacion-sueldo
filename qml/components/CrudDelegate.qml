import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Rectangle {
    id: root

    // ── Data properties ─────────────────────────────────────────
    property string primaryText: ""
    property string secondaryText: "Doble clic para editar"
    property string badgeText: ""
    property color badgeColor: Theme.accentColor
    property bool badgeCircular: false
    property string valueText: ""
    property color valueColor: Theme.successColor
    property var itemData: ({})
    property int itemId: -1

    // ── Behavior flags ──────────────────────────────────────────
    property bool showAdminActions: true
    property bool showDuplicate: false

    // ── Custom content slot (between text and value) ───────────
    property Component middleContent: null

    // ── Signals ─────────────────────────────────────────────────
    signal editRequested(var itemData)
    signal deleteRequested(int itemId)
    signal duplicateRequested(var itemData)

    // ── Visual ──────────────────────────────────────────────────
    width: ListView.view ? ListView.view.width : parent.width
    height: 56
    radius: 6
    color: mouseArea.containsMouse ? Theme.hoverBg : Theme.cardBg
    border.color: Theme.borderColor
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onDoubleClicked: root.editRequested(root.itemData)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 15

        // Badge pill (left)
        BadgePill {
            visible: root.badgeText !== ""
            text: root.badgeText
            badgeColor: root.badgeColor
            circular: root.badgeCircular
        }

        // Primary + secondary text
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                text: root.primaryText
                font.bold: true
                font.pixelSize: 14
                color: Theme.textColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Label {
                visible: root.secondaryText !== ""
                text: root.secondaryText
                font.pixelSize: 11
                color: Theme.subtextColor
            }
        }

        // Middle content slot (optional)
        Loader {
            visible: root.middleContent !== null
            sourceComponent: root.middleContent
            Layout.alignment: Qt.AlignVCenter
        }

        // Value display (right)
        Label {
            visible: root.valueText !== ""
            text: root.valueText
            font.bold: true
            font.pixelSize: 15
            color: root.valueColor
        }

        // Admin action buttons
        AdminActions {
            visible: root.showAdminActions && AppController.currentRole === "admin"
            showDuplicate: root.showDuplicate
            onEditClicked: root.editRequested(root.itemData)
            onDeleteClicked: root.deleteRequested(root.itemId)
            onDuplicateClicked: root.duplicateRequested(root.itemData)
        }
    }
}
