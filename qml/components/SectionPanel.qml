import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string title: ""
    property color titleColor: Theme.accentColor
    property bool showTitle: title !== ""
    property int padding: 18

    default property alias content: contentContainer.data

    Layout.fillWidth: true
    implicitHeight: outerColumn.implicitHeight + 2 * padding
    color: Theme.panelBg
    radius: 8
    border.color: Theme.borderColor

    ColumnLayout {
        id: outerColumn
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 12

        Label {
            visible: root.showTitle
            text: root.title
            font.pixelSize: 16
            font.bold: true
            color: root.titleColor
        }

        ColumnLayout {
            id: contentContainer
            Layout.fillWidth: true
            spacing: 10
        }
    }
}
