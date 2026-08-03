import QtQuick 2.15
import QtQuick.Controls 2.15

ComboBox {
    id: control

    font.pixelSize: 13

    delegate: ItemDelegate {
        width: control.width
        implicitHeight: 34
        text: {
            if (control.textRole && model && model[control.textRole] !== undefined) {
                var v = model[control.textRole]
                return (v !== null && typeof v !== "undefined") ? String(v) : ""
            }
            if (typeof modelData !== "undefined" && modelData !== null) {
                if (typeof modelData === "object") {
                    return modelData.text !== undefined ? String(modelData.text) : (modelData.nombre !== undefined ? String(modelData.nombre) : (modelData.name !== undefined ? String(modelData.name) : ""))
                }
                return String(modelData)
            }
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

    contentItem: Text {
        leftPadding: 12
        rightPadding: 24
        text: control.displayText || ""
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
