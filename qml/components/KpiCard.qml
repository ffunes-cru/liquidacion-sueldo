import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string title: ""
    property string value: "$ 0.00"
    property color borderAccent: Theme.accentColor
    property color valueColor: Theme.accentColor
    property int titleSize: 11
    property int valueSize: 16

    Layout.fillWidth: true
    height: 65
    color: Theme.cardBg
    radius: 6
    border.color: borderAccent

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        Label {
            text: root.title
            color: Theme.subtextColor
            font.pixelSize: root.titleSize
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: root.value
            color: root.valueColor
            font.bold: true
            font.pixelSize: root.valueSize
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
