import QtQuick 2.15
import QtQuick.Controls 2.15

ComboBox {
    id: control

    font.pixelSize: 13
    implicitWidth: 160
    implicitHeight: 36

    displayText: {
        if (currentIndex < 0 || currentIndex >= count) return ""
        var item = (typeof model !== "undefined" && model && model.length > currentIndex) ? model[currentIndex] : currentText
        if (typeof item === "object" && item !== null) {
            if (control.textRole && typeof item[control.textRole] !== "undefined") {
                return String(item[control.textRole])
            }
            if (typeof item.label !== "undefined") return String(item.label)
            if (typeof item.text !== "undefined") return String(item.text)
            if (typeof item.nombre !== "undefined") return String(item.nombre)
            if (typeof item.name !== "undefined") return String(item.name)
        }
        return currentText || ""
    }

    delegate: ItemDelegate {
        width: ListView.view ? ListView.view.width : control.width
        implicitHeight: 34
        text: {
            var item = typeof modelData !== "undefined" ? modelData : (typeof model !== "undefined" ? model : null)
            if (typeof item === "object" && item !== null) {
                if (control.textRole && typeof item[control.textRole] !== "undefined") {
                    return String(item[control.textRole])
                }
                if (typeof item.label !== "undefined") return String(item.label)
                if (typeof item.text !== "undefined") return String(item.text)
                if (typeof item.nombre !== "undefined") return String(item.nombre)
                if (typeof item.name !== "undefined") return String(item.name)
            }
            return (item !== null && typeof item !== "undefined") ? String(item) : ""
        }
        contentItem: Text {
            leftPadding: 8
            rightPadding: 8
            text: parent.text
            color: Theme.textColor
            font.pixelSize: 13
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: highlighted ? Theme.selectedBg : (hovered ? Theme.hoverBg : Theme.cardBg)
            radius: 4
        }
        highlighted: control.highlightedIndex === index
    }

    contentItem: Text {
        leftPadding: 12
        rightPadding: 28
        text: control.displayText
        font.pixelSize: 13
        color: Theme.textColor
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 160
        implicitHeight: 36
        color: Theme.inputBg
        border.color: control.activeFocus || control.pressed || (control.popup && control.popup.visible) ? Theme.accentColor : Theme.borderColor
        border.width: 1
        radius: 6
    }

    popup: Popup {
        y: control.height + 4
        width: Math.max(control.width, 220)
        implicitHeight: Math.min(contentItem.contentHeight + 10, 240)
        padding: 4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }

        background: Rectangle {
            color: Theme.cardBg
            border.color: Theme.borderColor
            border.width: 1
            radius: 8
        }
    }
}
