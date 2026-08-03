import QtQuick 2.15
import QtQuick.Controls 2.15

TabButton {
    id: control

    implicitHeight: 38
    implicitWidth: Math.max(100, contentItem.implicitWidth + 24)

    contentItem: Text {
        text: control.text
        font.pixelSize: 13
        font.weight: control.checked ? Font.DemiBold : Font.Normal
        color: control.checked ? Theme.accentColor : (control.hovered ? Theme.textColor : Theme.subtextColor)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    background: Rectangle {
        implicitHeight: 38
        radius: 8
        color: control.checked ? Theme.cardBg : (control.hovered ? Theme.hoverBg : "transparent")
        border.color: control.checked ? Theme.accentColor : (control.hovered ? Theme.borderColor : "transparent")
        border.width: control.checked ? 1.5 : (control.hovered ? 1 : 0)

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        // Bottom active line indicator for extra clean look
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: control.checked ? parent.width * 0.6 : 0
            height: 3
            radius: 1.5
            color: Theme.accentColor
            visible: control.checked

            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }
    }
}
