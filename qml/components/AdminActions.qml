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

    spacing: 6
    z: 10
    visible: true

    Rectangle {
        visible: root.showDuplicate
        implicitWidth: 30; implicitHeight: 28; radius: 4
        color: btnDupArea.containsMouse ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.3) : Qt.rgba(255, 255, 255, 0.08)
        border.color: Theme.borderColor

        Text { anchors.centerIn: parent; text: "📋"; font.pixelSize: 13 }

        MouseArea {
            id: btnDupArea
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.duplicateClicked()
        }
    }

    Rectangle {
        visible: root.showEdit
        implicitWidth: 30; implicitHeight: 28; radius: 4
        color: btnEditArea.containsMouse ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.3) : Qt.rgba(255, 255, 255, 0.08)
        border.color: Theme.borderColor

        Text { anchors.centerIn: parent; text: "✏️"; font.pixelSize: 13 }

        MouseArea {
            id: btnEditArea
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.editClicked()
        }
    }

    Rectangle {
        visible: root.showDelete
        implicitWidth: 30; implicitHeight: 28; radius: 4
        color: btnDelArea.containsMouse ? Qt.rgba(Theme.dangerColor.r, Theme.dangerColor.g, Theme.dangerColor.b, 0.35) : Qt.rgba(255, 255, 255, 0.08)
        border.color: Theme.borderColor

        Text { anchors.centerIn: parent; text: "🗑️"; font.pixelSize: 13 }

        MouseArea {
            id: btnDelArea
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.deleteClicked()
        }
    }
}
