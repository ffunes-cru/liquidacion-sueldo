"""
main.py — Punto de entrada de la aplicación de Liquidación de Sueldos.
Interfaz nativa del sistema operativo, sin estilos custom.
"""

import logging
import sys
from PyQt6.QtWidgets import QApplication

from database import DatabaseManager
from ui import MainWindow

# Configurar logging global
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s [%(levelname)s] %(name)s (%(filename)s:%(lineno)d): %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("app_debug.log", mode="a", encoding="utf-8")
    ]
)
logger = logging.getLogger("main")


def main():
    logger.info("================ INICIANDO APLICACIÓN LIQUIDACIÓN DE SUELDOS ================")
    app = QApplication(sys.argv)

    # Inicializar base de datos con bloqueo exclusivo por instancia
    try:
        logger.debug("Inicializando conexión y esquema de base de datos...")
        db = DatabaseManager()
        logger.info(f"Base de datos cargada exitosamente: {db.db_path}")

        # Configurar nivel de log dinámicamente según configuración 'modo_debug'
        modo_debug = db.obtener_config("modo_debug", "true").lower() == "true"
        level = logging.DEBUG if modo_debug else logging.INFO
        logging.getLogger().setLevel(level)
        logger.info(f"Nivel de traza inicializado. Modo Debug: {modo_debug} (Nivel activo: {logging.getLevelName(level)})")
    except Exception as e:
        logger.critical(f"Error crítico al abrir base de datos: {e}", exc_info=True)
        from PyQt6.QtWidgets import QMessageBox
        QMessageBox.critical(
            None,
            "Base de Datos Bloqueada",
            f"No se pudo iniciar la aplicación:\n\n{e}"
        )
        sys.exit(1)

    # Crear y mostrar ventana principal
    logger.debug("Inicializando ventana principal MainWindow...")
    window = MainWindow(db)
    window.show()
    logger.info("Ventana principal desplegada correctamente en pantalla.")

    code = app.exec()
    logger.info("Cerrando aplicación y liberando recursos de base de datos...")
    db.cerrar()
    logger.info("Aplicación finalizada con código de salida: %d", code)
    sys.exit(code)


if __name__ == "__main__":
    main()
