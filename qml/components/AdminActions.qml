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
        implicitWidth: 32; implicitHeight: 30; radius: 6
        color: btnDupArea.containsMouse ? Theme.hoverBg : Theme.cardBg
        border.color: btnDupArea.containsMouse ? Theme.accentColor : Theme.borderColor

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text { anchors.centerIn: parent; text: "📋"; font.pixelSize: 13 }

        MouseArea {
            id: btnDupArea
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.duplicateClicked()
        }
    }

    Rectangle {
        visible: root.showEdit
        implicitWidth: 32; implicitHeight: 30; radius: 6
        color: btnEditArea.containsMouse ? Theme.hoverBg : Theme.cardBg
        border.color: btnEditArea.containsMouse ? Theme.accentColor : Theme.borderColor

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text { anchors.centerIn: parent; text: "✏️"; font.pixelSize: 13 }

        MouseArea {
            id: btnEditArea
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.editClicked()
        }
    }

    Rectangle {
        visible: root.showDelete
        implicitWidth: 32; implicitHeight: 30; radius: 6
        color: btnDelArea.containsMouse ? Qt.rgba(Theme.dangerColor.r, Theme.dangerColor.g, Theme.dangerColor.b, 0.2) : Theme.cardBg
        border.color: btnDelArea.containsMouse ? Theme.dangerColor : Theme.borderColor

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text { anchors.centerIn: parent; text: "🗑️"; font.pixelSize: 13 }

        MouseArea {
            id: btnDelArea
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.deleteClicked()
        }
    }
}
