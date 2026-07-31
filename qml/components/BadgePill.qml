import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root

    property string text: ""
    property color badgeColor: Theme.accentColor
    property bool circular: false
    property int fontSize: 12
    property bool bold: true

    implicitWidth: circular ? implicitHeight : Math.max(label.implicitWidth + 16, 36)
    implicitHeight: circular ? 36 : 28
    radius: circular ? height / 2 : 4
    color: Qt.alpha(badgeColor, 0.2)
    border.color: badgeColor

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.bold: root.bold
        font.pixelSize: root.fontSize
        color: root.badgeColor
        elide: Text.ElideRight
    }
}
