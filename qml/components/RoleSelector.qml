import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LiquidacionSueldos 1.0

RowLayout {
    spacing: 10

    Label {
        text: "Modo de Vista:"
        font.pixelSize: 13
        color: Theme.textColor
    }

    StyledComboBox {
        id: roleCombo
        model: ["Administrador", "Usuario Operativo"]
        currentIndex: AppController.currentRole === "admin" ? 0 : 1

        onActivated: {
            AppController.currentRole = (currentIndex === 0) ? "admin" : "user"
        }
    }
}
