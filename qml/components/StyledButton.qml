import QtQuick 2.15
import QtQuick.Controls 2.15

Button {
    id: control

    // Variants: "primary", "secondary", "danger", "ghost"
    property string variant: "primary"
    property color customColor: Qt.rgba(0,0,0,0)

    font.pixelSize: 13
    font.weight: Font.Medium
    implicitHeight: 36
    implicitWidth: Math.max(80, contentItem.implicitWidth + 24)

    contentItem: Text {
        text: control.text
        font: control.font
        color: {
            if (!control.enabled) return Theme.subtextColor
            if (variant === "primary") return "#FFFFFF"
            if (variant === "danger") return "#FFFFFF"
            if (variant === "secondary") return Theme.textColor
            return Theme.accentColor
        }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 80
        implicitHeight: 36
        radius: 6
        color: {
            if (!control.enabled) return Theme.inputBg
            if (customColor.a > 0) return control.pressed ? Qt.darker(customColor, 1.2) : (control.hovered ? Qt.lighter(customColor, 1.1) : customColor)
            if (variant === "primary") return control.pressed ? Qt.darker(Theme.accentColor, 1.2) : (control.hovered ? Qt.lighter(Theme.accentColor, 1.1) : Theme.accentColor)
            if (variant === "danger") return control.pressed ? Qt.darker(Theme.dangerColor, 1.2) : (control.hovered ? Qt.lighter(Theme.dangerColor, 1.1) : Theme.dangerColor)
            if (variant === "secondary") return control.pressed ? Theme.hoverBg : (control.hovered ? Theme.cardBg : Theme.inputBg)
            return control.hovered ? Theme.hoverBg : "transparent"
        }
        border.color: {
            if (!control.enabled) return Theme.borderColor
            if (variant === "secondary") return control.activeFocus ? Theme.accentColor : Theme.borderColor
            return "transparent"
        }
        border.width: variant === "secondary" ? 1 : 0

        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
