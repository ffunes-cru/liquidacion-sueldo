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

    # Inicializar base de datos con bloqueo exclusivo por instancia
    try:
        db = DatabaseManager()
    except Exception as e:
        from PyQt6.QtWidgets import QMessageBox
        QMessageBox.critical(
            None,
            "Base de Datos Bloqueada",
            f"No se pudo iniciar la aplicación:\n\n{e}"
        )
        sys.exit(1)

    # Crear y mostrar ventana principal
    window = MainWindow(db)
    window.show()

    code = app.exec()
    db.cerrar()
    sys.exit(code)


if __name__ == "__main__":
    main()
