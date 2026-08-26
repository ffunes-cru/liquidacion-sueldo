import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Item {
    id: root

    property date selectedDate: new Date()
    property string selectedDateString: Qt.formatDate(selectedDate, "yyyy-MM-dd")
    property bool readOnly: false

    readonly property int selectedDay: selectedDate.getDate()
    readonly property int selectedMonth: selectedDate.getMonth() + 1 // 1-12
    readonly property int selectedYear: selectedDate.getFullYear()
    readonly property string formattedDate: Qt.formatDate(selectedDate, "yyyy-MM-dd")
    readonly property string displayDate: Qt.formatDate(selectedDate, "dd/MM/yyyy")

    signal dateSelected(date newDate)

    implicitWidth: 145
    implicitHeight: 36

    // Navigation state inside popup
    property int currentViewMonth: selectedDate.getMonth() // 0-11
    property int currentViewYear: selectedDate.getFullYear()

    onSelectedDateChanged: {
        currentViewMonth = selectedDate.getMonth()
        currentViewYear = selectedDate.getFullYear()
        var f = Qt.formatDate(selectedDate, "yyyy-MM-dd")
        if (selectedDateString !== f) {
            selectedDateString = f
        }
    }

    onSelectedDateStringChanged: {
        if (selectedDateString && selectedDateString !== formattedDate) {
            var parts = selectedDateString.split("-")
            if (parts.length === 3) {
                var y = parseInt(parts[0], 10)
                var m = parseInt(parts[1], 10) - 1
                var d = parseInt(parts[2], 10)
                if (!isNaN(y) && !isNaN(m) && !isNaN(d)) {
                    selectedDate = new Date(y, m, d)
                }
            }
        }
    }

    // Helper functions for calendar logic
    function daysInMonth(month, year) {
        return new Date(year, month + 1, 0).getDate()
    }

    function firstDayOfWeek(month, year) {
        return new Date(year, month, 1).getDay() // 0=Sunday, 1=Monday...
    }

    readonly property var monthNames: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                       "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
    readonly property var dayHeaderNames: ["Do", "Lu", "Ma", "Mi", "Ju", "Vi", "Sá"]

    // ── Main Trigger Field / Button ─────────────────────────────
    Rectangle {
        id: triggerBox
        anchors.fill: parent
        radius: 6
        color: Theme.inputBg
        border.color: popup.opened ? Theme.accentColor : (triggerMouse.containsMouse ? Theme.accentColor : Theme.borderColor)
        border.width: popup.opened ? 2 : 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            Text {
                text: "📅"
                font.pixelSize: 14
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.displayDate
                color: Theme.textColor
                font.pixelSize: 13
                font.bold: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: triggerMouse
            anchors.fill: parent
            hoverEnabled: !root.readOnly
            enabled: !root.readOnly
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.currentViewMonth = root.selectedDate.getMonth()
                root.currentViewYear = root.selectedDate.getFullYear()
                if (popup.opened) popup.close()
                else popup.open()
            }
        }
    }

    // ── Popup Calendar Modal ────────────────────────────────────
    Popup {
        id: popup
        y: {
            var globalY = root.mapToItem(null, 0, root.height).y
            var winH = (root.Window.window ? root.Window.window.height : 600)
            if (globalY + 290 + 10 > winH) {
                return -290 - 4
            } else {
                return root.height + 4
            }
        }
        x: {
            var globalX = root.mapToItem(null, 0, 0).x
            var winW = (root.Window.window ? root.Window.window.width : 800)
            if (globalX + 270 + 10 > winW) {
                return root.width - 270
            } else {
                return 0
            }
        }
        width: 270
        height: 290
        padding: 10
        modal: false
        focus: true

        background: Rectangle {
            color: Theme.panelBg
            border.color: Theme.borderColor
            border.width: 1
            radius: 10

            // Subdued Drop Shadow effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                color: "transparent"
                border.color: Qt.rgba(0, 0, 0, 0.2)
                radius: 10
                z: -1
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            // ── Header: Month / Year Navigation & Today ─────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Prev Month Button
                Rectangle {
                    width: 28; height: 28
                    radius: 4
                    color: prevMouse.containsMouse ? Theme.hoverBg : "transparent"
                    Text { text: "◄"; font.pixelSize: 10; color: Theme.textColor; anchors.centerIn: parent }
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentViewMonth === 0) {
                                root.currentViewMonth = 11
                                root.currentViewYear--
                            } else {
                                root.currentViewMonth--
                            }
                        }
                    }
                }

                // Month Year Title Label
                Label {
                    text: root.monthNames[root.currentViewMonth] + " " + root.currentViewYear
                    font.bold: true
                    font.pixelSize: 13
                    color: Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                // Next Month Button
                Rectangle {
                    width: 28; height: 28
                    radius: 4
                    color: nextMouse.containsMouse ? Theme.hoverBg : "transparent"
                    Text { text: "►"; font.pixelSize: 10; color: Theme.textColor; anchors.centerIn: parent }
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentViewMonth === 11) {
                                root.currentViewMonth = 0
                                root.currentViewYear++
                            } else {
                                root.currentViewMonth++
                            }
                        }
                    }
                }

                // Today Button
                Rectangle {
                    width: 44; height: 26
                    radius: 4
                    color: todayMouse.containsMouse ? Theme.hoverBg : Qt.rgba(255, 255, 255, 0.05)
                    border.color: Theme.borderColor
                    border.width: 1

                    Text {
                        text: "Hoy"
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.textColor
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: todayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var today = new Date()
                            root.selectedDate = today
                            root.dateSelected(today)
                            popup.close()
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.borderColor
            }

            // ── Day Header (Do, Lu, Ma...) ──────────────────────
            Grid {
                columns: 7
                Layout.fillWidth: true
                columnSpacing: 0
                rowSpacing: 0

                Repeater {
                    model: root.dayHeaderNames
                    delegate: Item {
                        width: 36
                        height: 22
                        Text {
                            text: modelData
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.subtextColor
                            anchors.centerIn: parent
                        }
                    }
                }
            }

            // ── Days Grid (42 Cells) ────────────────────────────
            Grid {
                columns: 7
                Layout.fillWidth: true
                Layout.fillHeight: true
                columnSpacing: 0
                rowSpacing: 2

                Repeater {
                    model: 42 // 6 rows of 7 days

                    delegate: Item {
                        width: 36
                        height: 30

                        // Calculate day info for this index
                        property int firstDay: root.firstDayOfWeek(root.currentViewMonth, root.currentViewYear)
                        property int totalDays: root.daysInMonth(root.currentViewMonth, root.currentViewYear)
                        property int dayNum: index - firstDay + 1
                        property bool isCurrentMonth: dayNum >= 1 && dayNum <= totalDays

                        property bool isSelected: {
                            if (!isCurrentMonth) return false
                            return dayNum === root.selectedDate.getDate() &&
                                   root.currentViewMonth === root.selectedDate.getMonth() &&
                                   root.currentViewYear === root.selectedDate.getFullYear()
                        }

                        property bool isToday: {
                            if (!isCurrentMonth) return false
                            var t = new Date()
                            return dayNum === t.getDate() &&
                                   root.currentViewMonth === t.getMonth() &&
                                   root.currentViewYear === t.getFullYear()
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            radius: 14
                            visible: isCurrentMonth

                            color: parent.isSelected ? Theme.accentColor : (dayMouse.containsMouse ? Theme.hoverBg : "transparent")
                            border.color: parent.isToday && !parent.isSelected ? Theme.accentColor : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.dayNum > 0 ? parent.parent.dayNum : ""
                                font.pixelSize: 12
                                font.bold: parent.parent.isSelected || parent.parent.isToday
                                color: parent.parent.isSelected ? "#FFFFFF" : Theme.textColor
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: parent.parent.isCurrentMonth
                                enabled: parent.parent.isCurrentMonth
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var newD = new Date(root.currentViewYear, root.currentViewMonth, parent.parent.dayNum)
                                    root.selectedDate = newD
                                    root.dateSelected(newD)
                                    popup.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
