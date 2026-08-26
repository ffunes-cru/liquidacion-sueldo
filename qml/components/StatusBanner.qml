import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string message: ""
    property alias text: root.message
    property bool isError: false
    property string variant: isError ? "danger" : "info"
    property int autoDismissMs: 0  // 0 = no auto-dismiss

    signal dismissed()

    readonly property color bannerColor: {
        if (variant === "danger" || isError) return Theme.isDark ? "#44232b" : "#fee2e2"
        if (variant === "warning") return Theme.isDark ? "#423215" : "#fef3c7"
        if (variant === "success") return Theme.isDark ? "#1e3a34" : "#d1fae5"
        return Theme.isDark ? "#1e293b" : "#e2e8f0"
    }

    readonly property color borderColorVal: {
        if (variant === "danger" || isError) return Theme.dangerColor
        if (variant === "warning") return Theme.warningColor
        if (variant === "success") return Theme.successColor
        return Theme.accentColor
    }

    readonly property color textColorVal: {
        if (variant === "danger" || isError) return Theme.dangerColor
        if (variant === "warning") return Theme.warningColor
        if (variant === "success") return Theme.successColor
        return Theme.textColor
    }

    readonly property string iconStr: {
        if (variant === "danger" || isError) return "⚠️"
        if (variant === "warning") return "🔒"
        if (variant === "success") return "✓"
        return "ℹ️"
    }

    visible: message !== ""
    Layout.fillWidth: true
    implicitHeight: visible ? 45 : 0
    color: bannerColor
    radius: 6
    border.color: borderColorVal
    border.width: 1

    Behavior on implicitHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Label {
            text: root.iconStr
            font.pixelSize: 15
            color: root.textColorVal
        }

        Label {
            text: root.message
            color: root.textColorVal
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
