import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: root

    property int dialogWidth: 480
    property int dialogHeight: -1  // -1 = auto from content

    modal: true
    anchors.centerIn: parent
    width: dialogWidth
    height: dialogHeight > 0 ? dialogHeight : implicitHeight

    padding: 20
    topPadding: 15
    bottomPadding: 18
    leftPadding: 24
    rightPadding: 24

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    background: Rectangle {
        color: Theme.panelBg
        radius: 10
        border.color: Theme.borderColor
        border.width: 1
    }

    header: Rectangle {
        implicitHeight: 52
        color: "transparent"
        radius: 10

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24

            Label {
                text: root.title
                font.pixelSize: 16
                font.bold: true
                color: Theme.textColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.borderColor
        }
    }

    enter: Transition {
        NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: 200; easing.type: Easing.OutBack }
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 180 }
    }

    exit: Transition {
        NumberAnimation { property: "scale"; from: 1.0; to: 0.85; duration: 150; easing.type: Easing.InQuad }
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150 }
    }
}
