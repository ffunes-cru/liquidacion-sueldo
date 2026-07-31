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
        var cleanCode = codeStr.split("(")[0]
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
            color: Theme.inputBg
            radius: 6
            border.color: inputField.activeFocus ? Theme.accentColor : Theme.borderColor
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
                    color: Theme.successColor
                    background: null

                    onTextChanged: {
                        filterCurrentWord()
                        if (activeFocus && filteredSuggestions.length > 0) {
                            suggestionPopup.updatePosition()
                            suggestionPopup.open()
                        }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            reloadSuggestions()
                            if (filteredSuggestions.length > 0) {
                                suggestionPopup.updatePosition()
                                suggestionPopup.open()
                            }
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
                        reloadSuggestions()
                        if (suggestionPopup.opened) {
                            suggestionPopup.close()
                        } else {
                            suggestionPopup.updatePosition()
                            suggestionPopup.open()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: suggestionPopup
        width: Math.max(root.width, 380)
        implicitHeight: Math.min(contentColumn.implicitHeight + 20, 260)
        padding: 8
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        function updatePosition() {
            var globalPos = root.mapToItem(null, 0, root.height)
            var screenHeight = Overlay.overlay ? Overlay.overlay.height : 600
            if (globalPos.y + 260 > screenHeight) {
                y = -implicitHeight - 6
            } else {
                y = root.height + 4
            }
        }

        background: Rectangle {
            color: Theme.cardBg
            radius: 8
            border.color: Theme.accentColor
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
                    color: Theme.accentColor
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: filteredSuggestions.length + " var"
                    font.pixelSize: 10
                    color: Theme.subtextColor
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
                    color: suggestionList.currentIndex === index ? Theme.selectedBg : (mouseArea.containsMouse ? Theme.hoverBg : "transparent")

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

                        BadgePill {
                            text: modelData.category ? modelData.category.substring(0, 1) : "V"
                            badgeColor: modelData.category === "Función Motor" ? Theme.infoColor :
                                        (modelData.category === "Acumulador" ? Theme.dangerColor :
                                        (modelData.category === "Variable Global" ? Theme.warningColor :
                                        (modelData.category === "Variable Local" ? Theme.accentColor : Theme.successColor)))
                            circular: true
                            implicitWidth: 22
                            implicitHeight: 22
                            fontSize: 10
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Label {
                                text: modelData.code
                                font.family: "Monospace"
                                font.bold: true
                                font.pixelSize: 12
                                color: Theme.textColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Label {
                                text: modelData.description
                                font.pixelSize: 10
                                color: Theme.subtextColor
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
