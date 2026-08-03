import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

Rectangle {
    id: root

    property var slices: []        // Array of { label: string, value: double, color: color }
    property double totalReference: 0.0
    property string title: "Distribución de Conceptos"

    implicitWidth: 460
    implicitHeight: 280
    color: Theme.cardBg
    radius: 8
    border.color: Theme.borderColor
    border.width: 1

    // Default vibrant palette for pie slices if color is not explicitly set
    readonly property var paletteColors: [
        "#74c7ec", "#a6e3a1", "#fab387", "#f38ba8", "#cba6f7",
        "#89b4fa", "#f9e2af", "#94e2d5", "#b4befe", "#e5c890"
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Label {
            text: root.title
            font.bold: true
            font.pixelSize: 13
            color: Theme.textColor
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 15

            // Canvas Pie Drawing
            Canvas {
                id: chartCanvas
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                antialiasing: true

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    if (!root.slices || root.slices.length === 0) {
                        ctx.fillStyle = Theme.subtextColor.toString()
                        ctx.font = "11px sans-serif"
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        ctx.fillText("Sin datos de gráfico", width / 2, height / 2)
                        return
                    }

                    var total = 0
                    for (var i = 0; i < root.slices.length; i++) {
                        total += Math.max(0, root.slices[i].value || 0)
                    }

                    var baseTotal = root.totalReference > 0 ? root.totalReference : total
                    if (baseTotal <= 0) baseTotal = 1.0

                    var centerX = width / 2
                    var centerY = height / 2
                    var radius = Math.min(centerX, centerY) - 8
                    var startAngle = -Math.PI / 2

                    for (var j = 0; j < root.slices.length; j++) {
                        var sliceVal = Math.max(0, root.slices[j].value || 0)
                        var sliceAngle = (sliceVal / baseTotal) * (2 * Math.PI)
                        var endAngle = startAngle + sliceAngle

                        var color = root.slices[j].color || root.paletteColors[j % root.paletteColors.length]
                        ctx.fillStyle = color.toString()
                        ctx.beginPath()
                        ctx.moveTo(centerX, centerY)
                        ctx.arc(centerX, centerY, radius, startAngle, endAngle, false)
                        ctx.closePath()
                        ctx.fill()

                        // Border outline
                        ctx.strokeStyle = Theme.cardBg.toString()
                        ctx.lineWidth = 1.5
                        ctx.stroke()

                        startAngle = endAngle
                    }

                    // Donut hole center
                    ctx.beginPath()
                    ctx.arc(centerX, centerY, radius * 0.45, 0, 2 * Math.PI, false)
                    ctx.fillStyle = Theme.cardBg.toString()
                    ctx.fill()
                }

                Connections {
                    target: root
                    function onSlicesChanged() { chartCanvas.requestPaint() }
                    function onTotalReferenceChanged() { chartCanvas.requestPaint() }
                }
            }

            // Legend Column
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.slices

                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 12; height: 12; radius: 3
                                color: modelData.color || root.paletteColors[index % root.paletteColors.length]
                            }

                            Label {
                                text: modelData.label
                                font.pixelSize: 11
                                color: Theme.textColor
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Label {
                                text: "$" + (modelData.value || 0).toLocaleString(Qt.locale(), 'f', 2)
                                font.bold: true
                                font.pixelSize: 11
                                color: Theme.textColor
                            }

                            Label {
                                property double totalCalc: {
                                    if (root.totalReference > 0) return root.totalReference
                                    var sum = 0
                                    for (var k = 0; k < root.slices.length; k++) sum += Math.max(0, root.slices[k].value || 0)
                                    return sum > 0 ? sum : 1.0
                                }
                                text: "(" + ((Math.max(0, modelData.value || 0) / totalCalc) * 100).toFixed(1) + "%)"
                                font.pixelSize: 10
                                color: Theme.subtextColor
                            }
                        }
                    }
                }
            }
        }
    }
}
