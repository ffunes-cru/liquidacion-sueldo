import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

AppDialog {
    id: root

    title: "⚠️ Confirmación requerida"
    dialogWidth: 440
    dialogHeight: 220
    standardButtons: Dialog.NoButton

    property string message: "¿Está seguro de realizar esta acción?"
    property string iconText: "⚠️"
    property string confirmButtonText: "Sí, Eliminar"
    property string confirmButtonVariant: "danger"

    signal confirmed()

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Label {
                text: root.iconText
                font.pixelSize: 32
                Layout.alignment: Qt.AlignTop
            }

            Label {
                text: root.message
                font.pixelSize: 13
                color: Theme.textColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            StyledButton {
                variant: "secondary"
                text: "Cancelar"
                onClicked: root.close()
            }

            StyledButton {
                variant: root.confirmButtonVariant
                text: root.confirmButtonText
                onClicked: {
                    root.confirmed()
                    root.close()
                }
            }
        }
    }
}
