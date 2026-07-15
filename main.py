"""
main.py — Punto de entrada de la aplicación de Liquidación de Sueldos.
Interfaz nativa del sistema operativo, sin estilos custom.
"""

import sys
from PyQt6.QtWidgets import QApplication

from database import DatabaseManager
from ui import MainWindow


def main():
    app = QApplication(sys.argv)

    # Inicializar base de datos (se crea si no existe, con seed)
    db = DatabaseManager()

    # Crear y mostrar ventana principal
    window = MainWindow(db)
    window.show()

    code = app.exec()
    db.cerrar()
    sys.exit(code)


if __name__ == "__main__":
    main()
