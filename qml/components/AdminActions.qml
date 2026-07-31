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
    visible: AppController.currentRole === "admin"

    Button {
        visible: root.showDuplicate
        implicitWidth: 30
        implicitHeight: 28
        flat: true
        text: "📋"
        ToolTip.visible: hovered
        ToolTip.text: "Duplicar"
        onClicked: root.duplicateClicked()
    }

    Button {
        visible: root.showEdit
        implicitWidth: 30
        implicitHeight: 28
        flat: true
        text: "✏️"
        ToolTip.visible: hovered
        ToolTip.text: "Editar"
        onClicked: root.editClicked()
    }

    Button {
        visible: root.showDelete
        implicitWidth: 30
        implicitHeight: 28
        flat: true
        text: "🗑️"
        ToolTip.visible: hovered
        ToolTip.text: "Eliminar"
        onClicked: root.deleteClicked()
    }
}
