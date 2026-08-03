import QtQuick 2.15
import QtQuick.Controls 2.15

Switch {
    id: control

    font.pixelSize: 13

    indicator: Rectangle {
        implicitWidth: 44
        implicitHeight: 24
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 12
        color: control.checked ? Theme.accentColor : Theme.borderColor
        border.color: "transparent"

        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            y: 3
            width: 18
            height: 18
            radius: 9
            color: "#FFFFFF"

            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + 10
        text: control.text
        font: control.font
        color: Theme.textColor
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
