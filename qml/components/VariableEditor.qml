import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Rectangle {
    id: root

    property string fieldCode: ""
    property string fieldLabel: ""
    property string fieldType: "number"
    property string value: ""
    signal valueSaved(string newValue)

    implicitHeight: 42
    color: Theme.panelBg
    radius: 4
    border.color: Theme.borderColor

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 12

        Label {
            text: root.fieldLabel + " (" + root.fieldCode + ")"
            font.pixelSize: 13
            color: Theme.textColor
            Layout.preferredWidth: 200
            elide: Text.ElideRight
        }

        Item { Layout.fillWidth: true }

        Switch {
            visible: root.fieldType === "bool"
            checked: root.value === "true" || root.value === "1"
            onToggled: {
                root.valueSaved(checked ? "true" : "false")
            }
        }

        StyledTextField {
            visible: root.fieldType !== "bool"
            text: root.value
            Layout.preferredWidth: 140
            horizontalAlignment: Text.AlignRight
            inputMethodHints: root.fieldType === "number" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone

            onEditingFinished: {
                root.valueSaved(text)
            }
        }
    }
}
