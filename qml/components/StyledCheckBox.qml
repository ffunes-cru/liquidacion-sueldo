import QtQuick 2.15
import QtQuick.Controls 2.15

CheckBox {
    id: control

    font.pixelSize: 13

    indicator: Rectangle {
        implicitWidth: 20
        implicitHeight: 20
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 4
        color: control.checked ? Theme.accentColor : Theme.inputBg
        border.color: control.checked ? Theme.accentColor : (control.hovered ? Theme.accentColor : Theme.borderColor)
        border.width: 1.5

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: "#FFFFFF"
            font.pixelSize: 13
            font.bold: true
            visible: control.checked
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
