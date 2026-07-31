import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

AppDialog {
    id: root

    property var errorsList: []

    title: "⚠️ Errores en la Liquidación"
    dialogWidth: 680
    dialogHeight: 460
    standardButtons: Dialog.Close

    function showErrors(errs) {
        if (!errs) return
        var list = []
        if (Array.isArray(errs)) {
            for (var i = 0; i < errs.length; i++) {
                list.push(errs[i])
            }
        } else {
            list.push(errs.toString())
        }
        if (list.length === 0) return
        root.errorsList = list
        root.open()
    }

    contentItem: ColumnLayout {
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.18)
            radius: 6
            border.color: "#EF4444"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Label {
                    text: "❌"
                    font.pixelSize: 18
                }

                Label {
                    text: "Se encontraron " + root.errorsList.length + " error(es) durante el proceso de evaluación de fórmulas."
                    color: "#F8FAFC"
                    font.bold: true
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
            }
        }

        Label {
            text: "Detalle de los errores detectados:"
            color: Theme.subtextColor
            font.pixelSize: 12
            font.bold: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                model: root.errorsList
                spacing: 8

                delegate: Rectangle {
                    width: ListView.view ? (ListView.view.width - 12) : 600
                    implicitHeight: errorLayout.implicitHeight + 16
                    color: "#1E293B"
                    radius: 6
                    border.color: "#334155"
                    border.width: 1

                    RowLayout {
                        id: errorLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Label {
                            text: (index + 1) + "."
                            color: "#EF4444"
                            font.bold: true
                            font.pixelSize: 13
                            Layout.alignment: Qt.AlignTop
                        }

                        Label {
                            text: modelData
                            color: "#F8FAFC"
                            font.family: "Monospace"
                            font.pixelSize: 12
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
