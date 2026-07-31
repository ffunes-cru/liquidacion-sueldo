import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

TabBar {
    id: control

    property var quincenas: ["Q1", "Q2"]
    property string currentQuincena: "Q1"

    background: Rectangle { color: window.panelBg }

    Repeater {
        model: control.quincenas
        TabButton {
            contentItem: Text {
                text: modelData
                color: parent.checked ? window.accentColor : window.textColor
                font.bold: parent.checked
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                control.currentQuincena = modelData
            }
        }
    }
}
