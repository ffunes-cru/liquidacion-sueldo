import QtQuick 2.15
import QtQuick.Controls 2.15

ComboBox {
    id: control

    font.pixelSize: 13

    delegate: ItemDelegate {
        width: control.width
        implicitHeight: 32
        text: {
            if (control.textRole && model && model[control.textRole] !== undefined) {
                var v = model[control.textRole]
                if (typeof v === "string" || typeof v === "number") return v.toString()
            }
            if (model && model.text !== undefined && typeof model.text !== "object") return model.text.toString()
            if (model && model.name !== undefined && typeof model.name !== "object") return model.name.toString()
            if (model && model.nombre !== undefined && typeof model.nombre !== "object") return model.nombre.toString()
            if (model && model.code !== undefined && typeof model.code !== "object") return model.code.toString()
            if (model && model.codigo !== undefined && typeof model.codigo !== "object") return model.codigo.toString()
            if (typeof modelData !== "undefined" && modelData !== null && typeof modelData !== "object") return modelData.toString()
            return ""
        }
        contentItem: Text {
            text: parent.text
            color: Theme.textColor
            font.pixelSize: 13
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: highlighted ? Theme.selectedBg : (hovered ? Theme.hoverBg : Theme.cardBg)
        }
        highlighted: control.highlightedIndex === index
    }

    indicator: Canvas {
        id: canvas
        x: control.width - width - 12
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 10
        height: 6
        contextType: "2d"

        Connections {
            target: control
            function onPressedChanged() { canvas.requestPaint() }
        }

        onPaint: {
            var context = getContext("2d")
            context.reset()
            context.moveTo(0, 0)
            context.lineTo(width / 2, height)
            context.lineTo(width, 0)
            context.strokeStyle = Theme.subtextColor
            context.lineWidth = 1.5
            context.stroke()
        }
    }

    contentItem: Text {
        leftPadding: 12
        rightPadding: control.indicator.width + 18
        text: control.displayText || control.currentText || ""
        font.pixelSize: 13
        color: Theme.textColor
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 160
        implicitHeight: 36
        color: Theme.inputBg
        border.color: control.activeFocus || control.pressed ? Theme.accentColor : Theme.borderColor
        border.width: 1
        radius: 6

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 200)
        padding: 4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex

            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: Theme.cardBg
            border.color: Theme.borderColor
            border.width: 1
            radius: 8
        }
    }
}
