import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

RowLayout {
    id: root

    property bool showEdit: true
    property bool showDelete: true
    property bool showDuplicate: false

    signal editClicked()
    signal deleteClicked()
    signal duplicateClicked()

    spacing: 4
    z: 10
    visible: AppController.currentRole === "admin"

    Button {
        visible: root.showDuplicate
        implicitWidth: 32
        implicitHeight: 32
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        flat: true
        text: "📋"
        font.pixelSize: 15
        ToolTip.visible: hovered
        ToolTip.text: "Duplicar"
        onClicked: root.duplicateClicked()
    }

    Button {
        visible: root.showEdit
        implicitWidth: 32
        implicitHeight: 32
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        flat: true
        text: "✏️"
        font.pixelSize: 15
        ToolTip.visible: hovered
        ToolTip.text: "Editar"
        onClicked: root.editClicked()
    }

    Button {
        visible: root.showDelete
        implicitWidth: 32
        implicitHeight: 32
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        flat: true
        text: "🗑️"
        font.pixelSize: 15
        ToolTip.visible: hovered
        ToolTip.text: "Eliminar"
        onClicked: root.deleteClicked()
    }
}
