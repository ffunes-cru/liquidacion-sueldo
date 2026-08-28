import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Rectangle {
    id: root

    property Window targetWindow: null
    property string title: "Sistema de Liquidación de Sueldos"

    signal settingsRequested()

    implicitHeight: 42
    color: Theme.panelBg
    radius: 12

    // Smooth connection with content below
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 14
        color: Theme.panelBg
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.borderColor
    }

    // ── Drag Window Area ─────────────────────────────────────────
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.rightMargin: 160
        z: 1

        onPressed: {
            if (root.targetWindow) {
                AppController.startWindowMove(root.targetWindow)
            }
        }

        onDoubleClicked: {
            if (root.targetWindow) {
                AppController.toggleMaximizeWindow(root.targetWindow)
            }
        }
    }

    // ── Header Title & Controls ──────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 150
        spacing: 12
        z: 2

        Text {
            text: "💼"
            font.pixelSize: 16
        }

        Label {
            text: root.title
            font.pixelSize: 13
            font.bold: true
            color: Theme.textColor
            elide: Text.ElideRight
        }

        Item { Layout.fillWidth: true }

        StyledButton {
            variant: "secondary"
            text: "⚙️"
            Layout.preferredWidth: 32
            Layout.preferredHeight: 28
            onClicked: root.settingsRequested()
        }
    }

    // ── Window Controls Row (HIGH VISIBILITY BUTTONS) ───────────
    Row {
        id: windowControlsRow
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 10
        spacing: 8
        z: 9999

        // Minimize Button (_)
        Rectangle {
            width: 36
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            radius: 6
            color: minMouse.containsMouse ? Theme.hoverBg : Qt.rgba(255, 255, 255, 0.12)
            border.color: Theme.borderColor
            border.width: 1

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -2
                text: "_"
                font.bold: true
                font.pixelSize: 14
                color: Theme.textColor
            }

            MouseArea {
                id: minMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.targetWindow) {
                        AppController.minimizeWindow(root.targetWindow)
                    }
                }
            }
        }

        // Maximize/Restore Button (□ / ❐)
        Rectangle {
            width: 36
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            radius: 6
            color: maxMouse.containsMouse ? Theme.hoverBg : Qt.rgba(255, 255, 255, 0.12)
            border.color: Theme.borderColor
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: (root.targetWindow && root.targetWindow.visibility === Window.Maximized) ? "❐" : "□"
                font.bold: true
                font.pixelSize: 13
                color: Theme.textColor
            }

            MouseArea {
                id: maxMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.targetWindow) {
                        AppController.toggleMaximizeWindow(root.targetWindow)
                    }
                }
            }
        }

        // Close Button (✕) - Vibrant Red Background
        Rectangle {
            width: 38
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            radius: 6
            color: closeMouse.containsMouse ? "#DC2626" : "#EF4444"
            border.color: "#B91C1C"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.bold: true
                font.pixelSize: 13
                color: "#FFFFFF"
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.targetWindow) {
                        AppController.closeWindow(root.targetWindow)
                    }
                }
            }
        }
    }
}
