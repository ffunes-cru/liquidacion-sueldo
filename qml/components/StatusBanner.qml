import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string message: ""
    property bool isError: false
    property int autoDismissMs: 0  // 0 = no auto-dismiss

    signal dismissed()

    visible: message !== ""
    Layout.fillWidth: true
    implicitHeight: visible ? 45 : 0
    color: isError ? "#44232b" : "#1e3a34"
    radius: 6
    border.color: isError ? Theme.dangerColor : Theme.successColor

    Behavior on implicitHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Label {
            text: root.isError ? "⚠" : "✓"
            font.pixelSize: 16
            color: root.isError ? Theme.dangerColor : Theme.successColor
        }

        Label {
            text: root.message
            color: root.isError ? Theme.dangerColor : Theme.successColor
            font.pixelSize: 13
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Button {
            implicitWidth: 28
            implicitHeight: 28
            text: "✕"
            flat: true
            onClicked: {
                root.message = ""
                root.dismissed()
            }

            contentItem: Text {
                text: parent.text
                color: root.isError ? Theme.dangerColor : Theme.successColor
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Timer {
        id: autoDismissTimer
        interval: root.autoDismissMs
        running: root.autoDismissMs > 0 && root.visible
        onTriggered: {
            root.message = ""
            root.dismissed()
        }
    }

    onMessageChanged: {
        if (autoDismissMs > 0 && message !== "") {
            autoDismissTimer.restart()
        }
    }
}
