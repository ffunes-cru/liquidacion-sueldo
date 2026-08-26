import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0
import "../components"

AppDialog {
    id: root

    title: "Cierre Inmutable del Período"
    dialogWidth: 540
    dialogHeight: -1
    standardButtons: Dialog.NoButton

    property int anio: AppController.selectedYear
    property int mes: AppController.selectedMonth
    property string monthName: {
        var names = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                     "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
        return (mes >= 1 && mes <= 12) ? names[mes - 1] : ""
    }

    onAboutToShow: {
        anio = AppController.selectedYear
        mes = AppController.selectedMonth

        // Set defaults from controller
        q1Field.selectedDateString = AppController.fechaCierreQ1
        q2Field.selectedDateString = AppController.fechaCierreQ2
        mesField.selectedDateString = AppController.fechaCierreMes
        pagoField.selectedDateString = AppController.fechaPago
    }

    contentItem: ColumnLayout {
        spacing: 16

        // Header Description Banner
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: bannerLayout.implicitHeight + 20
            radius: 8
            color: Theme.isDark ? Qt.rgba(245/255, 158/255, 11/255, 0.15) : Qt.rgba(245/255, 158/255, 11/255, 0.1)
            border.color: Qt.rgba(245/255, 158/255, 11/255, 0.4)
            border.width: 1

            RowLayout {
                id: bannerLayout
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Label {
                    text: "🔒"
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignTop
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: "Cierre del Período: " + root.monthName + " " + root.anio
                        font.bold: true
                        font.pixelSize: 14
                        color: Theme.textColor
                    }

                    Label {
                        text: "Al cerrar el mes se congelarán todos los valores de variables de empleados (jornales y mensuales), categorías y datos de cálculo en un snapshot inmutable. La configuración pasará a modo solo lectura."
                        font.pixelSize: 12
                        color: Theme.subtextColor
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Form Fields Section
        SectionPanel {
            Layout.fillWidth: true
            title: "Fechas Oficiales de Cierre y Pago"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        text: "Fecha Cierre 1ra Quincena (Q1):"
                        color: Theme.textColor
                        font.pixelSize: 13
                        Layout.preferredWidth: 210
                    }

                    StyledDatePicker {
                        id: q1Field
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        text: "Fecha Cierre 2da Quincena (Q2):"
                        color: Theme.textColor
                        font.pixelSize: 13
                        Layout.preferredWidth: 210
                    }

                    StyledDatePicker {
                        id: q2Field
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        text: "Fecha Cierre Mes Completo:"
                        color: Theme.textColor
                        font.pixelSize: 13
                        Layout.preferredWidth: 210
                    }

                    StyledDatePicker {
                        id: mesField
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        text: "Fecha de Pago de Haberes:"
                        color: Theme.textColor
                        font.pixelSize: 13
                        Layout.preferredWidth: 210
                    }

                    StyledDatePicker {
                        id: pagoField
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Layout.topMargin: 8

            Item { Layout.fillWidth: true }

            StyledButton {
                text: "Cancelar"
                variant: "secondary"
                onClicked: root.close()
            }

            StyledButton {
                text: "🔒 Confirmar y Cerrar Mes"
                variant: "danger"
                onClicked: {
                    var ok = AppController.closeMonth(
                        root.anio,
                        root.mes,
                        mesField.selectedDateString,
                        q1Field.selectedDateString,
                        q2Field.selectedDateString,
                        pagoField.selectedDateString
                    )
                    if (ok) {
                        root.close()
                    }
                }
            }
        }
    }
}
