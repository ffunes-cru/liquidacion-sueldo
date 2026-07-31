import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property alias text: inputField.text
    property alias placeholderText: inputField.placeholderText
    property string esquemaCodigo: "MENSUAL"
    property var allSuggestions: []
    property var filteredSuggestions: []

    implicitHeight: 42
    implicitWidth: 300

    onEsquemaCodigoChanged: reloadSuggestions()
    Component.onCompleted: reloadSuggestions()

    function reloadSuggestions() {
        allSuggestions = AppController.getAvailableFormulaVariables(esquemaCodigo)
        filterCurrentWord()
    }

    function filterCurrentWord() {
        var cursor = inputField.cursorPosition
        var fullText = inputField.text
        var leftText = fullText.substring(0, cursor)

        // Find current word prefix being typed
        var match = leftText.match(/([a-zA-Z0-9_]+)$/)
        var prefix = match ? match[1].toLowerCase() : ""

        if (prefix.length === 0) {
            filteredSuggestions = allSuggestions
            return
        }

        var results = []
        for (var i = 0; i < allSuggestions.length; i++) {
            var item = allSuggestions[i]
            if (item.code.toLowerCase().indexOf(prefix) >= 0 || item.description.toLowerCase().indexOf(prefix) >= 0) {
                results.push(item)
            }
        }
        filteredSuggestions = results
    }

    function insertSuggestion(codeStr) {
        var cleanCode = codeStr.split("(")[0] // If function like round(val, n), insert prefix or full
        var cursor = inputField.cursorPosition
        var fullText = inputField.text
        var leftText = fullText.substring(0, cursor)
        var rightText = fullText.substring(cursor)

        var match = leftText.match(/([a-zA-Z0-9_]+)$/)
        var prefix = match ? match[1] : ""
        var newLeft = leftText.substring(0, leftText.length - prefix.length) + codeStr

        inputField.text = newLeft + rightText
        inputField.cursorPosition = newLeft.length
        suggestionPopup.close()
        inputField.forceActiveFocus()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: window.inputBg
            radius: 6
            border.color: inputField.activeFocus ? window.accentColor : window.borderColor
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 6

                TextField {
                    id: inputField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    font.family: "Monospace"
                    font.pixelSize: 13
                    color: "#a6e3a1"
                    background: null

                    onTextChanged: {
                        filterCurrentWord()
                        if (activeFocus && filteredSuggestions.length > 0) {
                            suggestionPopup.open()
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus && filteredSuggestions.length > 0) {
                            suggestionPopup.open()
                        }
                    }

                    Keys.onPressed: function(event) {
                        if (suggestionPopup.opened) {
                            if (event.key === Qt.Key_Down) {
                                suggestionList.currentIndex = Math.min(suggestionList.currentIndex + 1, suggestionList.count - 1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                suggestionList.currentIndex = Math.max(suggestionList.currentIndex - 1, 0)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                                if (suggestionList.currentIndex >= 0 && suggestionList.currentIndex < filteredSuggestions.length) {
                                    insertSuggestion(filteredSuggestions[suggestionList.currentIndex].code)
                                    event.accepted = true
                                }
                            } else if (event.key === Qt.Key_Escape) {
                                suggestionPopup.close()
                                event.accepted = true
                            }
                        }
                    }
                }

                Button {
                    implicitWidth: 28
                    implicitHeight: 28
                    text: "💡"
                    flat: true
                    ToolTip.visible: hovered
                    ToolTip.text: "Variables e IntelliSense para Fórmulas"
                    onClicked: {
                        filterCurrentWord()
                        if (suggestionPopup.opened) suggestionPopup.close()
                        else suggestionPopup.open()
                    }
                }
            }
        }
    }

    Popup {
        id: suggestionPopup
        y: root.height + 4
        width: Math.max(root.width, 380)
        implicitHeight: Math.min(contentColumn.implicitHeight + 20, 260)
        padding: 8
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            color: window.cardBg
            radius: 8
            border.color: window.accentColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            id: contentColumn
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Sugerencias de Variables (IDE IntelliSense)"
                    font.pixelSize: 11
                    font.bold: true
                    color: window.accentColor
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: filteredSuggestions.length + " var"
                    font.pixelSize: 10
                    color: window.subtextColor
                }
            }

            ListView {
                id: suggestionList
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.min(count * 38, 220)
                clip: true
                model: filteredSuggestions

                delegate: Rectangle {
                    width: suggestionList.width
                    height: 36
                    radius: 4
                    color: suggestionList.currentIndex === index ? "#383852" : (mouseArea.containsMouse ? "#2e2e42" : "transparent")

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            suggestionList.currentIndex = index
                            insertSuggestion(modelData.code)
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 4
                            color: modelData.category === "Función Motor" ? "#89b4fa" :
                                   (modelData.category === "Acumulador" ? "#f38ba8" :
                                   (modelData.category === "Variable Global" ? "#fab387" : "#a6e3a1"))

                            Label {
                                anchors.centerIn: parent
                                text: modelData.category ? modelData.category.substring(0, 1) : "V"
                                font.pixelSize: 10
                                font.bold: true
                                color: "#11111b"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Label {
                                text: modelData.code
                                font.family: "Monospace"
                                font.bold: true
                                font.pixelSize: 12
                                color: window.textColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Label {
                                text: modelData.description
                                font.pixelSize: 10
                                color: window.subtextColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
