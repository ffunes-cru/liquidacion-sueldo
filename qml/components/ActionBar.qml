import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""         // e.g. "N registrados"
    property bool showSubtitle: true

    // Right-side content (buttons, combos, etc)
    default property alias rightContent: rightContainer.data

    Layout.fillWidth: true
    implicitHeight: 60
    color: Theme.panelBg
    radius: 8
    border.color: Theme.borderColor

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        spacing: 15

        Label {
            text: root.title
            font.pixelSize: 18
            font.bold: true
            color: Theme.textColor
        }

        Label {
            visible: root.showSubtitle && root.subtitle !== ""
            text: root.subtitle
            font.pixelSize: 12
            color: Theme.subtextColor
        }

        Item { Layout.fillWidth: true }

        Row {
            id: rightContainer
            spacing: 10
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
