import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root

    property string text: ""
    property string variant: ""
    property color badgeColor: {
        if (variant === "warning") return Theme.warningColor
        if (variant === "danger") return Theme.dangerColor
        if (variant === "success") return Theme.successColor
        if (variant === "info") return Theme.infoColor
        return Theme.accentColor
    }
    property bool circular: false
    property int fontSize: 12
    property bool bold: true

    implicitWidth: circular ? implicitHeight : Math.max(label.implicitWidth + 16, 36)
    implicitHeight: circular ? 36 : 28
    radius: circular ? height / 2 : 4
    color: Qt.rgba(badgeColor.r, badgeColor.g, badgeColor.b, 0.2)
    border.color: badgeColor
    border.width: 1

    Label {
        id: label
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        text: root.text
        font.bold: root.bold
        font.pixelSize: root.fontSize
        color: root.badgeColor
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    ToolTip.visible: mouseArea.containsMouse && label.truncated
    ToolTip.text: root.text
    ToolTip.delay: 300

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
