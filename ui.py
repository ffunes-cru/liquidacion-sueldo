"""
ui.py — Interfaz gráfica PyQt6 nativa para la aplicación de Liquidación de Sueldos.
Cuatro pestañas principales: Empleados, Categorías Jornal, Estructura de Recibo, Estructura de Gráfico, Vista Previa.
Menú para importar/exportar la base de datos (SQLite, Excel, CSV).
"""

import json
import os
import shutil

from PyQt6.QtCore import Qt, QSize, QDate, QThread, pyqtSignal
from PyQt6.QtGui import QAction, QFont, QColor, QActionGroup
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QFormLayout,
    QTabWidget, QTableWidget, QTableWidgetItem, QTreeWidget, QTreeWidgetItem,
    QComboBox, QPushButton, QLineEdit, QTextEdit, QLabel, QSplitter,
    QListWidget, QListWidgetItem, QMessageBox, QFileDialog, QHeaderView,
    QFrame, QGroupBox, QAbstractItemView, QDoubleSpinBox, QSpinBox, QRadioButton, QButtonGroup,
    QStackedWidget, QScrollArea, QDialog, QToolButton, QDateEdit, QCheckBox
)

from database import DatabaseManager
from motor import MotorLiquidacion
from gemini_assistant import GeminiAssistantClient

# Importar canvas de Matplotlib
from matplotlib.figure import Figure
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas

# Importar exportadores
import exporters


# ======================================================================
# Helpers de formato
# ======================================================================
class VariableAssistantDialog(QDialog):
    def __init__(self, parent, sys_vars, glob_vars, emp_vars, esq_vars, target_line_edit):
        super().__init__(parent)
        self.target_line_edit = target_line_edit
        self.setWindowTitle("Asistente de Variables")
        self.setModal(True)
        self.resize(420, 500)
        
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("<b>Selecciona una variable para insertar:</b>"))
        
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("Buscar variable (ej: smvm)...")
        self.search_input.textChanged.connect(self._filtrar_lista)
        layout.addWidget(self.search_input)
        
        self.list_widget = QListWidget()
        self.list_widget.itemDoubleClicked.connect(self._insertar_variable)
        layout.addWidget(self.list_widget)
        
        self.items_data = []
        
        # 1. Del Sistema
        for name, desc in sys_vars.items():
            self.items_data.append(("⚙️", name, f"{name} ({desc})"))
            
        # 2. NUEVO: Variables Globales 🌐
        for name, desc in glob_vars.items():
            self.items_data.append(("🌐", name, f"{name} ({desc})"))
            
        # 3. Dinámicas de los JSON de Empleados
        for v in emp_vars:
            self.items_data.append(("👤", v, v))

        # 3b. Funciones / Prefijos de Agregación por Quincena y Mes/Semestre
        q_funcs = [
            ("Q_sum_<variable>", "Suma el valor de <variable> en TODAS las quincenas. Ej: Q_sum_basico, Q_sum_bruto"),
            ("Q_avg_<variable>", "Promedio de <variable> en todas las quincenas. Ej: Q_avg_horas_extra"),
            ("Q_max_<variable>", "Máximo de <variable> entre quincenas. Ej: Q_max_bruto"),
            ("Q_min_<variable>", "Mínimo de <variable> entre quincenas. Ej: Q_min_basico"),
            ("cant_q()", "Cantidad de quincenas cargadas"),
            ("sumar_q('variable')", "Función: suma de 'variable' en todas las Q. Ej: sumar_q('basico')"),
            ("promedio_q('variable')", "Función: promedio de 'variable' en todas las Q"),
            ("max_q('variable')", "Función: máximo de 'variable' en todas las Q"),
            ("min_q('variable')", "Función: mínimo de 'variable' en todas las Q"),
            ("sumatoria_mes('variable', mes, anio)", "V2: Suma la variable en todos los recibos de ese mes/año (Q1+Q2)"),
            ("maximo_semestre('variable', semestre, anio)", "V2: Mayor suma mensual de la variable en el semestre (1 o 2)"),
            ("promedio_ultimos_n_meses('variable', n, mes, anio)", "V2: Promedio de la variable en los últimos N meses"),
            ("dias_trabajados_semestre(semestre, anio)", "V2: Días trabajados del semestre en base a fecha_ingreso"),
        ]
        for name, desc in q_funcs:
            self.items_data.append(("📊", name, f"{name} — {desc}"))

        # 4. Otros conceptos de la tabla actual
        for v in esq_vars:
            self.items_data.append(("📄", v, v))
            
        self._cargar_lista()
        
        # Botones de acción
        btn_layout = QHBoxLayout()
        btn_cancelar = QPushButton("Cancelar")
        btn_cancelar.clicked.connect(self.reject)
        
        btn_insertar = QPushButton("Insertar")
        btn_insertar.clicked.connect(self._insertar_variable)
        btn_insertar.setDefault(True)
        
        btn_layout.addStretch()
        btn_layout.addWidget(btn_cancelar)
        btn_layout.addWidget(btn_insertar)
        layout.addLayout(btn_layout)
        
    def _cargar_lista(self, filtro=""):
        self.list_widget.clear()
        filtro = filtro.lower()
        for tipo, real_name, display_text in self.items_data:
            if filtro in real_name.lower() or filtro in tipo.lower() or filtro in display_text.lower():
                item = QListWidgetItem(f"{display_text}  —  [{tipo}]")
                item.setData(Qt.ItemDataRole.UserRole, real_name)
                self.list_widget.addItem(item)
                
    def _filtrar_lista(self, text):
        self._cargar_lista(text)
        
    def _insertar_variable(self):
        selected = self.list_widget.currentItem()
        if selected:
            var_name = selected.data(Qt.ItemDataRole.UserRole)
            self.target_line_edit.insert(var_name)
            self.target_line_edit.setFocus()
            self.accept()


class MasivoPdfExportDialog(QDialog):
    def __init__(self, parent, lista_quincenas):
        super().__init__(parent)
        self.setWindowTitle("Exportación Masiva a PDF")
        self.setModal(True)
        self.resize(380, 220)
        
        layout = QVBoxLayout(self)
        form = QFormLayout()
        
        self.combo_quincena = QComboBox()
        self.combo_quincena.addItem("Todas las Quincenas y Mensuales (Todo)", "TODO")
        for q in lista_quincenas:
            self.combo_quincena.addItem(f"Solo Quincena {q}", q)
        self.combo_quincena.addItem("Solo Mensuales", "MENSUALES")
        form.addRow("Selección de Período:", self.combo_quincena)
        
        self.inp_fecha = QDateEdit()
        self.inp_fecha.setCalendarPopup(True)
        self.inp_fecha.setDisplayFormat("yyyy-MM-dd")
        self.inp_fecha.setDate(QDate.currentDate())
        form.addRow("Fecha de Cálculo:", self.inp_fecha)
        
        layout.addLayout(form)
        
        layout.addWidget(QLabel("<i>Se generará un PDF por cada recibo calculado de los empleados.</i>"))
        
        btn_layout = QHBoxLayout()
        btn_cancel = QPushButton("Cancelar")
        btn_cancel.clicked.connect(self.reject)
        
        btn_export = QPushButton("Seleccionar Carpeta y Exportar")
        btn_export.setDefault(True)
        btn_export.clicked.connect(self.accept)
        
        btn_layout.addStretch()
        btn_layout.addWidget(btn_cancel)
        btn_layout.addWidget(btn_export)
        
        layout.addLayout(btn_layout)


def _formato_moneda(valor) -> str:
    if valor is None:
        return ""
    try:
        v = float(valor)
        signo = "-" if v < 0 else ""
        v = abs(v)
        entero = int(v)
        decimal = round(v - entero, 2)
        entero_str = f"{entero:,}".replace(",", ".")
        decimal_str = f"{decimal:.2f}"[2:]
        return f"{signo}$ {entero_str},{decimal_str}"
    except (ValueError, TypeError):
        return str(valor)


def _formato_porcentaje(valor) -> str:
    if valor is None:
        return ""
    try:
        v = float(valor)
        if abs(v) < 1:
            return f"{v * 100:.2f}%"
        return f"{v:.2f}"
    except (ValueError, TypeError):
        return str(valor)


# ======================================================================
# Worker Thread para Gemini API
# ======================================================================
class GeminiWorkerThread(QThread):
    finished_signal = pyqtSignal(str, bool)
    error_signal = pyqtSignal(str)

    def __init__(self, api_key: str, db: DatabaseManager, prompt: str, historial: list):
        super().__init__()
        self.api_key = api_key
        self.db = db
        self.prompt = prompt
        self.historial = historial

    def run(self):
        try:
            client = GeminiAssistantClient(self.api_key, self.db)
            respuesta, db_modificada = client.enviar_mensaje(self.prompt, self.historial)
            self.finished_signal.emit(respuesta, db_modificada)
        except Exception as e:
            self.error_signal.emit(str(e))


# ======================================================================
# Diálogo de Configuración del Sistema
# ======================================================================
class ConfiguracionDialog(QDialog):
    def __init__(self, parent, db: DatabaseManager):
        super().__init__(parent)
        self.db = db
        self.parent_win = parent
        self.setWindowTitle("Configuración del Sistema")
        self.setMinimumWidth(500)
        self._init_ui()

    def _init_ui(self):
        layout = QVBoxLayout(self)

        group = QGroupBox("Opciones Generales de Operación")
        form = QFormLayout(group)

        # Modo de Vista
        self.combo_modo = QComboBox()
        self.combo_modo.addItems(["Administrador", "Usuario"])
        current_modo = getattr(self.parent_win, "modo_actual", "Administrador")
        idx_m = self.combo_modo.findText(current_modo)
        if idx_m >= 0:
            self.combo_modo.setCurrentIndex(idx_m)
        form.addRow("Modo de Interfaz:", self.combo_modo)

        # Modelo Inmutable por Esquema
        self.chk_inmutable = QCheckBox("Modelo de variables inmutable por Esquema de Cálculo")
        inmutable_val = self.db.obtener_config("modelo_empleado_inmutable", "false").lower() == "true"
        self.chk_inmutable.setChecked(inmutable_val)
        form.addRow(self.chk_inmutable)

        lbl_desc = QLabel(
            "<i>Al activar el modelo inmutable, al crear o modificar variables en un empleado, "
            "esas variables se replicarán automáticamente en todos los demás empleados asignados al mismo Esquema de Cálculo "
            "con su valor predeterminado inicial.</i>"
        )
        lbl_desc.setWordWrap(True)
        lbl_desc.setStyleSheet("color: #9CA3AF; font-size: 11px; margin-top: 5px;")
        form.addRow(lbl_desc)

        # Activar Pestaña Asistente IA
        self.chk_habilitar_ia = QCheckBox("Habilitar pestaña Asistente IA (Google Gemini)")
        ia_val = self.db.obtener_config("habilitar_asistente_ia", "false").lower() == "true"
        self.chk_habilitar_ia.setChecked(ia_val)
        form.addRow(self.chk_habilitar_ia)

        # Clave API de Gemini
        self.inp_gemini_key = QLineEdit()
        self.inp_gemini_key.setEchoMode(QLineEdit.EchoMode.Password)
        self.inp_gemini_key.setPlaceholderText("AIzaSy...")
        current_key = self.db.obtener_config("gemini_api_key", "")
        self.inp_gemini_key.setText(current_key)
        form.addRow("Clave API Google Gemini:", self.inp_gemini_key)

        layout.addWidget(group)

        btn_box = QHBoxLayout()
        btn_box.addStretch()

        btn_guardar = QPushButton("Guardar Configuración")
        btn_guardar.clicked.connect(self._guardar)
        btn_box.addWidget(btn_guardar)

        btn_cancelar = QPushButton("Cancelar")
        btn_cancelar.clicked.connect(self.reject)
        btn_box.addWidget(btn_cancelar)

        layout.addLayout(btn_box)

    def _guardar(self):
        nuevo_modo = self.combo_modo.currentText()
        if hasattr(self.parent_win, "_cambiar_modo"):
            self.parent_win._cambiar_modo(nuevo_modo)

        inmutable_str = "true" if self.chk_inmutable.isChecked() else "false"
        ia_str = "true" if self.chk_habilitar_ia.isChecked() else "false"
        self.db.guardar_config("modelo_empleado_inmutable", inmutable_str)
        self.db.guardar_config("habilitar_asistente_ia", ia_str)
        self.db.guardar_config("gemini_api_key", self.inp_gemini_key.text().strip())

        if hasattr(self.parent_win, "_actualizar_modo_vista"):
            self.parent_win._actualizar_modo_vista()

        QMessageBox.information(self, "Configuración", "Configuración del sistema guardada correctamente.")
        self.accept()


# ======================================================================
# Ventana Principal
# ======================================================================
class MainWindow(QMainWindow):
    def __init__(self, db: DatabaseManager):
        super().__init__()
        self.db = db
        self.motor = MotorLiquidacion(db)
        self.ultimo_resultado = None

        self.setWindowTitle("Liquidación de Sueldos y Costo Laboral — Argentina")
        self.setMinimumSize(QSize(1250, 780))
        self.resize(1380, 840)

        self._init_menu()
        self._init_ui()
        self.statusBar().showMessage("Listo  —  Base de datos: " + self.db.ruta_db())

    # ------------------------------------------------------------------
    # Menú
    # ------------------------------------------------------------------
    def _init_menu(self):
        menubar = self.menuBar()

        # Menú Archivo
        archivo = menubar.addMenu("&Archivo")

        # Acciones SQLite nativas
        act_export_db = QAction("Exportar Base de Datos (.db)…", self)
        act_export_db.triggered.connect(self._exportar_db)
        archivo.addAction(act_export_db)

        act_import_db = QAction("Importar Base de Datos (.db)…", self)
        act_import_db.triggered.connect(self._importar_db)
        archivo.addAction(act_import_db)

        archivo.addSeparator()

        # Acciones Excel/CSV de la Base de Datos
        act_export_xlsx = QAction("Exportar Base de Datos a Excel (.xlsx)…", self)
        act_export_xlsx.triggered.connect(self._exportar_db_xlsx)
        archivo.addAction(act_export_xlsx)

        act_import_xlsx = QAction("Importar Base de Datos desde Excel (.xlsx)…", self)
        act_import_xlsx.triggered.connect(self._importar_db_xlsx)
        archivo.addAction(act_import_xlsx)

        archivo.addSeparator()

        act_export_csv = QAction("Exportar Base de Datos a Carpeta con CSVs…", self)
        act_export_csv.triggered.connect(self._exportar_db_csv)
        archivo.addAction(act_export_csv)

        act_import_csv = QAction("Importar Base de Datos desde Carpeta con CSVs…", self)
        act_import_csv.triggered.connect(self._importar_db_csv)
        archivo.addAction(act_import_csv)

        archivo.addSeparator()

        act_salir = QAction("&Salir", self)
        act_salir.setShortcut("Ctrl+Q")
        act_salir.triggered.connect(self.close)
        archivo.addAction(act_salir)

        # --- Menú Modo ---
        menu_modo = menubar.addMenu("&Modo")
        
        # Grupo exclusivo para que funcionen como Radio Buttons
        self.grupo_modo = QActionGroup(self)
        self.grupo_modo.setExclusive(True)

        self.act_modo_admin = QAction("Administrador", self, checkable=True)
        self.act_modo_admin.setChecked(True) # Administrador por defecto
        self.act_modo_admin.triggered.connect(lambda: self._cambiar_modo("Administrador"))
        
        self.act_modo_usuario = QAction("Usuario", self, checkable=True)
        self.act_modo_usuario.triggered.connect(lambda: self._cambiar_modo("Usuario"))

        self.grupo_modo.addAction(self.act_modo_admin)
        self.grupo_modo.addAction(self.act_modo_usuario)
        
        menu_modo.addAction(self.act_modo_admin)
        menu_modo.addAction(self.act_modo_usuario)
        menu_modo.addSeparator()
        
        act_config = QAction("⚙ Configuración del Sistema…", self)
        act_config.triggered.connect(self._abrir_configuracion)
        menu_modo.addAction(act_config)

        # Inicializamos la variable de estado
        self.modo_actual = "Administrador"

        # --- Botón Nuevo Mes incrustado en la barra de menú ---
        self.btn_nuevo_mes = QPushButton("⚠ Nuevo Mes")
        self.btn_nuevo_mes.setStyleSheet("""
            QPushButton {
                background-color: #EF4444; 
                color: white; 
                font-weight: bold; 
                padding: 4px 10px; /* Ajustado un poco para que encaje bien en el menú */
                border-radius: 4px;
                margin-right: 5px; /* Un pequeño margen a la derecha */
                margin-top: 2px;
                margin-bottom: 2px;
            }
            QPushButton:hover {
                background-color: #DC2626;
            }
            QPushButton:pressed {
                background-color: #B91C1C;
            }
        """)
        self.btn_nuevo_mes.setToolTip("Reinicializar variables de empleados para un nuevo mes (Genera backup automático)")
        self.btn_nuevo_mes.clicked.connect(self._nuevo_mes_accion_riesgo)
        
        # Insertar el widget (botón) en la esquina superior derecha del QMenuBar
        menubar.setCornerWidget(self.btn_nuevo_mes, Qt.Corner.TopRightCorner)

    def _abrir_configuracion(self):
        dlg = ConfiguracionDialog(self, self.db)
        dlg.exec()

    # ------------------------------------------------------------------
    # UI principal
    # ------------------------------------------------------------------
    def _init_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)

        self.tabs = QTabWidget()
        root.addWidget(self.tabs)

        # 1. Empleados
        self.tab_empleados = QWidget()
        self.tabs.addTab(self.tab_empleados, "Empleados")
        self._build_tab_empleados()

        # 1b. Empresa (Singleton)
        self.tab_empresa = QWidget()
        self.tabs.addTab(self.tab_empresa, "Empresa")
        self._build_tab_empresa()

        # 2. Categorías Jornaleras
        self.tab_categorias = QWidget()
        self.tabs.addTab(self.tab_categorias, "Categorías Jornal")
        self._build_tab_categorias()

        # 2a. Esquemas de Cálculo (CRUD)
        self.tab_esquemas = QWidget()
        self.tabs.addTab(self.tab_esquemas, "Esquemas de Cálculo")
        self._build_tab_esquemas()

        # 2b. Secciones (CRUD)
        self.tab_secciones = QWidget()
        self.tabs.addTab(self.tab_secciones, "Secciones")
        self._build_tab_secciones()

        # 2c. Campos Globales
        self.tab_globales = QWidget()
        self.tabs.addTab(self.tab_globales, "Campos Globales")
        self._build_tab_globales()

        # 3. Estructura de Recibo
        self.tab_estructura = QWidget()
        self.tabs.addTab(self.tab_estructura, "Estructura del Recibo")
        self._build_tab_estructura()

        # 4. Estructura de Gráficos Custom
        self.tab_graficos_config = QWidget()
        self.tabs.addTab(self.tab_graficos_config, "Estructura del Gráfico")
        self._build_tab_grafico_config()

        # 5. Vista Previa
        self.tab_preview = QWidget()
        self.tabs.addTab(self.tab_preview, "Vista Previa")
        self._build_tab_preview()

        # 6. Historial de Recibos (NUEVO)
        self.tab_historial = QWidget()
        self.tabs.addTab(self.tab_historial, "Historial de Recibos")
        self._build_tab_historial()

        # 7. Consola/Intérprete de Fórmulas (NUEVO)
        self.tab_consola = QWidget()
        self.tabs.addTab(self.tab_consola, "Consola de Fórmulas")
        self._build_tab_consola()

        # 8. Asistente IA (Google Gemini)
        self.tab_asistente_ia = QWidget()
        self.tabs.addTab(self.tab_asistente_ia, "🤖 Asistente IA")
        self._build_tab_asistente_ia()

        # Guardamos la lista de todas las pestañas para poder reconstruirlas dinámicamente
        self.all_tabs = [
            (self.tab_empleados, "Empleados"),
            (self.tab_empresa, "Empresa"),
            (self.tab_categorias, "Categorías Jornal"),
            (self.tab_esquemas, "Esquemas de Cálculo"),
            (self.tab_secciones, "Secciones"),
            (self.tab_globales, "Campos Globales"),
            (self.tab_estructura, "Estructura del Recibo"),
            (self.tab_graficos_config, "Estructura del Gráfico"),
            (self.tab_preview, "Vista Previa"),
            (self.tab_historial, "Historial de Recibos"),
            (self.tab_consola, "Consola de Fórmulas"),
            (self.tab_asistente_ia, "🤖 Asistente IA")
        ]

        # Aplicar visibilidad inicial de pestañas según la configuración
        self._actualizar_modo_vista()

    # ==================================================================
    # PESTAÑA 1 — EMPLEADOS
    # ==================================================================
    def _build_tab_empleados(self):
        layout = QHBoxLayout(self.tab_empleados)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        layout.addWidget(splitter)

        # --- Panel Izquierdo: Lista ---
        left = QWidget()
        left_layout = QVBoxLayout(left)
        left_layout.setContentsMargins(0, 0, 0, 0)

        left_layout.addWidget(QLabel("<b>Empleados</b>"))

        self.lista_empleados = QListWidget()
        self.lista_empleados.currentRowChanged.connect(self._on_empleado_seleccionado)
        left_layout.addWidget(self.lista_empleados)

        btn_bar = QHBoxLayout()
        self.btn_nuevo = QPushButton("Nuevo")
        self.btn_nuevo.clicked.connect(self._nuevo_empleado)
        btn_bar.addWidget(self.btn_nuevo)

        self.btn_duplicar = QPushButton("Duplicar")
        self.btn_duplicar.clicked.connect(self._duplicar_empleado)
        btn_bar.addWidget(self.btn_duplicar)

        self.btn_eliminar = QPushButton("Eliminar")
        self.btn_eliminar.clicked.connect(self._eliminar_empleado)
        btn_bar.addWidget(self.btn_eliminar)
        left_layout.addLayout(btn_bar)

        splitter.addWidget(left)

        # --- Panel Derecho: Formulario ---
        right = QWidget()
        right_layout = QVBoxLayout(right)
        right_layout.setContentsMargins(0, 0, 0, 0)

        group_datos = QGroupBox("Datos del Empleado")
        form = QFormLayout()

        self.inp_legajo = QLineEdit()
        self.inp_legajo.setPlaceholderText("Ej: 0001")
        form.addRow("Legajo:", self.inp_legajo)

        self.inp_nombre = QLineEdit()
        self.inp_nombre.setPlaceholderText("Nombre completo")
        form.addRow("Nombre:", self.inp_nombre)

        self.inp_cuil = QLineEdit()
        self.inp_cuil.setPlaceholderText("Ej: 20-12345678-9")
        form.addRow("CUIL:", self.inp_cuil)

        self.inp_tipo = QComboBox()
        self.inp_tipo.addItems(["mensual", "jornal"])
        self.inp_tipo.currentIndexChanged.connect(self._on_tipo_liquidacion_cambiado)
        form.addRow("Tipo Liquidación:", self.inp_tipo)

        self.inp_esquema = QComboBox()
        form.addRow("Esquema de Cálculo:", self.inp_esquema)

        self.inp_categoria_jornal = QComboBox()
        form.addRow("Categoría Jornalera:", self.inp_categoria_jornal)

        self.inp_fecha_ingreso = QDateEdit()
        self.inp_fecha_ingreso.setCalendarPopup(True)
        self.inp_fecha_ingreso.setDisplayFormat("yyyy-MM-dd")
        form.addRow("Fecha de Ingreso:", self.inp_fecha_ingreso)

        group_datos.setLayout(form)
        right_layout.addWidget(group_datos)

        # Variables JSON
        # --- Variables de Cálculo (Dinámicas) ---
        group_vars = QGroupBox("Variables de Cálculo")
        vars_layout = QVBoxLayout()

        # Tab widget para agrupar quincenas
        self.tab_widget_vars = QTabWidget()
        self.tab_widget_vars.setMinimumHeight(200)
        vars_layout.addWidget(self.tab_widget_vars)

        # Diccionario para trackear quincenas y sus filas
        self.quincena_tabs = {}

        # Botonera inferior para añadir variables y quincenas
        btn_vars_bar = QHBoxLayout()
        self.btn_add_var = QPushButton("+ Agregar Variable")
        self.btn_add_var.clicked.connect(self._on_agregar_variable_click)
        btn_vars_bar.addWidget(self.btn_add_var)

        self.btn_add_quincena = QPushButton("+ Agregar Quincena")
        self.btn_add_quincena.clicked.connect(self._on_agregar_quincena_click)
        btn_vars_bar.addWidget(self.btn_add_quincena)

        self.btn_del_quincena = QPushButton("− Eliminar Quincena")
        self.btn_del_quincena.clicked.connect(self._on_eliminar_quincena_click)
        btn_vars_bar.addWidget(self.btn_del_quincena)

        btn_vars_bar.addStretch()
        vars_layout.addLayout(btn_vars_bar)

        group_vars.setLayout(vars_layout)
        right_layout.addWidget(group_vars)

        btn_guardar = QPushButton("Guardar Empleado")
        btn_guardar.clicked.connect(self._guardar_empleado)
        right_layout.addWidget(btn_guardar)

        splitter.addWidget(right)
        splitter.setSizes([280, 700])

        self._cargar_lista_empleados()
        self._cargar_combos_empleado()

    def _cargar_combos_empleado(self):
        # Cargar Esquemas
        self.inp_esquema.clear()
        for esq in self.db.listar_esquemas():
            self.inp_esquema.addItem(esq["nombre"], esq["codigo"])

        # Cargar Categorías Jornaleras
        self.inp_categoria_jornal.clear()
        self.inp_categoria_jornal.addItem("Ninguna", None)
        for cat in self.db.listar_categorias_jornal():
            self.inp_categoria_jornal.addItem(f"{cat['nombre']} (${cat['valor_hora']}/h)", cat["id"])

    def _on_tipo_liquidacion_cambiado(self):
        es_jornal = self.inp_tipo.currentText() == "jornal"
        self.inp_categoria_jornal.setEnabled(es_jornal)
        if es_jornal:
            # Seleccionar esquema JORNAL automáticamente si existe
            idx = self.inp_esquema.findData("JORNAL")
            if idx >= 0:
                self.inp_esquema.setCurrentIndex(idx)
        else:
            # Seleccionar esquema MENSUAL
            self.inp_categoria_jornal.setCurrentIndex(0)  # Ninguno
            idx = self.inp_esquema.findData("MENSUAL")
            if idx >= 0:
                self.inp_esquema.setCurrentIndex(idx)
                
        # Reconstruir dinámicamente el layout de variables
        if hasattr(self, "quincena_tabs") and self.quincena_tabs:
            current_json = self._get_variables_json()
            self._set_variables_json(current_json)

    def _cargar_lista_empleados(self):
        current_row = self.lista_empleados.currentRow()
        self.lista_empleados.blockSignals(True)
        self.lista_empleados.clear()
        self._empleados_data = self.db.listar_empleados()
        for emp in self._empleados_data:
            item = QListWidgetItem(f"[{emp['legajo']}]  {emp['nombre_completo']}")
            item.setData(Qt.ItemDataRole.UserRole, emp["id"])
            self.lista_empleados.addItem(item)
        if self._empleados_data:
            target = current_row if (0 <= current_row < len(self._empleados_data)) else 0
            self.lista_empleados.setCurrentRow(target)
        self.lista_empleados.blockSignals(False)

    def _on_empleado_seleccionado(self, row: int):
        if row < 0 or row >= len(self._empleados_data):
            return
        emp = self._empleados_data[row]
        self.inp_legajo.setText(emp["legajo"] or "")
        self.inp_nombre.setText(emp["nombre_completo"] or "")
        self.inp_cuil.setText(emp.get("cuil") or "")
        
        idx_tipo = self.inp_tipo.findText(emp["tipo_liquidacion"])
        if idx_tipo >= 0:
            self.inp_tipo.setCurrentIndex(idx_tipo)

        idx_esq = self.inp_esquema.findData(emp["esquema_codigo"])
        if idx_esq >= 0:
            self.inp_esquema.setCurrentIndex(idx_esq)

        idx_cat = self.inp_categoria_jornal.findData(emp["categoria_jornal_id"])
        if idx_cat >= 0:
            self.inp_categoria_jornal.setCurrentIndex(idx_cat)

        # Cargar Fecha de Ingreso
        f_ing_str = emp.get("fecha_ingreso") or "2020-01-01"
        qdate = QDate.fromString(f_ing_str, "yyyy-MM-dd")
        self.inp_fecha_ingreso.setDate(qdate if qdate.isValid() else QDate(2020, 1, 1))

        self._set_variables_json(emp["variables_calculo"] or "{}")

    def _duplicar_empleado(self):
        """Toma el empleado seleccionado actualmente, copia sus datos y crea uno nuevo."""
        row = self.lista_empleados.currentRow()
        if row < 0 or row >= len(self._empleados_data):
            return
        emp = self._empleados_data[row]
        
        nuevo_legajo = f"{emp['legajo']}_copia" if emp['legajo'] else "0000"
        nuevo_nombre = f"{emp['nombre_completo']} (Copia)"
        
        nuevo_id = self.db.guardar_empleado(
            None,
            nuevo_legajo,
            nuevo_nombre,
            emp["tipo_liquidacion"],
            emp["variables_calculo"],
            emp["esquema_codigo"],
            emp["categoria_jornal_id"],
            emp["fecha_ingreso"],
            emp.get("cuil", "")
        )
        
        self._cargar_lista_empleados()
        
        # Seleccionar el nuevo empleado duplicado en la lista
        for i in range(self.lista_empleados.count()):
            item = self.lista_empleados.item(i)
            if item and item.data(Qt.ItemDataRole.UserRole) == nuevo_id:
                self.lista_empleados.setCurrentRow(i)
                break
                
        if hasattr(self, "_cargar_combo_empleados"):
            self._cargar_combo_empleados()
            
        self.statusBar().showMessage(f"Empleado duplicado como '{nuevo_nombre}'.", 4000)

    def _guardar_empleado(self):
        row = self.lista_empleados.currentRow()
        emp_id = None
        if 0 <= row < len(self._empleados_data):
            emp_id = self._empleados_data[row]["id"]

        nombre = self.inp_nombre.text().strip()
        if not nombre:
            QMessageBox.warning(self, "Error", "El nombre es obligatorio.")
            return

        variables_txt = self._get_variables_json()

        esquema = self.inp_esquema.currentData()
        cat_id = self.inp_categoria_jornal.currentData()
        fecha_ing = self.inp_fecha_ingreso.date().toString("yyyy-MM-dd")
        cuil = self.inp_cuil.text().strip()

        self.db.guardar_empleado(
            emp_id, self.inp_legajo.text().strip(),
            nombre, self.inp_tipo.currentText(), variables_txt, esquema, cat_id, fecha_ing, cuil
        )

        # Si el modelo inmutable está activo, propagar variables al esquema
        inmutable = self.db.obtener_config("modelo_empleado_inmutable", "false").lower() == "true"
        if inmutable and esquema:
            try:
                d_vars = json.loads(variables_txt)
                self.db.propagar_variables_esquema(esquema, d_vars)
            except Exception:
                pass

        self.statusBar().showMessage("Empleado guardado correctamente.", 4000)
        old_row = row
        self._cargar_lista_empleados()
        if 0 <= old_row < self.lista_empleados.count():
            self.lista_empleados.setCurrentRow(old_row)
        self._cargar_combo_empleados()

    def _nuevo_empleado(self):
        variables_default = json.dumps({
            "antiguedad_anios": 0,
            "asistencia_perfecta": True,
            "horas_trabajadas": 150
        }, indent=2, ensure_ascii=False)
        self.db.guardar_empleado(None, "", "Nuevo Empleado", "mensual", variables_default, "MENSUAL", None, "2020-01-01")
        self._cargar_lista_empleados()
        self.lista_empleados.setCurrentRow(self.lista_empleados.count() - 1)
        self._cargar_combo_empleados()
        self.statusBar().showMessage("Nuevo empleado creado.", 4000)

    def _eliminar_empleado(self):
        row = self.lista_empleados.currentRow()
        if row < 0:
            return
        emp = self._empleados_data[row]
        resp = QMessageBox.question(
            self, "Confirmar",
            f"¿Eliminar al empleado \"{emp['nombre_completo']}\"?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if resp == QMessageBox.StandardButton.Yes:
            self.db.eliminar_empleado(emp["id"])
            self._cargar_lista_empleados()
            if hasattr(self, "_cargar_combo_empleados"):
                self._cargar_combo_empleados()
            self.statusBar().showMessage("Empleado eliminado.", 4000)

    # ------------------------------------------------------------------
    # Gestión de Variables de Cálculo con Pestañas/Quincenas
    # ------------------------------------------------------------------
    def _add_quincena_tab(self, name: str, variables: dict):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setMinimumHeight(180)
        
        scroll_content = QWidget()
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(scroll_content)
        
        self.tab_widget_vars.addTab(scroll, name)
        
        self.quincena_tabs[name] = {
            "scroll_area": scroll,
            "scroll_layout": scroll_layout,
            "rows": []
        }
        
        for k, v in variables.items():
            self._add_variable_row_to_tab(name, k, v)

    def _add_variable_row_to_tab(self, tab_name: str, key="", val=""):
        tab_info = self.quincena_tabs.get(tab_name)
        if not tab_info:
            return
            
        row_widget = QWidget()
        row_layout = QHBoxLayout(row_widget)
        row_layout.setContentsMargins(0, 2, 0, 2)

        inp_key = QLineEdit()
        inp_key.setPlaceholderText("Clave (ej: horas_trabajadas)")
        inp_key.setText(str(key))

        is_user = hasattr(self, "modo_actual") and self.modo_actual == "Usuario"
        
        if is_user:
            inp_key.setReadOnly(True)
            inp_key.setStyleSheet("background-color: #374151; color: #9CA3AF; border: 1px solid #4B5563; padding: 2px;")
            
            # Determinar control para el valor
            if isinstance(val, bool) or str(val).lower() in ("true", "false"):
                val_bool = val if isinstance(val, bool) else (str(val).lower() == "true")
                inp_val = QCheckBox()
                inp_val.setChecked(val_bool)
            elif isinstance(val, (int, float)) or (isinstance(val, str) and val.replace(".","",1).replace("-","",1).isdigit()):
                try:
                    val_float = float(val)
                except ValueError:
                    val_float = 0.0
                inp_val = QDoubleSpinBox()
                inp_val.setRange(-99999999.0, 99999999.0)
                inp_val.setDecimals(2)
                inp_val.setValue(val_float)
            else:
                inp_val = QLineEdit()
                inp_val.setText(str(val) if val is not None else "")
        else:
            inp_val = QLineEdit()
            if isinstance(val, bool):
                inp_val.setText("true" if val else "false")
            else:
                inp_val.setText(str(val) if val is not None else "")

        btn_del = QPushButton("−")
        btn_del.setFixedWidth(30)
        btn_del.setToolTip("Eliminar esta variable")
        btn_del.clicked.connect(lambda checked=False, t=tab_name, rw=row_widget: self._remove_variable_row_from_tab(t, rw))

        if is_user:
            btn_del.setVisible(False)

        row_layout.addWidget(inp_key, 2)
        row_layout.addWidget(inp_val, 3)
        row_layout.addWidget(btn_del, 0)

        tab_info["scroll_layout"].addWidget(row_widget)
        
        tab_info["rows"].append({
            "widget": row_widget,
            "key_input": inp_key,
            "val_input": inp_val
        })

    def _remove_variable_row_from_tab(self, tab_name: str, row_widget: QWidget):
        tab_info = self.quincena_tabs.get(tab_name)
        if not tab_info:
            return
        for item in tab_info["rows"]:
            if item["widget"] == row_widget:
                tab_info["rows"].remove(item)
                break
        tab_info["scroll_layout"].removeWidget(row_widget)
        row_widget.deleteLater()

    def _clear_quincena_tabs(self):
        self.tab_widget_vars.clear()
        self.quincena_tabs.clear()

    def _on_agregar_variable_click(self):
        idx = self.tab_widget_vars.currentIndex()
        if idx < 0:
            return
        tab_name = self.tab_widget_vars.tabText(idx)
        
        tab_info = self.quincena_tabs.get(tab_name)
        existing_keys = set()
        if tab_info:
            for item in tab_info["rows"]:
                k = item["key_input"].text().strip()
                if k:
                    existing_keys.add(k)
                    
        count = 1
        new_key = f"variable_{count}"
        while new_key in existing_keys:
            count += 1
            new_key = f"variable_{count}"

        self._add_variable_row_to_tab(tab_name, new_key, 0)

    def _on_agregar_quincena_click(self):
        q1_vars = self._get_tab_variables_dict("Q1")
        existing_qs = [name for name in self.quincena_tabs.keys() if name.startswith("Q")]
        
        q_nums = []
        for q in existing_qs:
            try:
                q_nums.append(int(q[1:]))
            except ValueError:
                pass
                
        next_num = max(q_nums) + 1 if q_nums else 2
        new_q_name = f"Q{next_num}"
        
        self._add_quincena_tab(new_q_name, q1_vars)
        
        idx = self.tab_widget_vars.count() - 1
        self.tab_widget_vars.setCurrentIndex(idx)

    def _on_eliminar_quincena_click(self):
        idx = self.tab_widget_vars.currentIndex()
        if idx < 0:
            return
        tab_name = self.tab_widget_vars.tabText(idx)
        
        if tab_name == "Q1":
            QMessageBox.warning(self, "Atención", "La quincena base Q1 no se puede eliminar.")
            return
            
        resp = QMessageBox.question(
            self, "Confirmar",
            f"¿Está seguro de que desea eliminar la quincena {tab_name}?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if resp == QMessageBox.StandardButton.Yes:
            self.tab_widget_vars.removeTab(idx)
            if tab_name in self.quincena_tabs:
                del self.quincena_tabs[tab_name]

    def _get_tab_variables_dict(self, tab_name: str) -> dict:
        tab_info = self.quincena_tabs.get(tab_name)
        if not tab_info:
            return {}
            
        data = {}
        for item in tab_info["rows"]:
            k = item["key_input"].text().strip()
            if not k:
                continue
                
            widget = item["val_input"]
            if isinstance(widget, QCheckBox):
                v = widget.isChecked()
            elif isinstance(widget, QDoubleSpinBox):
                val_float = widget.value()
                if val_float.is_integer():
                    v = int(val_float)
                else:
                    v = val_float
            else:
                # QLineEdit
                v_raw = widget.text().strip()
                v_lower = v_raw.lower()
                
                if v_lower == "true":
                    v = True
                elif v_lower == "false":
                    v = False
                elif v_raw == "":
                    v = None
                else:
                    try:
                        v = int(v_raw)
                    except ValueError:
                        try:
                            v = float(v_raw)
                        except ValueError:
                            v = v_raw
            data[k] = v
        return data

    def _get_variables_json(self) -> str:
        es_jornal = self.inp_tipo.currentText() == "jornal"
        if not es_jornal:
            tab_name = "Mensual"
            if tab_name not in self.quincena_tabs:
                if self.quincena_tabs:
                    tab_name = list(self.quincena_tabs.keys())[0]
                else:
                    return "{}"
            data = self._get_tab_variables_dict(tab_name)
            return json.dumps(data, ensure_ascii=False)
        else:
            quincenas_data = {}
            for tab_name in self.quincena_tabs.keys():
                if tab_name == "Mensual":
                    continue
                quincenas_data[tab_name] = self._get_tab_variables_dict(tab_name)
            return json.dumps({"quincenas": quincenas_data}, ensure_ascii=False)

    def _set_variables_json(self, json_str: str):
        self._clear_quincena_tabs()
        try:
            data = json.loads(json_str) if json_str else {}
        except Exception:
            data = {}
            
        es_jornal = self.inp_tipo.currentText() == "jornal"
        
        if es_jornal:
            self.tab_widget_vars.tabBar().show()
            self.btn_add_quincena.show()
            self.btn_del_quincena.show()
            
            if isinstance(data, dict) and "quincenas" in data:
                quincenas_dict = data["quincenas"]
            else:
                quincenas_dict = {"Q1": data if isinstance(data, dict) else {}}
                
            if "Q1" not in quincenas_dict:
                quincenas_dict["Q1"] = {}
                
            for q_name in sorted(quincenas_dict.keys()):
                self._add_quincena_tab(q_name, quincenas_dict[q_name])
        else:
            self.tab_widget_vars.tabBar().hide()
            self.btn_add_quincena.hide()
            self.btn_del_quincena.hide()
            
            if isinstance(data, dict) and "quincenas" in data:
                flat_data = data["quincenas"].get("Q1", {})
            else:
                flat_data = data if isinstance(data, dict) else {}
                
            self._add_quincena_tab("Mensual", flat_data)

    # ==================================================================
    # PESTAÑA 2 — CATEGORÍAS JORNALERAS (CRUD)
    # ==================================================================
    def _build_tab_categorias(self):
        layout = QVBoxLayout(self.tab_categorias)

        header = QHBoxLayout()
        header.addWidget(QLabel("<b>Categorías Jornaleras (Valor por Hora)</b>"))
        header.addStretch()

        btn_add = QPushButton("Agregar Categoría")
        btn_add.clicked.connect(self._agregar_categoria)
        header.addWidget(btn_add)

        btn_del = QPushButton("Eliminar Seleccionada")
        btn_del.clicked.connect(self._eliminar_categoria)
        header.addWidget(btn_del)

        btn_save = QPushButton("Guardar Cambios")
        btn_save.clicked.connect(self._guardar_categorias)
        header.addWidget(btn_save)

        layout.addLayout(header)

        self.tabla_categorias = QTableWidget()
        self.tabla_categorias.setAlternatingRowColors(True)
        self.tabla_categorias.setColumnCount(2)
        self.tabla_categorias.setHorizontalHeaderLabels(["Nombre de Categoría", "Valor de la Hora ($)"])
        self.tabla_categorias.horizontalHeader().setStretchLastSection(True)
        self.tabla_categorias.verticalHeader().setVisible(False)
        self.tabla_categorias.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        layout.addWidget(self.tabla_categorias)

        self._cargar_tabla_categorias()

    def _cargar_tabla_categorias(self):
        cats = self.db.listar_categorias_jornal()
        self.tabla_categorias.setRowCount(len(cats))
        for i, c in enumerate(cats):
            self.tabla_categorias.setItem(i, 0, QTableWidgetItem(c["nombre"]))
            self.tabla_categorias.setItem(i, 1, QTableWidgetItem(f"{c['valor_hora']:.2f}"))
            
            # ID oculto
            item_nombre = self.tabla_categorias.item(i, 0)
            if item_nombre:
                item_nombre.setData(Qt.ItemDataRole.UserRole, c["id"])

        self.tabla_categorias.resizeColumnsToContents()
        self.tabla_categorias.setColumnWidth(0, 400)

    def _guardar_categorias(self):
        errores = []
        for i in range(self.tabla_categorias.rowCount()):
            nombre = (self.tabla_categorias.item(i, 0).text() or "").strip()
            val_str = (self.tabla_categorias.item(i, 1).text() or "0").strip()

            if not nombre:
                errores.append(f"Fila {i + 1}: El nombre de la categoría es obligatorio.")
                continue
            try:
                val = float(val_str)
            except ValueError:
                errores.append(f"Fila {i + 1}: El valor de la hora debe ser un número decimal.")
                continue

            cat_id = self.tabla_categorias.item(i, 0).data(Qt.ItemDataRole.UserRole)
            try:
                self.db.guardar_categoria_jornal(cat_id, nombre, val)
            except Exception as e:
                errores.append(f"Fila {i + 1}: {e}")

        if errores:
            QMessageBox.warning(self, "Errores al guardar", "\n".join(errores))
        else:
            self.statusBar().showMessage("Categorías guardadas correctamente.", 4000)
        self._cargar_tabla_categorias()
        self._cargar_combos_empleado()

    def _agregar_categoria(self):
        self.db.guardar_categoria_jornal(None, "Nueva Categoría", 0.0)
        self._cargar_tabla_categorias()
        self.tabla_categorias.scrollToBottom()

    def _eliminar_categoria(self):
        row = self.tabla_categorias.currentRow()
        if row < 0:
            return
        item = self.tabla_categorias.item(row, 0)
        if not item:
            return
        cat_id = item.data(Qt.ItemDataRole.UserRole)
        if cat_id:
            resp = QMessageBox.question(
                self, "Confirmar",
                f"¿Eliminar la categoría \"{item.text()}\"?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if resp == QMessageBox.StandardButton.Yes:
                try:
                    self.db.eliminar_categoria_jornal(cat_id)
                    self._cargar_tabla_categorias()
                    self._cargar_combos_empleado()
                    self.statusBar().showMessage("Categoría eliminada.", 4000)
                except Exception as e:
                    QMessageBox.warning(self, "Error", f"No se pudo eliminar la categoría: {e}")

    # ==================================================================
    # PESTAÑA SECCIONES (CRUD)
    # ==================================================================
    def _build_tab_secciones(self):
        layout = QHBoxLayout(self.tab_secciones)
        splitter = QSplitter(Qt.Orientation.Horizontal)
        layout.addWidget(splitter)

        # Panel Izquierdo: Lista/Tabla de Secciones
        left = QWidget()
        left_layout = QVBoxLayout(left)

        self.tabla_secciones = QTableWidget()
        self.tabla_secciones.setColumnCount(4)
        self.tabla_secciones.setHorizontalHeaderLabels(["ID", "Código", "Título", "Orden"])
        self.tabla_secciones.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self.tabla_secciones.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.tabla_secciones.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.tabla_secciones.currentItemChanged.connect(self._on_seccion_seleccionada)
        left_layout.addWidget(self.tabla_secciones)

        btn_bar = QHBoxLayout()
        btn_nueva_sec = QPushButton("+ Nueva Sección")
        btn_nueva_sec.clicked.connect(self._nueva_seccion)
        btn_elim_sec = QPushButton("− Eliminar Sección")
        btn_elim_sec.clicked.connect(self._eliminar_seccion)
        btn_bar.addWidget(btn_nueva_sec)
        btn_bar.addWidget(btn_elim_sec)
        left_layout.addLayout(btn_bar)

        splitter.addWidget(left)

        # Panel Derecho: Formulario Editor
        right = QWidget()
        right_layout = QVBoxLayout(right)
        group_edit = QGroupBox("Editor de Sección")
        form = QFormLayout()

        self.sec_inp_codigo = QLineEdit()
        self.sec_inp_codigo.setPlaceholderText("Ej: PREMIOS (Mayúsculas sin espacios)")
        form.addRow("Código:", self.sec_inp_codigo)

        self.sec_inp_titulo = QLineEdit()
        self.sec_inp_titulo.setPlaceholderText("Ej: Premios y Adicionales")
        form.addRow("Título:", self.sec_inp_titulo)

        self.sec_inp_orden = QSpinBox()
        self.sec_inp_orden.setRange(0, 999)
        form.addRow("Orden:", self.sec_inp_orden)

        group_edit.setLayout(form)
        right_layout.addWidget(group_edit)

        btn_guardar_sec = QPushButton("Guardar Sección")
        btn_guardar_sec.clicked.connect(self._guardar_seccion)
        right_layout.addWidget(btn_guardar_sec)

        right_layout.addStretch()
        splitter.addWidget(right)

        self._cargar_tabla_secciones()

    def _cargar_tabla_secciones(self):
        self.tabla_secciones.setRowCount(0)
        self._secciones_data = self.db.listar_secciones()
        for i, sec in enumerate(self._secciones_data):
            self.tabla_secciones.insertRow(i)
            self.tabla_secciones.setItem(i, 0, QTableWidgetItem(str(sec["id"])))
            self.tabla_secciones.setItem(i, 1, QTableWidgetItem(sec["codigo"]))
            self.tabla_secciones.setItem(i, 2, QTableWidgetItem(sec["titulo"]))
            self.tabla_secciones.setItem(i, 3, QTableWidgetItem(str(sec.get("orden", 0))))
            
        self._refrescar_secciones_en_combos()

    def _on_seccion_seleccionada(self, current, previous):
        row = self.tabla_secciones.currentRow()
        if 0 <= row < len(self._secciones_data):
            sec = self._secciones_data[row]
            self.sec_inp_codigo.setText(sec["codigo"])
            self.sec_inp_titulo.setText(sec["titulo"])
            self.sec_inp_orden.setValue(sec.get("orden", 0))

    def _nueva_seccion(self):
        self.tabla_secciones.clearSelection()
        self.sec_inp_codigo.clear()
        self.sec_inp_titulo.clear()
        self.sec_inp_orden.setValue(len(self._secciones_data) * 10)
        self.sec_inp_codigo.setFocus()

    def _guardar_seccion(self):
        row = self.tabla_secciones.currentRow()
        sec_id = self._secciones_data[row]["id"] if (0 <= row < len(self._secciones_data)) else None

        codigo = self.sec_inp_codigo.text().strip().upper()
        titulo = self.sec_inp_titulo.text().strip()
        orden = self.sec_inp_orden.value()

        if not codigo or not titulo:
            QMessageBox.warning(self, "Error", "El código y título de la sección son obligatorios.")
            return

        self.db.guardar_seccion(sec_id, codigo, titulo, orden)
        self._cargar_tabla_secciones()
        self.statusBar().showMessage("Sección guardada correctamente.", 4000)

    def _eliminar_seccion(self):
        row = self.tabla_secciones.currentRow()
        if row < 0 or row >= len(self._secciones_data):
            return
        sec = self._secciones_data[row]
        resp = QMessageBox.question(
            self, "Confirmar",
            f"¿Desea eliminar la sección '{sec['titulo']}'?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if resp == QMessageBox.StandardButton.Yes:
            self.db.eliminar_seccion(sec["id"])
            self._cargar_tabla_secciones()

    def _refrescar_secciones_en_combos(self):
        """Actualiza los desplegables de secciones en el editor de Estructura de Recibo"""
        if hasattr(self, "combo_editor_seccion"):
            current = self.combo_editor_seccion.currentText()
            self.combo_editor_seccion.clear()
            secciones = [s["codigo"] for s in self.db.listar_secciones()]
            self.combo_editor_seccion.addItems(secciones)
            idx = self.combo_editor_seccion.findText(current)
            if idx >= 0:
                self.combo_editor_seccion.setCurrentIndex(idx)

    # ==================================================================
    # PESTAÑA 2b — CAMPOS GLOBALES DE SISTEMA
    # ==================================================================
    def _build_tab_globales(self):
        layout = QVBoxLayout(self.tab_globales)

        # Fila de herramientas superior
        top_layout = QHBoxLayout()
        top_layout.addWidget(QLabel("<b>Variables y Constantes Globales</b>"))
        top_layout.addStretch()

        self.btn_add_global = QPushButton("Agregar Variable")
        self.btn_add_global.clicked.connect(self._agregar_variable_global)
        top_layout.addWidget(self.btn_add_global)

        self.btn_del_global = QPushButton("Eliminar Variable")
        self.btn_del_global.clicked.connect(self._eliminar_variable_global)
        top_layout.addWidget(self.btn_del_global)

        btn_save = QPushButton("Guardar Cambios")
        btn_save.clicked.connect(self._guardar_variables_globales)
        # Resaltamos el botón de guardar para mejorar la experiencia
        top_layout.addWidget(btn_save)

        layout.addLayout(top_layout)

        # Tabla del Grid Editable
        self.tabla_globales = QTableWidget()
        self.tabla_globales.setColumnCount(3)
        self.tabla_globales.setHorizontalHeaderLabels([
            "Código de Variable", "Valor (Numérico o Texto)", "Descripción / Propósito"
        ])
        self.tabla_globales.setAlternatingRowColors(True)
        self.tabla_globales.verticalHeader().setVisible(False)
        self.tabla_globales.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        
        # Ajuste de tamaño inteligente de columnas
        self.tabla_globales.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Interactive)
        self.tabla_globales.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Interactive)
        self.tabla_globales.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self.tabla_globales.setColumnWidth(0, 220)
        self.tabla_globales.setColumnWidth(1, 180)

        layout.addWidget(self.tabla_globales)
        
        self._cargar_tabla_globales()

    def _cargar_tabla_globales(self):
        self.tabla_globales.blockSignals(True)
        variables = self.db.listar_variables_globales()
        self.tabla_globales.setRowCount(len(variables))

        is_user = hasattr(self, "modo_actual") and self.modo_actual == "Usuario"
        
        for i, var in enumerate(variables):
            item_codigo = QTableWidgetItem(var["codigo"])
            # Guardamos el ID en UserRole para rastrear cambios en la BD
            item_codigo.setData(Qt.ItemDataRole.UserRole, var["id"])
            
            item_valor = QTableWidgetItem(var["valor"])
            item_desc = QTableWidgetItem(var["descripcion"])

            if is_user:
                item_codigo.setFlags(item_codigo.flags() & ~Qt.ItemFlag.ItemIsEditable)
                item_desc.setFlags(item_desc.flags() & ~Qt.ItemFlag.ItemIsEditable)

            self.tabla_globales.setItem(i, 0, item_codigo)
            self.tabla_globales.setItem(i, 1, item_valor)
            self.tabla_globales.setItem(i, 2, item_desc)

        self.tabla_globales.blockSignals(False)

    def _agregar_variable_global(self):
        # Creamos una entrada básica temporal para que el usuario la personalice
        siguiente_num = self.tabla_globales.rowCount() + 1
        try:
            self.db.guardar_variable_global(
                None, f"nueva_variable_{siguiente_num}", "0.0", "Descripción de la variable"
            )
            self._cargar_tabla_globales()
            self.tabla_globales.setCurrentCell(self.tabla_globales.rowCount() - 1, 0)
            self.statusBar().showMessage("Nueva variable global añadida al final. Recuerde hacer clic en Guardar Cambios.", 4000)
        except Exception as e:
            QMessageBox.critical(self, "Error", f"No se pudo crear la variable: {str(e)}")

    def _eliminar_variable_global(self):
        row = self.tabla_globales.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Atención", "Seleccione una fila para eliminar.")
            return

        item_codigo = self.tabla_globales.item(row, 0)
        if not item_codigo:
            return

        var_id = item_codigo.data(Qt.ItemDataRole.UserRole)
        codigo = item_codigo.text().strip()

        resp = QMessageBox.question(
            self, "Confirmar eliminación",
            f"¿Está seguro de que desea eliminar permanentemente la variable '{codigo}'?\n"
            "Si algún concepto/fórmula la utiliza, fallará la simulación.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if resp == QMessageBox.StandardButton.Yes:
            if var_id:
                self.db.eliminar_variable_global(var_id)
            self._cargar_tabla_globales()
            self.statusBar().showMessage("Variable global eliminada correctamente.", 4000)

    def _guardar_variables_globales(self):
        errores = []
        for i in range(self.tabla_globales.rowCount()):
            item_codigo = self.tabla_globales.item(i, 0)
            item_valor = self.tabla_globales.item(i, 1)
            item_desc = self.tabla_globales.item(i, 2)

            if not item_codigo or not item_valor:
                continue

            codigo = item_codigo.text().strip()
            valor = item_valor.text().strip()
            desc = item_desc.text().strip() if item_desc else ""
            var_id = item_codigo.data(Qt.ItemDataRole.UserRole)

            if not codigo:
                errores.append(f"Fila {i + 1}: El código de variable no puede estar vacío.")
                continue
            if not valor:
                errores.append(f"Fila {i + 1}: El valor no puede estar vacío.")
                continue

            try:
                self.db.guardar_variable_global(var_id, codigo, valor, desc)
            except Exception as e:
                errores.append(f"Fila {i + 1} ('{codigo}'): {str(e)}")

        if errores:
            QMessageBox.warning(self, "Errores al guardar", "\n".join(errores))
        else:
            self.statusBar().showMessage("Variables globales guardadas con éxito.", 4000)
        
        self._cargar_tabla_globales()

    # ==================================================================
    # PESTAÑA 3 — ESTRUCTURA DEL RECIBO (Con Editor Simple y Asistente)
    # ==================================================================
    def _build_tab_estructura(self):
        layout = QVBoxLayout(self.tab_estructura)

        # Fila de Filtro por Esquema
        filter_layout = QHBoxLayout()
        filter_layout.addWidget(QLabel("<b>Esquema de Cálculo:</b>"))
        self.combo_filter_esquema = QComboBox()
        for esq in self.db.listar_esquemas():
            self.combo_filter_esquema.addItem(esq["nombre"], esq["codigo"])
        self.combo_filter_esquema.currentIndexChanged.connect(self._on_esquema_filtro_cambiado)
        filter_layout.addWidget(self.combo_filter_esquema)
        filter_layout.addStretch()

        btn_add = QPushButton("Agregar Celda")
        btn_add.clicked.connect(self._agregar_celda)
        filter_layout.addWidget(btn_add)

        btn_del = QPushButton("Eliminar Celda")
        btn_del.clicked.connect(self._eliminar_celda)
        filter_layout.addWidget(btn_del)

        btn_save = QPushButton("Guardar Cambios")
        btn_save.clicked.connect(self._guardar_celdas)
        filter_layout.addWidget(btn_save)

        layout.addLayout(filter_layout)

        # Splitter principal para separar Tabla de Editor Simple
        splitter = QSplitter(Qt.Orientation.Vertical)
        layout.addWidget(splitter)

        # Tabla (Superior)
        self.tabla_celdas = QTableWidget()
        self.tabla_celdas.setAlternatingRowColors(True)
        self.tabla_celdas.setColumnCount(10)
        self.tabla_celdas.setHorizontalHeaderLabels([
            "Sección", "Código Variable", "Descripción", "Condición",
            "Tipo Cálculo", "Fórmula Unidad / Pct", "Fórmula Base", "Fórmula Monto", "Mostrar", "Orden",
        ])
        self.tabla_celdas.horizontalHeader().setStretchLastSection(True)
        self.tabla_celdas.verticalHeader().setVisible(False)
        self.tabla_celdas.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.tabla_celdas.itemSelectionChanged.connect(self._on_celda_seleccionada_tabla)
        splitter.addWidget(self.tabla_celdas)

        # Editor Simple / Avanzado (Inferior)
        self.editor_celda_group = QGroupBox("Configuración de Concepto (Estilo Simple / SAP)")
        editor_layout = QVBoxLayout(self.editor_celda_group)
        
        form_simple = QFormLayout()
        
        # Selector del Tipo de Cálculo
        self.combo_editor_tipo = QComboBox()
        self.combo_editor_tipo.addItem("Porcentaje de un Concepto", "porcentaje")
        self.combo_editor_tipo.addItem("Monto Fijo Directo", "fijo")
        self.combo_editor_tipo.addItem("Fórmulas Matemáticas (Avanzado)", "formula")
        self.combo_editor_tipo.currentIndexChanged.connect(self._on_tipo_calculo_editor_cambiado)
        form_simple.addRow("Regla de Cálculo:", self.combo_editor_tipo)

        # --- Función Auxiliar para crear inputs con botón de rayito '⚡' ---
        def make_input_with_helper(placeholder, tooltip):
            container = QWidget()
            h_layout = QHBoxLayout(container)
            h_layout.setContentsMargins(0, 0, 0, 0)
            h_layout.setSpacing(4)
            
            inp = QLineEdit()
            inp.setPlaceholderText(placeholder)
            
            btn = QToolButton()
            btn.setText("⚡")
            btn.setToolTip(tooltip)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.clicked.connect(lambda: self._abrir_asistente_variables(inp))
            
            h_layout.addWidget(inp)
            h_layout.addWidget(btn)
            return container, inp

        # Campo de Condición (General para todos los conceptos, movido aquí abajo)
        cond_widget, self.inp_condicion = make_input_with_helper(
            "Ej: antiguedad_anios > 5  o  asistencia_perfecta == true", 
            "Abrir asistente de variables para la Condición"
        )
        form_simple.addRow("Condición de Aplicación:", cond_widget)

        # Campo de visibilidad del recibo
        self.chk_visible_recibo = QCheckBox("Mostrar en Recibo (Vista Final)")
        self.chk_visible_recibo.setChecked(True)
        form_simple.addRow("Visibilidad:", self.chk_visible_recibo)

        # Stack de widgets
        self.editor_stack = QStackedWidget()

        # 1. Panel Porcentaje
        self.pane_porcentaje = QWidget()
        l_pct = QHBoxLayout(self.pane_porcentaje)
        l_pct.setContentsMargins(0, 0, 0, 0)
        self.spin_pct_valor = QDoubleSpinBox()
        self.spin_pct_valor.setRange(0, 100)
        self.spin_pct_valor.setDecimals(2)
        self.spin_pct_valor.setSuffix(" %")
        l_pct.addWidget(self.spin_pct_valor)
        l_pct.addWidget(QLabel(" Sobre Concepto Base: "))
        self.combo_pct_base = QComboBox()
        self.combo_pct_base.setMinimumWidth(250)
        l_pct.addWidget(self.combo_pct_base)
        l_pct.addStretch()
        self.editor_stack.addWidget(self.pane_porcentaje)

        # 2. Panel Fijo
        self.pane_fijo = QWidget()
        l_fijo = QHBoxLayout(self.pane_fijo)
        l_fijo.setContentsMargins(0, 0, 0, 0)
        self.spin_fijo_valor = QDoubleSpinBox()
        self.spin_fijo_valor.setRange(0, 99999999)
        self.spin_fijo_valor.setDecimals(2)
        self.spin_fijo_valor.setPrefix("$ ")
        l_fijo.addWidget(self.spin_fijo_valor)
        l_fijo.addStretch()
        self.editor_stack.addWidget(self.pane_fijo)

        # 3. Panel Avanzado (Fórmulas con asistente de variables)
        self.pane_formula = QWidget()
        l_form = QFormLayout(self.pane_formula)
        l_form.setContentsMargins(0, 0, 0, 0)
        
        unid_widget, self.inp_formula_unidad = make_input_with_helper(
            "Ej: antiguedad_anios", "Insertar variable en Fórmula Unidad"
        )
        l_form.addRow("Fórmula Unidad:", unid_widget)

        base_widget, self.inp_formula_base = make_input_with_helper(
            "Ej: basico_categoria", "Insertar variable en Fórmula Base"
        )
        l_form.addRow("Fórmula Base:", base_widget)

        monto_widget, self.inp_formula_monto = make_input_with_helper(
            "Ej: unidad * base  o  bruto * 0.11", "Insertar variable en Fórmula Monto"
        )
        l_form.addRow("Fórmula Monto:", monto_widget)
        
        self.editor_stack.addWidget(self.pane_formula)

        form_simple.addRow(self.editor_stack)
        editor_layout.addLayout(form_simple)

        # Conectar widgets del editor a actualizaciones de la tabla
        self.spin_pct_valor.valueChanged.connect(self._sync_editor_hacia_tabla)
        self.combo_pct_base.currentIndexChanged.connect(self._sync_editor_hacia_tabla)
        self.spin_fijo_valor.valueChanged.connect(self._sync_editor_hacia_tabla)
        self.inp_condicion.textChanged.connect(self._sync_editor_hacia_tabla)
        self.inp_formula_unidad.textChanged.connect(self._sync_editor_hacia_tabla)
        self.inp_formula_base.textChanged.connect(self._sync_editor_hacia_tabla)
        self.inp_formula_monto.textChanged.connect(self._sync_editor_hacia_tabla)
        self.chk_visible_recibo.stateChanged.connect(self._sync_editor_hacia_tabla)

        splitter.addWidget(self.editor_celda_group)
        splitter.setSizes([450, 250])

        self._cargar_tabla_celdas()

    def _abrir_asistente_variables(self, line_edit):
        """Abre la ventana del asistente pasándole todos los alcances de variables."""
        sys_vars, glob_vars, emp_vars, esq_vars = self._obtener_todas_las_variables()
        dialog = VariableAssistantDialog(self, sys_vars, glob_vars, emp_vars, esq_vars, line_edit)
        dialog.exec()

    def _on_esquema_filtro_cambiado(self):
        self._cargar_tabla_celdas()

    def _cargar_tabla_celdas(self):
        esq = self.combo_filter_esquema.currentData()
        if not esq:
            return

        self.tabla_celdas.blockSignals(True)
        celdas = self.db.listar_celdas_por_esquema(esq)
        self.tabla_celdas.setRowCount(len(celdas))

        secciones = [s["codigo"] for s in self.db.listar_secciones()]

        for i, c in enumerate(celdas):
            combo = QComboBox()
            combo.addItems(secciones)
            idx = combo.findText(c["seccion_codigo"])
            if idx >= 0:
                combo.setCurrentIndex(idx)
            self.tabla_celdas.setCellWidget(i, 0, combo)

            # Columnas editables del grid (Código, Descripción, Orden)
            self.tabla_celdas.setItem(i, 1, QTableWidgetItem(c["codigo_variable"]))
            self.tabla_celdas.setItem(i, 2, QTableWidgetItem(c["descripcion"]))
            self.tabla_celdas.setItem(i, 9, QTableWidgetItem(str(c["orden"])))

            # --- NUEVO: Hacer celdas calculadas, fórmulas y condiciones estrictamente READ-ONLY en el grid ---
            def make_readonly_item(text):
                it = QTableWidgetItem(text)
                it.setFlags(it.flags() & ~Qt.ItemFlag.ItemIsEditable)
                return it

            self.tabla_celdas.setItem(i, 3, make_readonly_item(c["condicion"] or ""))
            self.tabla_celdas.setItem(i, 4, make_readonly_item(c["tipo_calculo"]))

            t = c["tipo_calculo"]
            if t == "porcentaje":
                self.tabla_celdas.setItem(i, 5, make_readonly_item(f"{c['simple_porcentaje'] or 0.0}%"))
                self.tabla_celdas.setItem(i, 6, make_readonly_item(f"sobre {c['simple_base_variable'] or ''}"))
                self.tabla_celdas.setItem(i, 7, make_readonly_item("calculado"))
            elif t == "fijo":
                self.tabla_celdas.setItem(i, 5, make_readonly_item("-"))
                self.tabla_celdas.setItem(i, 6, make_readonly_item("-"))
                self.tabla_celdas.setItem(i, 7, make_readonly_item(f"Fijo: ${c['simple_monto_fijo'] or 0.0}"))
            else:
                self.tabla_celdas.setItem(i, 5, make_readonly_item(c["formula_unidad"] or ""))
                self.tabla_celdas.setItem(i, 6, make_readonly_item(c["formula_base"] or ""))
                self.tabla_celdas.setItem(i, 7, make_readonly_item(c["formula_monto"] or ""))

            # Mostrar en recibo
            vis_text = "Sí" if c.get("visible_recibo", 1) == 1 else "No"
            self.tabla_celdas.setItem(i, 8, make_readonly_item(vis_text))

            # Guardar en metadatos para el editor inferior
            item_codigo = self.tabla_celdas.item(i, 1)
            if item_codigo:
                item_codigo.setData(Qt.ItemDataRole.UserRole, c["id"])
                item_codigo.setData(Qt.ItemDataRole.UserRole + 1, c["tipo_calculo"])
                item_codigo.setData(Qt.ItemDataRole.UserRole + 2, c["simple_porcentaje"])
                item_codigo.setData(Qt.ItemDataRole.UserRole + 3, c["simple_base_variable"])
                item_codigo.setData(Qt.ItemDataRole.UserRole + 4, c["simple_monto_fijo"])
                item_codigo.setData(Qt.ItemDataRole.UserRole + 5, c["formula_unidad"] or "")
                item_codigo.setData(Qt.ItemDataRole.UserRole + 6, c["formula_base"] or "")
                item_codigo.setData(Qt.ItemDataRole.UserRole + 7, c["formula_monto"] or "")
                item_codigo.setData(Qt.ItemDataRole.UserRole + 8, c["condicion"] or "")
                item_codigo.setData(Qt.ItemDataRole.UserRole + 9, c.get("visible_recibo", 1))

        self.tabla_celdas.blockSignals(False)

        # Ancho de columnas
        self.tabla_celdas.setColumnWidth(0, 130)
        self.tabla_celdas.setColumnWidth(1, 160)
        self.tabla_celdas.setColumnWidth(2, 180)
        self.tabla_celdas.setColumnWidth(3, 140)
        self.tabla_celdas.setColumnWidth(4, 100)
        self.tabla_celdas.setColumnWidth(5, 150)
        self.tabla_celdas.setColumnWidth(6, 150)
        self.tabla_celdas.setColumnWidth(7, 240)
        self.tabla_celdas.setColumnWidth(8, 70)
        self.tabla_celdas.setColumnWidth(9, 60)

        if self.tabla_celdas.rowCount() > 0:
            self.tabla_celdas.selectRow(0)

    def _on_celda_seleccionada_tabla(self):
        row = self.tabla_celdas.currentRow()
        if row < 0:
            return

        item_codigo = self.tabla_celdas.item(row, 1)
        if not item_codigo:
            return

        self._is_loading_cell = True

        self.spin_pct_valor.blockSignals(True)
        self.combo_pct_base.blockSignals(True)
        self.spin_fijo_valor.blockSignals(True)
        self.inp_condicion.blockSignals(True)
        self.inp_formula_unidad.blockSignals(True)
        self.inp_formula_base.blockSignals(True)
        self.inp_formula_monto.blockSignals(True)
        self.combo_editor_tipo.blockSignals(True)
        self.chk_visible_recibo.blockSignals(True)

        tipo_calculo = item_codigo.data(Qt.ItemDataRole.UserRole + 1) or "formula"
        simple_porcentaje = item_codigo.data(Qt.ItemDataRole.UserRole + 2)
        simple_base_variable = item_codigo.data(Qt.ItemDataRole.UserRole + 3)
        simple_monto_fijo = item_codigo.data(Qt.ItemDataRole.UserRole + 4)
        formula_unidad = item_codigo.data(Qt.ItemDataRole.UserRole + 5) or ""
        formula_base = item_codigo.data(Qt.ItemDataRole.UserRole + 6) or ""
        formula_monto = item_codigo.data(Qt.ItemDataRole.UserRole + 7) or ""
        condicion = item_codigo.data(Qt.ItemDataRole.UserRole + 8) or ""
        visible_recibo = item_codigo.data(Qt.ItemDataRole.UserRole + 9)
        if visible_recibo is None:
            visible_recibo = 1

        # Rellenar combo de variables base del mismo esquema
        self.combo_pct_base.clear()
        for r_i in range(self.tabla_celdas.rowCount()):
            it = self.tabla_celdas.item(r_i, 1)
            if it:
                v_code = it.text().strip()
                if v_code and v_code != item_codigo.text().strip():
                    self.combo_pct_base.addItem(v_code, v_code)

        idx = self.combo_editor_tipo.findData(tipo_calculo)
        if idx >= 0:
            self.combo_editor_tipo.setCurrentIndex(idx)

        self._on_tipo_calculo_editor_cambiado()

        self.spin_pct_valor.setValue(simple_porcentaje if simple_porcentaje is not None else 0.0)
        idx_base = self.combo_pct_base.findData(simple_base_variable)
        if idx_base >= 0:
            self.combo_pct_base.setCurrentIndex(idx_base)

        self.spin_fijo_valor.setValue(simple_monto_fijo if simple_monto_fijo is not None else 0.0)
        self.inp_condicion.setText(condicion)
        self.inp_formula_unidad.setText(formula_unidad)
        self.inp_formula_base.setText(formula_base)
        self.inp_formula_monto.setText(formula_monto)
        self.chk_visible_recibo.setChecked(visible_recibo == 1)

        self.spin_pct_valor.blockSignals(False)
        self.combo_pct_base.blockSignals(False)
        self.spin_fijo_valor.blockSignals(False)
        self.inp_condicion.blockSignals(False)
        self.inp_formula_unidad.blockSignals(False)
        self.inp_formula_base.blockSignals(False)
        self.inp_formula_monto.blockSignals(False)
        self.combo_editor_tipo.blockSignals(False)
        self.chk_visible_recibo.blockSignals(False)

        self._is_loading_cell = False

    def _on_tipo_calculo_editor_cambiado(self):
        t = self.combo_editor_tipo.currentData()
        if t == "porcentaje":
            self.editor_stack.setCurrentWidget(self.pane_porcentaje)
        elif t == "fijo":
            self.editor_stack.setCurrentWidget(self.pane_fijo)
        else:
            self.editor_stack.setCurrentWidget(self.pane_formula)
        
        if not getattr(self, "_is_loading_cell", False):
            self._sync_editor_hacia_tabla()

    def _sync_editor_hacia_tabla(self):
        if getattr(self, "_is_loading_cell", False):
            return

        row = self.tabla_celdas.currentRow()
        if row < 0:
            return
        item_codigo = self.tabla_celdas.item(row, 1)
        if not item_codigo:
            return

        tipo_calculo = self.combo_editor_tipo.currentData()
        item_codigo.setData(Qt.ItemDataRole.UserRole + 1, tipo_calculo)
        
        # Guardar valores
        item_codigo.setData(Qt.ItemDataRole.UserRole + 2, self.spin_pct_valor.value())
        item_codigo.setData(Qt.ItemDataRole.UserRole + 3, self.combo_pct_base.currentData())
        item_codigo.setData(Qt.ItemDataRole.UserRole + 4, self.spin_fijo_valor.value())
        item_codigo.setData(Qt.ItemDataRole.UserRole + 5, self.inp_formula_unidad.text())
        item_codigo.setData(Qt.ItemDataRole.UserRole + 6, self.inp_formula_base.text())
        item_codigo.setData(Qt.ItemDataRole.UserRole + 7, self.inp_formula_monto.text())
        item_codigo.setData(Qt.ItemDataRole.UserRole + 8, self.inp_condicion.text())
        item_codigo.setData(Qt.ItemDataRole.UserRole + 9, 1 if self.chk_visible_recibo.isChecked() else 0)

        # Actualizar visualización en la tabla de forma segura sin romper el foco ni la selección
        self.tabla_celdas.blockSignals(True)

        def safe_set_readonly_text(r, c, text):
            it = self.tabla_celdas.item(r, c)
            if it:
                it.setText(text)
            else:
                new_it = QTableWidgetItem(text)
                new_it.setFlags(new_it.flags() & ~Qt.ItemFlag.ItemIsEditable)
                self.tabla_celdas.setItem(r, c, new_it)

        # Sincronizamos la condición directamente
        safe_set_readonly_text(row, 3, self.inp_condicion.text())
        safe_set_readonly_text(row, 4, tipo_calculo)
        
        if tipo_calculo == "porcentaje":
            safe_set_readonly_text(row, 5, f"{self.spin_pct_valor.value()}%")
            safe_set_readonly_text(row, 6, f"sobre {self.combo_pct_base.currentText()}")
            safe_set_readonly_text(row, 7, "calculado")
        elif tipo_calculo == "fijo":
            safe_set_readonly_text(row, 5, "-")
            safe_set_readonly_text(row, 6, "-")
            safe_set_readonly_text(row, 7, f"Fijo: ${self.spin_fijo_valor.value()}")
        else:
            safe_set_readonly_text(row, 5, self.inp_formula_unidad.text())
            safe_set_readonly_text(row, 6, self.inp_formula_base.text())
            safe_set_readonly_text(row, 7, self.inp_formula_monto.text())

        # Mostrar
        safe_set_readonly_text(row, 8, "Sí" if self.chk_visible_recibo.isChecked() else "No")

        self.tabla_celdas.blockSignals(False)

    def _guardar_celdas(self):
        esq = self.combo_filter_esquema.currentData()
        if not esq:
            return

        errores = []
        for i in range(self.tabla_celdas.rowCount()):
            combo_sec = self.tabla_celdas.cellWidget(i, 0)
            seccion = combo_sec.currentText() if combo_sec else "COMPOSICION"
            
            codigo = (self.tabla_celdas.item(i, 1).text() or "").strip()
            desc = (self.tabla_celdas.item(i, 2).text() or "").strip()
            orden_str = (self.tabla_celdas.item(i, 9).text() or "0").strip()

            item_codigo = self.tabla_celdas.item(i, 1)
            tipo_calc = item_codigo.data(Qt.ItemDataRole.UserRole + 1) or "formula"
            simple_porcentaje = item_codigo.data(Qt.ItemDataRole.UserRole + 2)
            simple_base_variable = item_codigo.data(Qt.ItemDataRole.UserRole + 3)
            simple_monto_fijo = item_codigo.data(Qt.ItemDataRole.UserRole + 4)
            formula_unidad = item_codigo.data(Qt.ItemDataRole.UserRole + 5)
            formula_base = item_codigo.data(Qt.ItemDataRole.UserRole + 6)
            formula_monto = item_codigo.data(Qt.ItemDataRole.UserRole + 7)
            cond = item_codigo.data(Qt.ItemDataRole.UserRole + 8) or ""
            visible_recibo = item_codigo.data(Qt.ItemDataRole.UserRole + 9)
            if visible_recibo is None:
                visible_recibo = 1

            if not codigo:
                errores.append(f"Fila {i + 1}: El código de variable es obligatorio.")
                continue

            if tipo_calc == "formula" and not formula_monto:
                errores.append(f"Fila {i + 1}: Fórmula de Monto es obligatoria en modo avanzado.")
                continue

            try:
                orden = int(orden_str)
            except ValueError:
                errores.append(f"Fila {i + 1}: El orden debe ser un entero.")
                continue

            celda_id = item_codigo.data(Qt.ItemDataRole.UserRole)
            try:
                self.db.guardar_celda(
                    celda_id, seccion, codigo, desc, cond, formula_unidad, formula_base, formula_monto,
                    orden, esq, tipo_calc, simple_porcentaje, simple_base_variable, simple_monto_fijo,
                    visible_recibo
                )
            except Exception as e:
                errores.append(f"Fila {i + 1}: {e}")

        if errores:
            QMessageBox.warning(self, "Errores al guardar", "\n".join(errores))
        else:
            self.statusBar().showMessage("Estructura de celdas guardada correctamente.", 4000)
        self._cargar_tabla_celdas()

    def _agregar_celda(self):
        esq = self.combo_filter_esquema.currentData()
        if not esq:
            return
        secciones = self.db.listar_secciones()
        sec = secciones[0]["codigo"] if secciones else "COMPOSICION"
        celdas = self.db.listar_celdas_por_esquema(esq)
        max_orden = max((c["orden"] for c in celdas), default=0)
        
        self.db.guardar_celda(
            None, sec, f"nueva_var_{max_orden + 10}", "Nuevo concepto",
            "", "", "", "unidad * base", max_orden + 10, esq,
            "formula", 0.0, "", 0.0
        )
        self._cargar_tabla_celdas()
        self.tabla_celdas.scrollToBottom()

    def _eliminar_celda(self):
        row = self.tabla_celdas.currentRow()
        if row < 0:
            return
        item = self.tabla_celdas.item(row, 1)
        if not item:
            return
        celda_id = item.data(Qt.ItemDataRole.UserRole)
        if celda_id:
            resp = QMessageBox.question(
                self, "Confirmar",
                f"¿Eliminar la celda \"{item.text()}\"?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if resp == QMessageBox.StandardButton.Yes:
                self.db.eliminar_celda(celda_id)
                self._cargar_tabla_celdas()
                self.statusBar().showMessage("Celda eliminada.", 4000)

    def _obtener_todas_las_variables(self):
        """Busca dinámicamente qué variables hay configuradas en los empleados,
        los parámetros globales, y las celdas de este esquema."""
        
        # 1. Variables del Sistema (Ficha física)
        sys_vars = {
            "tipo_liquidacion": "Devuelve 'mensual' o 'jornal'",
            "valor_hora": "Valor hora de la categoría jornalera asignada",
            "legajo": "Número de legajo del empleado",
            "nombre_completo": "Nombre y apellido del empleado",
            "fecha_ingreso": "Fecha de ingreso del empleado (YYYY-MM-DD)",
            "fecha_calculo": "Fecha de cálculo (Hoy/Liquidación) (YYYY-MM-DD)",
            "antiguedad_anios": "Años de antigüedad (calculado automáticamente)",
            "antiguedad": "Años de antigüedad (alias de antiguedad_anios)",
        }

        # 2. NUEVO: Variables Globales desde SQLite
        glob_vars = {}
        try:
            for v_glob in self.db.listar_variables_globales():
                # Guardamos el código como key y su valor + descripción en el valor del dict
                glob_vars[v_glob["codigo"]] = f"{v_glob['valor']}"
        except Exception:
            pass

        # 3. Variables dinámicas desde los JSON de variables de cálculo de los empleados
        emp_vars = set()
        try:
            for emp in self.db.listar_empleados():
                try:
                    import json
                    data = json.loads(emp["variables_calculo"] or "{}")
                    if isinstance(data, dict):
                        if "quincenas" in data:
                            # Estructura de quincenas: extraer variables de cada quincena
                            for q_name, q_vars in data["quincenas"].items():
                                if isinstance(q_vars, dict):
                                    emp_vars.update(q_vars.keys())
                        else:
                            # Estructura plana
                            emp_vars.update(data.keys())
                except Exception:
                    pass
        except Exception:
            pass
        
        if not emp_vars:
            emp_vars = {"asistencia_perfecta", "horas_trabajadas", "horas_extras_50", "horas_extras_100"}
            
        # Filtramos para no duplicar con llaves fijas del sistema
        emp_vars = emp_vars - set(sys_vars.keys()) - set(glob_vars.keys())

        # 4. Códigos de conceptos (celdas) de la tabla actual
        esq_vars = []
        for row in range(self.tabla_celdas.rowCount()):
            item = self.tabla_celdas.item(row, 1)
            if item:
                code = item.text().strip()
                if code:
                    esq_vars.append(code)
                    
        return sys_vars, glob_vars, sorted(list(emp_vars)), sorted(esq_vars)

    # ==================================================================
    # PESTAÑA 4 — ESTRUCTURA DEL GRÁFICO (CRUD)
    # ==================================================================
    def _build_tab_grafico_config(self):
        layout = QVBoxLayout(self.tab_graficos_config)

        filter_layout = QHBoxLayout()
        filter_layout.addWidget(QLabel("<b>Esquema de Cálculo:</b>"))
        self.combo_filter_esquema_g = QComboBox()
        for esq in self.db.listar_esquemas():
            self.combo_filter_esquema_g.addItem(esq["nombre"], esq["codigo"])
        self.combo_filter_esquema_g.currentIndexChanged.connect(self._on_esquema_grafico_filtro_cambiado)
        filter_layout.addWidget(self.combo_filter_esquema_g)
        filter_layout.addStretch()

        btn_add = QPushButton("Agregar Porción")
        btn_add.clicked.connect(self._agregar_porcion_grafico)
        filter_layout.addWidget(btn_add)

        btn_del = QPushButton("Eliminar Seleccionada")
        btn_del.clicked.connect(self._eliminar_porcion_grafico)
        filter_layout.addWidget(btn_del)

        btn_save = QPushButton("Guardar Cambios")
        btn_save.clicked.connect(self._guardar_grafico_config)
        filter_layout.addWidget(btn_save)

        layout.addLayout(filter_layout)

        self.tabla_grafico = QTableWidget()
        self.tabla_grafico.setAlternatingRowColors(True)
        self.tabla_grafico.setColumnCount(3)
        self.tabla_grafico.setHorizontalHeaderLabels([
            "Etiqueta de Porción", "Fórmula de Agrupación (Variables del Recibo)", "Orden"
        ])
        self.tabla_grafico.horizontalHeader().setStretchLastSection(True)
        self.tabla_grafico.verticalHeader().setVisible(False)
        self.tabla_grafico.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        layout.addWidget(self.tabla_grafico)

        self._cargar_tabla_grafico()

    def _on_esquema_grafico_filtro_cambiado(self):
        self._cargar_tabla_grafico()

    def _cargar_tabla_grafico(self):
        esq = self.combo_filter_esquema_g.currentData()
        if not esq:
            return

        celdas = self.db.listar_celdas_grafico_por_esquema(esq)
        self.tabla_grafico.setRowCount(len(celdas))

        for i, c in enumerate(celdas):
            self.tabla_grafico.setItem(i, 0, QTableWidgetItem(c["etiqueta"]))
            self.tabla_grafico.setItem(i, 1, QTableWidgetItem(c["formula"]))
            self.tabla_grafico.setItem(i, 2, QTableWidgetItem(str(c["orden"])))

            item_etiqueta = self.tabla_grafico.item(i, 0)
            if item_etiqueta:
                item_etiqueta.setData(Qt.ItemDataRole.UserRole, c["id"])

        self.tabla_grafico.resizeColumnsToContents()
        self.tabla_grafico.setColumnWidth(0, 300)
        self.tabla_grafico.setColumnWidth(1, 600)
        self.tabla_grafico.setColumnWidth(2, 80)

    def _guardar_grafico_config(self):
        esq = self.combo_filter_esquema_g.currentData()
        if not esq:
            return

        errores = []
        for i in range(self.tabla_grafico.rowCount()):
            etiqueta = (self.tabla_grafico.item(i, 0).text() or "").strip()
            formula = (self.tabla_grafico.item(i, 1).text() or "").strip()
            orden_str = (self.tabla_grafico.item(i, 2).text() or "0").strip()

            if not etiqueta or not formula:
                errores.append(f"Fila {i + 1}: Etiqueta y Fórmula son obligatorios.")
                continue

            try:
                orden = int(orden_str)
            except ValueError:
                errores.append(f"Fila {i + 1}: Orden debe ser un entero.")
                continue

            celda_id = self.tabla_grafico.item(i, 0).data(Qt.ItemDataRole.UserRole)
            try:
                self.db.guardar_celda_grafico(celda_id, etiqueta, formula, orden, esq)
            except Exception as e:
                errores.append(f"Fila {i + 1}: {e}")

        if errores:
            QMessageBox.warning(self, "Errores al guardar", "\n".join(errores))
        else:
            self.statusBar().showMessage("Configuración de gráfico guardada correctamente.", 4000)
        self._cargar_tabla_grafico()

    def _agregar_porcion_grafico(self):
        esq = self.combo_filter_esquema_g.currentData()
        if not esq:
            return
        celdas = self.db.listar_celdas_grafico_por_esquema(esq)
        max_orden = max((c["orden"] for c in celdas), default=0)
        self.db.guardar_celda_grafico(None, "Nueva Categoría", "0", max_orden + 10, esq)
        self._cargar_tabla_grafico()
        self.tabla_grafico.scrollToBottom()

    def _eliminar_porcion_grafico(self):
        row = self.tabla_grafico.currentRow()
        if row < 0:
            return
        item = self.tabla_grafico.item(row, 0)
        if not item:
            return
        celda_id = item.data(Qt.ItemDataRole.UserRole)
        if celda_id:
            resp = QMessageBox.question(
                self, "Confirmar",
                f"¿Eliminar la porción \"{item.text()}\" del gráfico?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if resp == QMessageBox.StandardButton.Yes:
                self.db.eliminar_celda_grafico(celda_id)
                self._cargar_tabla_grafico()
                self.statusBar().showMessage("Porción eliminada.", 4000)

    # ==================================================================
    # PESTAÑA 5 — VISTA PREVIA DEL RECIBO (Con Gráficos y Reportes)
    # ==================================================================
    def _build_tab_preview(self):
        layout = QVBoxLayout(self.tab_preview)

        # Controles superiores
        top = QHBoxLayout()
        top.addWidget(QLabel("Empleado:"))
        self.combo_empleado = QComboBox()
        self.combo_empleado.setMinimumWidth(200)
        self.combo_empleado.currentIndexChanged.connect(self._on_combo_empleado_cambiado)
        top.addWidget(self.combo_empleado)

        self.lbl_quincena = QLabel("Quincena:")
        self.lbl_quincena.hide()
        top.addWidget(self.lbl_quincena)

        self.combo_quincena = QComboBox()
        self.combo_quincena.setMinimumWidth(90)
        self.combo_quincena.hide()
        top.addWidget(self.combo_quincena)

        top.addWidget(QLabel("Fecha de Cálculo (Hoy):"))
        self.inp_fecha_hoy = QDateEdit()
        self.inp_fecha_hoy.setCalendarPopup(True)
        self.inp_fecha_hoy.setDisplayFormat("yyyy-MM-dd")
        self.inp_fecha_hoy.setDate(QDate.currentDate())
        top.addWidget(self.inp_fecha_hoy)

        self.chk_debug_recibo = QCheckBox("Modo Debug (mostrar ocultos)")
        self.chk_debug_recibo.setChecked(False)
        top.addWidget(self.chk_debug_recibo)

        btn_calcular = QPushButton("Calcular Liquidación")
        btn_calcular.clicked.connect(self._calcular_liquidacion)
        top.addWidget(btn_calcular)
        top.addStretch()
        layout.addLayout(top)

        # Resumen KPIs
        self.group_resumen = QGroupBox("Resumen")
        resumen_layout = QHBoxLayout()

        self.lbl_bruto = QLabel("Bruto: —")
        self.lbl_bruto.setFont(self._bold_font())
        resumen_layout.addWidget(self.lbl_bruto)

        resumen_layout.addWidget(self._separador_v())

        self.lbl_deducciones = QLabel("Deducciones: —")
        self.lbl_deducciones.setFont(self._bold_font())
        resumen_layout.addWidget(self.lbl_deducciones)

        resumen_layout.addWidget(self._separador_v())

        self.lbl_neto = QLabel("Neto: —")
        self.lbl_neto.setFont(self._bold_font())
        resumen_layout.addWidget(self.lbl_neto)

        resumen_layout.addWidget(self._separador_v())

        self.lbl_costo = QLabel("Costo Total: —")
        self.lbl_costo.setFont(self._bold_font())
        resumen_layout.addWidget(self.lbl_costo)

        resumen_layout.addStretch()
        self.group_resumen.setLayout(resumen_layout)
        layout.addWidget(self.group_resumen)

        # Splitter principal
        splitter = QSplitter(Qt.Orientation.Horizontal)
        layout.addWidget(splitter)
        layout.setStretchFactor(splitter, 1)

        # --- Panel Izquierdo: Tabla/Tree del Recibo ---
        left_widget = QWidget()
        left_layout = QVBoxLayout(left_widget)
        left_layout.setContentsMargins(0, 0, 0, 0)

        self.tree_resultado = QTreeWidget()
        self.tree_resultado.setColumnCount(4)
        self.tree_resultado.setHeaderLabels(["Concepto", "Unidad", "Base", "Monto"])
        self.tree_resultado.setAlternatingRowColors(True)
        self.tree_resultado.setRootIsDecorated(True)
        self.tree_resultado.header().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        for col in (1, 2, 3):
            self.tree_resultado.header().setSectionResizeMode(col, QHeaderView.ResizeMode.Interactive)
        self.tree_resultado.setColumnWidth(1, 110)
        self.tree_resultado.setColumnWidth(2, 130)
        self.tree_resultado.setColumnWidth(3, 140)
        left_layout.addWidget(self.tree_resultado)

        self.lbl_errores = QLabel("")
        self.lbl_errores.setStyleSheet("color: red;")
        self.lbl_errores.setWordWrap(True)
        left_layout.addWidget(self.lbl_errores)

        splitter.addWidget(left_widget)

        # --- Panel Derecho: Gráfico y Exportación de Informes ---
        right_widget = QWidget()
        right_layout = QVBoxLayout(right_widget)
        right_layout.setContentsMargins(0, 0, 0, 0)

        # Panel de control del gráfico
        group_grafico = QGroupBox("Gráfico de Distribución (Matplotlib)")
        grafico_layout = QVBoxLayout(group_grafico)

        # Selector de Sección del Gráfico
        sec_selector_layout = QHBoxLayout()
        sec_selector_layout.addWidget(QLabel("Sección a Graficar:"))
        self.combo_grafico = QComboBox()
        self.combo_grafico.addItem("Composición Salarial", "COMPOSICION")
        self.combo_grafico.addItem("Deducciones del Recibo", "RECIBO")
        self.combo_grafico.addItem("Costo Empleador", "COSTO_EMP")
        self.combo_grafico.addItem("Gráfico Custom de Distribución", "CUSTOM")
        self.combo_grafico.currentIndexChanged.connect(self._actualizar_grafico)
        sec_selector_layout.addWidget(self.combo_grafico)
        grafico_layout.addLayout(sec_selector_layout)

        # Canvas Matplotlib
        self.fig = Figure(figsize=(5, 4), dpi=90)
        self.canvas = FigureCanvas(self.fig)
        grafico_layout.addWidget(self.canvas)

        right_layout.addWidget(group_grafico)

        # Botones de exportación del Recibo actual
        group_exports = QGroupBox("Exportar Recibo")
        exports_layout = QHBoxLayout(group_exports)

        btn_pdf = QPushButton("Exportar PDF")
        btn_pdf.clicked.connect(self._exportar_recibo_pdf)
        exports_layout.addWidget(btn_pdf)

        btn_xlsx = QPushButton("Exportar Excel")
        btn_xlsx.clicked.connect(self._exportar_recibo_xlsx)
        exports_layout.addWidget(btn_xlsx)

        btn_ods = QPushButton("Exportar ODS")
        btn_ods.clicked.connect(self._exportar_recibo_ods)
        exports_layout.addWidget(btn_ods)

        right_layout.addWidget(group_exports)

        # Botones de exportación Masiva
        group_exports_masivo = QGroupBox("Exportación Masiva")
        exports_masivo_layout = QHBoxLayout(group_exports_masivo)

        btn_masivo_pdf = QPushButton("Exportación Masiva a PDF...")
        btn_masivo_pdf.clicked.connect(self._exportacion_masiva_pdf)
        exports_masivo_layout.addWidget(btn_masivo_pdf)

        right_layout.addWidget(group_exports_masivo)

        # Botonera de Emisión Histórica
        group_emision = QGroupBox("Emitir y Guardar en Historial (Snapshot)")
        emision_layout = QHBoxLayout(group_emision)

        emision_layout.addWidget(QLabel("Mes:"))
        self.inp_emit_mes = QComboBox()
        self.inp_emit_mes.addItems([str(i) for i in range(1, 13)])
        self.inp_emit_mes.setCurrentText(str(QDate.currentDate().month()))
        emision_layout.addWidget(self.inp_emit_mes)

        emision_layout.addWidget(QLabel("Año:"))
        self.inp_emit_anio = QComboBox()
        self.inp_emit_anio.addItems([str(y) for y in range(2020, 2036)])
        self.inp_emit_anio.setCurrentText(str(QDate.currentDate().year()))
        emision_layout.addWidget(self.inp_emit_anio)

        emision_layout.addWidget(QLabel("Período:"))
        self.inp_emit_periodo = QComboBox()
        emision_layout.addWidget(self.inp_emit_periodo)

        btn_emitir = QPushButton("Emitir y Guardar Recibo")
        btn_emitir.setStyleSheet("background-color: #059669; color: white; font-weight: bold;")
        btn_emitir.clicked.connect(self._emitir_y_guardar_recibo)
        emision_layout.addWidget(btn_emitir)

        right_layout.addWidget(group_emision)

        splitter.addWidget(right_widget)
        splitter.setSizes([750, 500])

        self._cargar_combo_empleados()

    @staticmethod
    def _bold_font() -> QFont:
        f = QFont()
        f.setBold(True)
        f.setPointSize(11)
        return f

    @staticmethod
    def _separador_v() -> QFrame:
        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.VLine)
        sep.setFrameShadow(QFrame.Shadow.Sunken)
        return sep

    def _cargar_combo_empleados(self):
        self.combo_empleado.clear()
        empleados = self.db.listar_empleados()
        for emp in empleados:
            self.combo_empleado.addItem(
                f"[{emp['legajo']}] {emp['nombre_completo']}", emp["id"]
            )
        if hasattr(self, "_cargar_combo_historial_empleados"):
            self._cargar_combo_historial_empleados()
        if hasattr(self, "_cargar_combo_consola_empleados"):
            self._cargar_combo_consola_empleados()

    def _on_combo_empleado_cambiado(self):
        emp_id = self.combo_empleado.currentData()
        if emp_id is None:
            self.lbl_quincena.hide()
            self.combo_quincena.hide()
            return

        self.inp_emit_periodo.clear()
        self.inp_emit_periodo.addItem("Mensual (M)", "M")
        
        empleado = self.db.obtener_empleado(emp_id)
        if empleado and empleado.get("tipo_liquidacion") == "jornal":
            quincenas = self.db.listar_quincenas_empleado(emp_id)
            self.combo_quincena.clear()
            self.combo_quincena.addItem("Q1 (Base)", "Q1")
            for q in quincenas:
                q_code = q["codigo_quincena"]
                if q_code != "Q1":
                    self.combo_quincena.addItem(q_code, q_code)
                # También agregar a las opciones de emisión
                self.inp_emit_periodo.addItem(f"Quincena {q_code}", q_code)
            self.lbl_quincena.show()
            self.combo_quincena.show()
        else:
            self.lbl_quincena.hide()
            self.combo_quincena.hide()

    def _calcular_liquidacion(self):
        emp_id = self.combo_empleado.currentData()
        if emp_id is None:
            QMessageBox.warning(self, "Error", "Seleccione un empleado.")
            return

        fecha_calc = self.inp_fecha_hoy.date().toString("yyyy-MM-dd")
        quincena = self.combo_quincena.currentData() if self.combo_quincena.isVisible() else None
        resultado = self.motor.procesar_liquidacion(emp_id, quincena_sel=quincena, fecha_calculo=fecha_calc)
        self.ultimo_resultado = resultado

        # Errores
        if resultado["errores"]:
            self.lbl_errores.setText("⚠ " + " | ".join(resultado["errores"]))
        else:
            self.lbl_errores.setText("")

        # KPIs
        ctx = resultado["contexto_final"]
        self.lbl_bruto.setText(f"Bruto: {_formato_moneda(ctx.get('bruto', 0))}")
        self.lbl_deducciones.setText(f"Deducciones: {_formato_moneda(ctx.get('total_deducciones', 0))}")
        self.lbl_neto.setText(f"Neto: {_formato_moneda(ctx.get('neto', 0))}")
        self.lbl_costo.setText(f"Costo Total: {_formato_moneda(ctx.get('costo_laboral_total', 0))}")

        # Tree
        self.tree_resultado.clear()
        secciones_info = {s["codigo"]: s["titulo"] for s in self.db.listar_secciones()}

        orden_secciones = [s["codigo"] for s in self.db.listar_secciones()]
        for s_cod in resultado["resultados_por_seccion"].keys():
            if s_cod not in orden_secciones:
                orden_secciones.append(s_cod)

        for sec_codigo in orden_secciones:
            filas = resultado["resultados_por_seccion"].get(sec_codigo, [])
            if not self.chk_debug_recibo.isChecked():
                filas_visibles = [f for f in filas if f.get("visible_recibo", 1) == 1]
            else:
                filas_visibles = filas

            if not filas_visibles:
                continue

            sec_titulo = secciones_info.get(sec_codigo, sec_codigo)
            parent = QTreeWidgetItem(self.tree_resultado, [sec_titulo, "", "", ""])
            parent_font = QFont()
            parent_font.setBold(True)
            parent_font.setPointSize(11)
            parent.setFont(0, parent_font)
            parent.setExpanded(True)

            for fila in filas_visibles:
                es_total = fila["codigo"].startswith("total_") or fila["codigo"] in (
                    "bruto", "total_deducciones", "neto",
                    "total_cargas_patronales", "costo_laboral_total",
                )

                child = QTreeWidgetItem(parent, [
                    fila["descripcion"],
                    _formato_porcentaje(fila["unidad"]) if fila["unidad"] is not None else "",
                    _formato_moneda(fila["base"]) if fila["base"] is not None else "",
                    _formato_moneda(fila["monto"]),
                ])

                for col in (1, 2, 3):
                    child.setTextAlignment(col, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)

                if es_total:
                    bold = QFont()
                    bold.setBold(True)
                    for col in range(4):
                        child.setFont(col, bold)

        self.tree_resultado.expandAll()
        
        self._actualizar_grafico()
        
        self.statusBar().showMessage(
            f"Liquidación calculada: {resultado['empleado']['nombre_completo']}", 5000
        )

    def _actualizar_grafico(self):
        """Actualiza el gráfico de torta embebido."""
        if not self.ultimo_resultado:
            self.fig.clear()
            self.canvas.draw()
            return

        self.fig.clear()
        sec_codigo = self.combo_grafico.currentData()
        ax = self.fig.add_subplot(111)

        if sec_codigo == "CUSTOM":
            filas_custom = self.ultimo_resultado.get("resultados_grafico_custom", [])
            items = [f for f in filas_custom if f["valor"] > 0]
            if not items:
                ax.text(0.5, 0.5, "Sin datos para graficar en esta sección", ha='center', va='center')
                self.canvas.draw()
                return
            labels = [f["etiqueta"] for f in items]
            valores = [f["valor"] for f in items]
        else:
            filas = self.ultimo_resultado["resultados_por_seccion"].get(sec_codigo, [])
            ignorar = ("bruto", "total_deducciones", "neto", "total_cargas_patronales", "costo_laboral_total")
            items = [f for f in filas if f["codigo"] not in ignorar and f["monto"] > 0 and f.get("visible_recibo", 1) == 1]
            if not items:
                ax.text(0.5, 0.5, "Sin datos para graficar en esta sección", ha='center', va='center')
                self.canvas.draw()
                return
            labels = [f["descripcion"] for f in items]
            valores = [f["monto"] for f in items]

        def make_autopct(values):
            def my_autopct(pct):
                total = sum(values)
                val = pct * total / 100.0
                return f'{pct:.1f}%\n(${val:,.2f})'
            return my_autopct

        wedges, texts, autotexts = ax.pie(
            valores,
            labels=labels,
            autopct=make_autopct(valores),
            startangle=140,
            textprops=dict(size=7.5)
        )
        ax.axis("equal")

        titulos = {
            "COMPOSICION": "Composición Salarial",
            "RECIBO": "Deducciones",
            "COSTO_EMP": "Cargas Patronales",
            "CUSTOM": "Distribución Custom (Fisco)"
        }
        ax.set_title(titulos.get(sec_codigo, ""), fontsize=9, fontweight='bold', pad=10)
        
        self.fig.tight_layout()
        self.canvas.draw()

    # ==================================================================
    # Acciones de Exportación del Recibo a PDF, Excel y ODS
    # ==================================================================
    def _obtener_todas_las_quincenas_en_uso(self) -> list[str]:
        cur = self.db.conn.cursor()
        rows = cur.execute("SELECT variables_calculo FROM empleados WHERE tipo_liquidacion='jornal'").fetchall()
        codigos = set()
        codigos.add("Q1")
        codigos.add("Q2")
        for r in rows:
            try:
                data = json.loads(r[0])
                if isinstance(data, dict) and "quincenas" in data:
                    for q_code in data["quincenas"].keys():
                        codigos.add(q_code)
            except Exception:
                pass
        return sorted(list(codigos))

    def _exportacion_masiva_pdf(self):
        lista_qs = self._obtener_todas_las_quincenas_en_uso()
        dial = MasivoPdfExportDialog(self, lista_qs)
        if hasattr(self, "inp_fecha_hoy"):
            dial.inp_fecha.setDate(self.inp_fecha_hoy.date())
        if dial.exec() != QDialog.DialogCode.Accepted:
            return
            
        periodo_sel = dial.combo_quincena.currentData()
        fecha_str = dial.inp_fecha.date().toString("yyyy-MM-dd")
        
        dir_path = QFileDialog.getExistingDirectory(self, "Seleccionar Carpeta para Guardar los PDFs")
        if not dir_path:
            return
            
        empleados = self.db.listar_empleados()
        if not empleados:
            QMessageBox.warning(self, "Sin Empleados", "No hay empleados registrados en la base de datos.")
            return
            
        success_count = 0
        error_count = 0
        error_msgs = []
        
        temp_chart = os.path.join(os.path.dirname(self.db.ruta_db()), "temp_chart_export_masivo.png")
        motor = MotorLiquidacion(self.db)
        
        for emp in empleados:
            legajo = emp["legajo"] or f"ID_{emp['id']}"
            nombre = emp["nombre_completo"] or "Empleado"
            es_jornal = emp["tipo_liquidacion"] == "jornal"
            
            quincenas_a_liquidar = []
            if es_jornal:
                try:
                    variables_emp = json.loads(emp["variables_calculo"] or "{}")
                except Exception:
                    variables_emp = {}
                
                if isinstance(variables_emp, dict) and "quincenas" in variables_emp:
                    qs_existentes = list(variables_emp["quincenas"].keys())
                else:
                    qs_existentes = ["Q1"]
                
                if not qs_existentes:
                    qs_existentes = ["Q1"]
                    
                if periodo_sel == "TODO":
                    quincenas_a_liquidar = qs_existentes
                elif periodo_sel == "MENSUALES":
                    quincenas_a_liquidar = []
                else:
                    if periodo_sel in qs_existentes:
                        quincenas_a_liquidar = [periodo_sel]
            else:
                # Mensual
                if periodo_sel in ("TODO", "MENSUALES"):
                    quincenas_a_liquidar = ["Mensual"]
            for q_sel in quincenas_a_liquidar:
                try:
                    q_param = q_sel if es_jornal else None
                    liq_res = motor.procesar_liquidacion(emp["id"], quincena_sel=q_param, fecha_calculo=fecha_str)
                    
                    q_suffix = f"_{q_sel}" if es_jornal else ""
                    pdf_filename = f"recibo_{legajo}{q_suffix}.pdf"
                    pdf_path = os.path.join(dir_path, pdf_filename)
                    
                    chart_generado = exporters.generar_grafico_torta(liq_res, "Composición Salarial", temp_chart)
                    
                    date_val = dial.inp_fecha.date()
                    mes_anio_dict = {
                        "mes": date_val.month(),
                        "anio": date_val.year(),
                        "periodo": q_sel if es_jornal else "M"
                    }
                    empresa_dict = self.db.obtener_empresa()
                    
                    exporters.exportar_recibo_pdf(liq_res, self.db, pdf_path, temp_chart if chart_generado else None, empresa=empresa_dict, mes_anio=mes_anio_dict)
                    success_count += 1
                except Exception as e:
                    error_count += 1
                    error_msgs.append(f"Empleado {nombre} ({legajo}) {q_sel}: {str(e)}")
                finally:
                    if os.path.exists(temp_chart):
                        try:
                            os.remove(temp_chart)
                        except Exception:
                            pass
                            
        if error_count == 0:
            QMessageBox.information(
                self, "Exportación Completada", 
                f"Se han exportado exitosamente {success_count} recibos a PDF en la carpeta:\n{dir_path}"
            )
        else:
            msg = f"Se exportaron {success_count} recibos correctamente.\n\nHubo {error_count} errores:\n"
            msg += "\n".join(error_msgs[:10])
            if len(error_msgs) > 10:
                msg += f"\n... y {len(error_msgs) - 10} errores más."
            QMessageBox.warning(self, "Exportación con Errores", msg)

    def _exportar_recibo_pdf(self):
        if not self.ultimo_resultado:
            QMessageBox.warning(self, "Error", "Debe calcular la liquidación primero.")
            return

        path, _ = QFileDialog.getSaveFileName(
            self, "Exportar Recibo a PDF",
            os.path.expanduser(f"~/recibo_{self.ultimo_resultado['empleado']['legajo']}.pdf"),
            "Documentos PDF (*.pdf)"
        )
        if not path:
            return

        temp_chart = os.path.join(os.path.dirname(self.db.ruta_db()), "temp_chart_export.png")
        chart_generado = exporters.generar_grafico_torta(self.ultimo_resultado, self.combo_grafico.currentData(), temp_chart)

        fecha_val = self.inp_fecha_hoy.date()
        mes_anio_dict = {
            "mes": fecha_val.month(),
            "anio": fecha_val.year(),
            "periodo": self.combo_quincena.currentData() if self.combo_quincena.isVisible() else "M"
        }
        empresa_dict = self.db.obtener_empresa()

        try:
            exporters.exportar_recibo_pdf(self.ultimo_resultado, self.db, path, temp_chart if chart_generado else None, empresa=empresa_dict, mes_anio=mes_anio_dict)
            QMessageBox.information(self, "Exportado", f"Recibo exportado correctamente a PDF:\n{path}")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"No se pudo generar el PDF: {e}")
        finally:
            if os.path.exists(temp_chart):
                os.remove(temp_chart)

    def _exportar_recibo_xlsx(self):
        if not self.ultimo_resultado:
            QMessageBox.warning(self, "Error", "Debe calcular la liquidación primero.")
            return

        path, _ = QFileDialog.getSaveFileName(
            self, "Exportar Recibo a Excel",
            os.path.expanduser(f"~/recibo_{self.ultimo_resultado['empleado']['legajo']}.xlsx"),
            "Archivos de Excel (*.xlsx)"
        )
        if not path:
            return

        temp_chart = os.path.join(os.path.dirname(self.db.ruta_db()), "temp_chart_export.png")
        chart_generado = exporters.generar_grafico_torta(self.ultimo_resultado, self.combo_grafico.currentData(), temp_chart)

        try:
            exporters.exportar_recibo_xlsx(self.ultimo_resultado, self.db, path, temp_chart if chart_generado else None)
            QMessageBox.information(self, "Exportado", f"Recibo exportado correctamente a Excel:\n{path}")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"No se pudo generar el archivo Excel: {e}")
        finally:
            if os.path.exists(temp_chart):
                os.remove(temp_chart)

    def _exportar_recibo_ods(self):
        if not self.ultimo_resultado:
            QMessageBox.warning(self, "Error", "Debe calcular la liquidación primero.")
            return

        path, _ = QFileDialog.getSaveFileName(
            self, "Exportar Recibo a ODS",
            os.path.expanduser(f"~/recibo_{self.ultimo_resultado['empleado']['legajo']}.ods"),
            "Planillas OpenDocument (*.ods)"
        )
        if not path:
            return

        temp_chart = os.path.join(os.path.dirname(self.db.ruta_db()), "temp_chart_export.png")
        chart_generado = exporters.generar_grafico_torta(self.ultimo_resultado, self.combo_grafico.currentData(), temp_chart)

        try:
            exporters.exportar_recibo_ods(self.ultimo_resultado, self.db, path, temp_chart if chart_generado else None)
            QMessageBox.information(self, "Exportado", f"Recibo exportado correctamente a ODS:\n{path}")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"No se pudo generar el archivo ODS: {e}")
        finally:
            if os.path.exists(temp_chart):
                os.remove(temp_chart)

    # ==================================================================
    # Acciones del Menú Archivo: Importar/Exportar DB (SQLite, Excel, CSV)
    # ==================================================================
    def _exportar_db(self):
        path, _ = QFileDialog.getSaveFileName(
            self, "Exportar Base de Datos SQLite",
            os.path.expanduser("~/liquidacion_sueldos_backup.db"),
            "SQLite Database (*.db)",
        )
        if path:
            self.db.conn.commit()
            try:
                shutil.copy2(self.db.ruta_db(), path)
                QMessageBox.information(self, "Exportado", f"Base de datos exportada a:\n{path}")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"No se pudo exportar: {e}")

    def _importar_db(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Importar Base de Datos SQLite", "",
            "SQLite Database (*.db)",
        )
        if path:
            resp = QMessageBox.question(
                self, "Confirmar Importación",
                "Esto reemplazará TODOS los datos actuales de la aplicación.\n¿Desea continuar?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if resp == QMessageBox.StandardButton.Yes:
                try:
                    self.db.cerrar()
                    shutil.copy2(path, self.db.ruta_db())
                    self.db = DatabaseManager(self.db.ruta_db())
                    self.motor = MotorLiquidacion(self.db)
                    self._cargar_lista_empleados()
                    self._cargar_combos_empleado()
                    self._cargar_tabla_categorias()
                    self._cargar_tabla_celdas()
                    self._cargar_tabla_grafico()
                    self._cargar_combo_empleados()
                    self.ultimo_resultado = None
                    self.fig.clear()
                    self.canvas.draw()
                    self.statusBar().showMessage("Base de datos SQLite importada.", 5000)
                    QMessageBox.information(self, "Importado", "Base de datos SQLite importada con éxito.")
                except Exception as e:
                    QMessageBox.critical(self, "Error", f"No se pudo importar: {e}")

    def _exportar_db_xlsx(self):
        path, _ = QFileDialog.getSaveFileName(
            self, "Exportar Base de Datos a Excel",
            os.path.expanduser("~/datos_liquidacion_sueldos.xlsx"),
            "Archivos de Excel (*.xlsx)",
        )
        if path:
            try:
                exporters.exportar_datos_xlsx(self.db, path)
                QMessageBox.information(self, "Exportado", f"Datos exportados a Excel correctamente:\n{path}")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"No se pudo exportar a Excel: {e}")

    def _importar_db_xlsx(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Importar Base de Datos desde Excel", "",
            "Archivos de Excel (*.xlsx)",
        )
        if path:
            resp = QMessageBox.question(
                self, "Confirmar Importación",
                "Esto reemplazará TODOS los datos actuales de la aplicación con los del Excel.\n¿Desea continuar?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if resp == QMessageBox.StandardButton.Yes:
                try:
                    exporters.importar_datos_xlsx(self.db, path)
                    self._cargar_lista_empleados()
                    self._cargar_combos_empleado()
                    self._cargar_tabla_categorias()
                    self._cargar_tabla_celdas()
                    self._cargar_tabla_grafico()
                    self._cargar_combo_empleados()
                    self.ultimo_resultado = None
                    self.fig.clear()
                    self.canvas.draw()
                    self.statusBar().showMessage("Base de datos importada desde Excel.", 5000)
                    QMessageBox.information(self, "Importado", "Base de datos de Excel importada con éxito.")
                except Exception as e:
                    QMessageBox.critical(self, "Error", f"No se pudo importar desde Excel:\n{e}")

    def _exportar_db_csv(self):
        directorio = QFileDialog.getExistingDirectory(
            self, "Seleccionar carpeta para exportar CSVs",
            os.path.expanduser("~")
        )
        if directorio:
            try:
                exporters.exportar_datos_csv(self.db, directorio)
                QMessageBox.information(
                    self, "Exportado",
                    f"CSVs creados en el directorio:\n{directorio}"
                )
            except Exception as e:
                QMessageBox.critical(self, "Error", f"No se pudo exportar a CSV: {e}")

    def _importar_db_csv(self):
        directorio = QFileDialog.getExistingDirectory(
            self, "Seleccionar carpeta que contiene los CSVs",
            os.path.expanduser("~")
        )
        if directorio:
            resp = QMessageBox.question(
                self, "Confirmar Importación",
                "Esto reemplazará TODOS los datos actuales de la aplicación con los del directorio de CSVs.\n¿Desea continuar?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if resp == QMessageBox.StandardButton.Yes:
                try:
                    exporters.importar_datos_csv(self.db, directorio)
                    self._cargar_lista_empleados()
                    self._cargar_combos_empleado()
                    self._cargar_tabla_categorias()
                    self._cargar_tabla_celdas()
                    self._cargar_tabla_grafico()
                    self._cargar_combo_empleados()
                    self.ultimo_resultado = None
                    self.fig.clear()
                    self.canvas.draw()
                    self.statusBar().showMessage("Base de datos importada desde CSVs.", 5000)
                    QMessageBox.information(self, "Importado", "Datos de CSVs importados con éxito.")
                except Exception as e:
                    QMessageBox.critical(self, "Error", f"No se pudo importar desde CSV:\n{e}")

    # ==================================================================
    # Acción de Riesgo: Nuevo Mes
    # ==================================================================
    def _nuevo_mes_accion_riesgo(self):
        resp = QMessageBox.warning(
            self,
            "ATENCIÓN: Acción de Riesgo",
            "Esta acción reinicializará las horas, horas extras y vacaciones a 0 para todos los empleados, "
            "y eliminará las quincenas adicionales (Q2, Q3, etc.) manteniendo únicamente la quincena base Q1.\n\n"
            "Se realizará una copia de seguridad automática de la base de datos antes de proceder.\n\n"
            "¿Desea continuar?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        if resp == QMessageBox.StandardButton.Yes:
            try:
                backup_path = self.db.reinicializar_nuevo_mes()
                
                # Recargar UI
                self._cargar_lista_empleados()
                self._cargar_combo_empleados()
                
                QMessageBox.information(
                    self,
                    "Éxito",
                    f"Se ha inicializado el nuevo mes correctamente.\n\n"
                    f"Copia de seguridad guardada en:\n{backup_path}",
                    QMessageBox.StandardButton.Ok
                )
                self.statusBar().showMessage(f"Nuevo mes inicializado. Backup en: {os.path.basename(backup_path)}", 6000)
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Ocurrió un error al reinicializar el mes o crear el backup:\n{e}")


    # ==================================================================
    # ABM de Esquemas de Cálculo
    # ==================================================================
    def _build_tab_esquemas(self):
        layout = QVBoxLayout(self.tab_esquemas)

        header = QHBoxLayout()
        header.addWidget(QLabel("<b>Esquemas de Cálculo (CRUD)</b>"))
        header.addStretch()

        btn_add = QPushButton("Agregar Esquema")
        btn_add.clicked.connect(self._agregar_esquema)
        header.addWidget(btn_add)

        btn_del = QPushButton("Eliminar Seleccionado")
        btn_del.clicked.connect(self._eliminar_esquema)
        header.addWidget(btn_del)

        btn_save = QPushButton("Guardar Cambios")
        btn_save.clicked.connect(self._guardar_esquemas)
        header.addWidget(btn_save)

        layout.addLayout(header)

        self.tabla_esquemas = QTableWidget()
        self.tabla_esquemas.setAlternatingRowColors(True)
        self.tabla_esquemas.setColumnCount(2)
        self.tabla_esquemas.setHorizontalHeaderLabels(["Código del Esquema", "Nombre descriptivo"])
        self.tabla_esquemas.horizontalHeader().setStretchLastSection(True)
        self.tabla_esquemas.verticalHeader().setVisible(False)
        self.tabla_esquemas.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        layout.addWidget(self.tabla_esquemas)

        self._cargar_tabla_esquemas()

    def _cargar_tabla_esquemas(self):
        esqs = self.db.listar_esquemas()
        self.tabla_esquemas.setRowCount(len(esqs))
        for i, esq in enumerate(esqs):
            self.tabla_esquemas.setItem(i, 0, QTableWidgetItem(esq["codigo"]))
            self.tabla_esquemas.setItem(i, 1, QTableWidgetItem(esq["nombre"]))
            
            # Guardar el código original oculto para saber si se modificó la PK
            item_codigo = self.tabla_esquemas.item(i, 0)
            if item_codigo:
                item_codigo.setData(Qt.ItemDataRole.UserRole, esq["codigo"])

        self.tabla_esquemas.resizeColumnsToContents()

    def _agregar_esquema(self):
        row = self.tabla_esquemas.rowCount()
        self.tabla_esquemas.insertRow(row)
        self.tabla_esquemas.setItem(row, 0, QTableWidgetItem(f"NUEVO_ESQ_{row + 1}"))
        self.tabla_esquemas.setItem(row, 1, QTableWidgetItem("Nuevo Esquema de Cálculo"))
        
        # Registrar como nuevo (sin original_codigo)
        item_codigo = self.tabla_esquemas.item(row, 0)
        if item_codigo:
            item_codigo.setData(Qt.ItemDataRole.UserRole, None)
            
        self.tabla_esquemas.selectRow(row)

    def _eliminar_esquema(self):
        row = self.tabla_esquemas.currentRow()
        if row < 0:
            return
            
        item_codigo = self.tabla_esquemas.item(row, 0)
        if not item_codigo:
            return
            
        orig_codigo = item_codigo.data(Qt.ItemDataRole.UserRole)
        
        if not orig_codigo:
            # Aún no se ha guardado en DB, simplemente removemos la fila de la tabla
            self.tabla_esquemas.removeRow(row)
            return
            
        resp = QMessageBox.question(
            self, "Confirmar",
            f"¿Está seguro de que desea eliminar el esquema '{orig_codigo}'?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if resp == QMessageBox.StandardButton.Yes:
            try:
                self.db.eliminar_esquema(orig_codigo)
                self._cargar_tabla_esquemas()
                self._recargar_combos_esquemas()
                self.statusBar().showMessage(f"Esquema '{orig_codigo}' eliminado.", 4000)
            except Exception as e:
                QMessageBox.critical(self, "Error al eliminar", str(e))

    def _guardar_esquemas(self):
        errores = []
        for i in range(self.tabla_esquemas.rowCount()):
            item_codigo = self.tabla_esquemas.item(i, 0)
            item_nombre = self.tabla_esquemas.item(i, 1)
            
            if not item_codigo or not item_nombre:
                continue
                
            nuevo_codigo = item_codigo.text().strip().upper()
            nombre = item_nombre.text().strip()
            orig_codigo = item_codigo.data(Qt.ItemDataRole.UserRole)
            
            if not nuevo_codigo:
                errores.append(f"Fila {i+1}: El código del esquema no puede estar vacío.")
                continue
            if not nombre:
                errores.append(f"Fila {i+1}: El nombre del esquema no puede estar vacío.")
                continue
                
            try:
                self.db.guardar_esquema(orig_codigo, nuevo_codigo, nombre)
            except Exception as e:
                errores.append(f"Fila {i+1} ({nuevo_codigo}): {e}")
                
        if errores:
            QMessageBox.warning(self, "Errores al guardar", "\n".join(errores))
        else:
            self.statusBar().showMessage("Esquemas de cálculo guardados.", 4000)
            
        self._cargar_tabla_esquemas()
        self._recargar_combos_esquemas()

    def _recargar_combos_esquemas(self):
        esquemas = self.db.listar_esquemas()
        
        # 1. Combo en el filtro de la estructura de recibos
        current_esq_filtro = self.combo_filter_esquema.currentData()
        self.combo_filter_esquema.blockSignals(True)
        self.combo_filter_esquema.clear()
        for esq in esquemas:
            self.combo_filter_esquema.addItem(esq["nombre"], esq["codigo"])
        idx = self.combo_filter_esquema.findData(current_esq_filtro)
        if idx >= 0:
            self.combo_filter_esquema.setCurrentIndex(idx)
        else:
            self.combo_filter_esquema.setCurrentIndex(0)
        self.combo_filter_esquema.blockSignals(False)
        
        # 2. Combo en el formulario de empleados
        current_emp_esq = self.inp_esquema.currentData()
        self.inp_esquema.blockSignals(True)
        self.inp_esquema.clear()
        for esq in esquemas:
            self.inp_esquema.addItem(esq["nombre"], esq["codigo"])
        idx = self.inp_esquema.findData(current_emp_esq)
        if idx >= 0:
            self.inp_esquema.setCurrentIndex(idx)
        else:
            self.inp_esquema.setCurrentIndex(0)
        self.inp_esquema.blockSignals(False)

        # 3. Combo en el filtro del gráfico custom
        current_esq_grafico = self.combo_filter_esquema_g.currentData()
        self.combo_filter_esquema_g.blockSignals(True)
        self.combo_filter_esquema_g.clear()
        for esq in esquemas:
            self.combo_filter_esquema_g.addItem(esq["nombre"], esq["codigo"])
        idx = self.combo_filter_esquema_g.findData(current_esq_grafico)
        if idx >= 0:
            self.combo_filter_esquema_g.setCurrentIndex(idx)
        else:
            self.combo_filter_esquema_g.setCurrentIndex(0)
        self.combo_filter_esquema_g.blockSignals(False)

    def _cambiar_modo(self, modo):
        """Método auxiliar llamado por las acciones del menú"""
        self.modo_actual = modo
        self._actualizar_modo_vista()

    def _actualizar_modo_vista(self):
        is_user = self.modo_actual == "Usuario"
        habilitar_ia = self.db.obtener_config("habilitar_asistente_ia", "false").lower() == "true"
        
        # Guardar pestaña actual
        current_tab = self.tabs.currentWidget()
        
        # Limpiar y reconstruir tabs visibles
        self.tabs.clear()
        
        if is_user:
            # En modo Usuario solo mostramos Empleados, Campos Globales, Vista Previa, Historial e Intérprete
            self.tabs.addTab(self.tab_empleados, "Empleados")
            self.tabs.addTab(self.tab_globales, "Campos Globales")
            self.tabs.addTab(self.tab_preview, "Vista Previa")
            self.tabs.addTab(self.tab_historial, "Historial de Recibos")
            self.tabs.addTab(self.tab_consola, "Consola de Fórmulas")
            if habilitar_ia:
                self.tabs.addTab(self.tab_asistente_ia, "🤖 Asistente IA")
            
            # Controles Empleados
            if hasattr(self, "btn_nuevo"): self.btn_nuevo.setVisible(False)
            if hasattr(self, "btn_eliminar"): self.btn_eliminar.setVisible(False)
            if hasattr(self, "btn_add_var"): self.btn_add_var.setVisible(False)
            if hasattr(self, "btn_add_quincena"): self.btn_add_quincena.setVisible(False)
            if hasattr(self, "btn_del_quincena"): self.btn_del_quincena.setVisible(False)
                
            # Controles Globales (El botón Nuevo mes ahora es una Acción del Menú)
            if hasattr(self, "btn_add_global"): self.btn_add_global.setVisible(False)
            if hasattr(self, "btn_del_global"): self.btn_del_global.setVisible(False)
            if hasattr(self, "btn_nuevo_mes"): self.btn_nuevo_mes.setVisible(False) # Ocultar en el menú
        else:
            # En modo Administrador mostramos todo lo habilitado
            for widget, name in self.all_tabs:
                if widget == getattr(self, "tab_asistente_ia", None) and not habilitar_ia:
                    continue
                self.tabs.addTab(widget, name)
                
            if hasattr(self, "btn_nuevo"): self.btn_nuevo.setVisible(True)
            if hasattr(self, "btn_eliminar"): self.btn_eliminar.setVisible(True)
            if hasattr(self, "btn_add_var"): self.btn_add_var.setVisible(True)
                
            is_jornal = hasattr(self, "inp_tipo") and self.inp_tipo.currentText() == "jornal"
            if hasattr(self, "btn_add_quincena"): self.btn_add_quincena.setVisible(is_jornal)
            if hasattr(self, "btn_del_quincena"): self.btn_del_quincena.setVisible(is_jornal)
                
            if hasattr(self, "btn_add_global"): self.btn_add_global.setVisible(True)
            if hasattr(self, "btn_del_global"): self.btn_del_global.setVisible(True)
            if hasattr(self, "btn_nuevo_mes"): self.btn_nuevo_mes.setVisible(True) # Mostrar en el menú
                
        # Seleccionar la pestaña anterior si sigue estando
        idx = self.tabs.indexOf(current_tab)
        if idx >= 0:
            self.tabs.setCurrentIndex(idx)
        else:
            self.tabs.setCurrentIndex(0)
            
        # Recargar para aplicar restricciones de lectura
        self._cargar_tabla_globales()
        if hasattr(self, "lista_empleados") and self.lista_empleados.currentRow() >= 0:
            self._on_empleado_seleccionado(self.lista_empleados.currentRow())

    # ==================================================================
    # PESTAÑA EMPRESA (Singleton CRUD)
    # ==================================================================
    def _build_tab_empresa(self):
        layout = QVBoxLayout(self.tab_empresa)
        
        group = QGroupBox("Datos de la Empresa (para la Cabecera del Recibo)")
        form = QFormLayout(group)
        
        self.inp_emp_razon = QLineEdit()
        form.addRow("Razón Social:", self.inp_emp_razon)
        
        self.inp_emp_direccion = QLineEdit()
        form.addRow("Dirección:", self.inp_emp_direccion)
        
        self.inp_emp_cuit = QLineEdit()
        self.inp_emp_cuit.setPlaceholderText("Ej: 30-12345678-9")
        form.addRow("CUIT:", self.inp_emp_cuit)
        
        self.inp_emp_lugar = QLineEdit()
        self.inp_emp_lugar.setPlaceholderText("Ej: C.A.B.A.")
        form.addRow("Lugar de Pago:", self.inp_emp_lugar)
        
        btn_guardar = QPushButton("Guardar Datos de Empresa")
        btn_guardar.setStyleSheet("font-weight: bold; background-color: #2563EB; color: white;")
        btn_guardar.clicked.connect(self._guardar_empresa)
        
        layout.addWidget(group)
        layout.addWidget(btn_guardar)
        layout.addStretch()
        
        self._cargar_datos_empresa()

    def _cargar_datos_empresa(self):
        emp = self.db.obtener_empresa()
        self.inp_emp_razon.setText(emp.get("razon_social") or "")
        self.inp_emp_direccion.setText(emp.get("direccion") or "")
        self.inp_emp_cuit.setText(emp.get("cuit") or "")
        self.inp_emp_lugar.setText(emp.get("lugar_de_pago") or "")

    def _guardar_empresa(self):
        razon = self.inp_emp_razon.text().strip()
        direccion = self.inp_emp_direccion.text().strip()
        cuit = self.inp_emp_cuit.text().strip()
        lugar = self.inp_emp_lugar.text().strip()
        
        self.db.guardar_empresa(razon, direccion, cuit, lugar)
        self.statusBar().showMessage("Datos de la empresa guardados correctamente.", 4000)

    # ==================================================================
    # EMISIÓN DE RECIBO HISTÓRICO
    # ==================================================================
    def _emitir_y_guardar_recibo(self):
        if not hasattr(self, "ultimo_resultado") or not self.ultimo_resultado:
            QMessageBox.warning(self, "Error", "Debe calcular la liquidación primero.")
            return

        mes = int(self.inp_emit_mes.currentText())
        anio = int(self.inp_emit_anio.currentText())
        periodo = self.inp_emit_periodo.currentData()
        emp = self.ultimo_resultado["empleado"]

        resp = QMessageBox.question(
            self, "Confirmar Emisión",
            f"¿Desea emitir y guardar el recibo para {emp['nombre_completo']} del período {periodo} ({mes}/{anio})?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if resp == QMessageBox.StandardButton.Yes:
            try:
                rec_id = self.motor.persistir_liquidacion_actual(
                    self.ultimo_resultado, mes, anio, periodo
                )
                self.statusBar().showMessage(f"Recibo emitido con éxito. ID: {rec_id}", 5000)
                QMessageBox.information(
                    self, "Éxito",
                    f"Recibo de {emp['nombre_completo']} para {mes}/{anio} ({periodo}) guardado en el historial."
                )
                self._cargar_historial_recibos()
            except Exception as e:
                QMessageBox.critical(self, "Error", f"No se pudo guardar el recibo: {e}")

    # ==================================================================
    # PESTAÑA HISTORIAL DE RECIBOS
    # ==================================================================
    def _build_tab_historial(self):
        layout = QVBoxLayout(self.tab_historial)
        
        # Filtros superiores
        top = QHBoxLayout()
        top.addWidget(QLabel("Empleado:"))
        self.combo_hist_empleado = QComboBox()
        self.combo_hist_empleado.setMinimumWidth(200)
        self.combo_hist_empleado.currentIndexChanged.connect(self._cargar_historial_recibos)
        top.addWidget(self.combo_hist_empleado)
        top.addStretch()
        layout.addLayout(top)
        
        # Splitter para separar la tabla de la vista de detalle
        splitter = QSplitter(Qt.Orientation.Horizontal)
        layout.addWidget(splitter)
        layout.setStretchFactor(splitter, 1)
        
        # Tabla de Recibos
        self.table_historial = QTableWidget()
        self.table_historial.setColumnCount(6)
        self.table_historial.setHorizontalHeaderLabels(["ID", "Mes", "Año", "Período", "Esquema", "Fecha Emisión"])
        self.table_historial.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table_historial.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.table_historial.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.table_historial.itemSelectionChanged.connect(self._on_recibo_seleccionado)
        self.table_historial.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        splitter.addWidget(self.table_historial)
        
        # Panel Derecho: Detalle del Recibo
        right = QWidget()
        right_layout = QVBoxLayout(right)
        right_layout.setContentsMargins(0, 0, 0, 0)
        
        right_layout.addWidget(QLabel("<b>Detalles del Recibo Histórico:</b>"))
        
        self.tree_hist_detalle = QTreeWidget()
        self.tree_hist_detalle.setColumnCount(2)
        self.tree_hist_detalle.setHeaderLabels(["Concepto / Variable", "Valor"])
        self.tree_hist_detalle.header().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        right_layout.addWidget(self.tree_hist_detalle)
        
        btn_bar = QHBoxLayout()
        self.btn_hist_pdf = QPushButton("Exportar PDF")
        self.btn_hist_pdf.clicked.connect(self._exportar_recibo_historico_pdf)
        self.btn_hist_pdf.setEnabled(False)
        btn_bar.addWidget(self.btn_hist_pdf)
        
        self.btn_hist_eliminar = QPushButton("Eliminar del Historial")
        self.btn_hist_eliminar.clicked.connect(self._eliminar_recibo_historico)
        self.btn_hist_eliminar.setEnabled(False)
        btn_bar.addWidget(self.btn_hist_eliminar)
        
        right_layout.addLayout(btn_bar)
        splitter.addWidget(right)
        
        splitter.setSizes([600, 400])
        self._selected_recibo_data = None
        self._cargar_combo_historial_empleados()

    def _cargar_combo_historial_empleados(self):
        if not hasattr(self, "combo_hist_empleado"):
            return
        self.combo_hist_empleado.blockSignals(True)
        self.combo_hist_empleado.clear()
        empleados = self.db.listar_empleados()
        for emp in empleados:
            self.combo_hist_empleado.addItem(
                f"[{emp['legajo']}] {emp['nombre_completo']}", emp["id"]
            )
        self.combo_hist_empleado.blockSignals(False)
        self._cargar_historial_recibos()

    def _cargar_historial_recibos(self):
        emp_id = self.combo_hist_empleado.currentData()
        self.table_historial.setRowCount(0)
        self.tree_hist_detalle.clear()
        self.btn_hist_pdf.setEnabled(False)
        self.btn_hist_eliminar.setEnabled(False)
        self._selected_recibo_data = None
        
        if emp_id is None:
            return
            
        recibos = self.db.listar_recibos_empleado(emp_id)
        self.table_historial.setRowCount(len(recibos))
        
        for row_i, r in enumerate(recibos):
            self.table_historial.setItem(row_i, 0, QTableWidgetItem(str(r["id"])))
            self.table_historial.setItem(row_i, 1, QTableWidgetItem(str(r["mes"])))
            self.table_historial.setItem(row_i, 2, QTableWidgetItem(str(r["anio"])))
            self.table_historial.setItem(row_i, 3, QTableWidgetItem(str(r["periodo"])))
            self.table_historial.setItem(row_i, 4, QTableWidgetItem(str(r["esquema_codigo"])))
            self.table_historial.setItem(row_i, 5, QTableWidgetItem(str(r["fecha_emision"])))

    def _on_recibo_seleccionado(self):
        row = self.table_historial.currentRow()
        if row < 0:
            self.tree_hist_detalle.clear()
            self.btn_hist_pdf.setEnabled(False)
            self.btn_hist_eliminar.setEnabled(False)
            self._selected_recibo_data = None
            return
            
        recibo_id = int(self.table_historial.item(row, 0).text())
        recibo = self.db.obtener_recibo(recibo_id)
        if not recibo:
            return
            
        self._selected_recibo_data = recibo
        self.btn_hist_pdf.setEnabled(True)
        self.btn_hist_eliminar.setEnabled(True)
        
        self.tree_hist_detalle.clear()
        try:
            datos = json.loads(recibo["datos_json"])
        except Exception:
            datos = {}
            
        for k in sorted(datos.keys()):
            val = datos[k]
            val_str = _formato_moneda(val) if isinstance(val, (int, float)) and not isinstance(val, bool) else str(val)
            QTreeWidgetItem(self.tree_hist_detalle, [k, val_str])

    def _eliminar_recibo_historico(self):
        if not hasattr(self, "_selected_recibo_data") or not self._selected_recibo_data:
            return
            
        r = self._selected_recibo_data
        resp = QMessageBox.question(
            self, "Confirmar Eliminación",
            f"¿Desea eliminar el recibo ID {r['id']} ({r['mes']}/{r['anio']}) del historial?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if resp == QMessageBox.StandardButton.Yes:
            self.db.eliminar_recibo(r["id"])
            self.statusBar().showMessage("Recibo eliminado del historial.", 4000)
            self._cargar_historial_recibos()

    def _exportar_recibo_historico_pdf(self):
        if not hasattr(self, "_selected_recibo_data") or not self._selected_recibo_data:
            return
            
        r = self._selected_recibo_data
        emp_id = r["empleado_id"]
        emp = self.db.obtener_empleado(emp_id)
        if not emp:
            QMessageBox.warning(self, "Error", "El empleado ya no existe en el sistema.")
            return
            
        path, _ = QFileDialog.getSaveFileName(
            self, "Exportar Recibo Histórico a PDF",
            os.path.expanduser(f"~/recibo_{emp['legajo']}_{r['anio']}_{r['mes']}_{r['periodo']}.pdf"),
            "Documentos PDF (*.pdf)"
        )
        if not path:
            return
            
        try:
            datos = json.loads(r["datos_json"])
        except Exception:
            datos = {}
            
        # Reconstruir secciones del recibo a partir de las celdas actuales y los valores guardados
        celdas = self.db.listar_celdas_por_esquema(r["esquema_codigo"])
        
        resultados_por_seccion = {}
        for c in celdas:
            cod = c["codigo_variable"]
            sec = c["seccion_codigo"]
            if cod in datos:
                fila = {
                    "codigo": cod,
                    "descripcion": c["descripcion"],
                    "unidad": None,
                    "base": None,
                    "monto": datos[cod],
                    "visible_recibo": c.get("visible_recibo", 1)
                }
                resultados_por_seccion.setdefault(sec, []).append(fila)
                
        liq_res_mock = {
            "empleado": emp,
            "resultados_por_seccion": resultados_por_seccion,
            "contexto_final": datos,
            "quincena_sel": r["periodo"] if r["periodo"] in ("Q1", "Q2") else None
        }
        
        empresa = self.db.obtener_empresa()
        mes_anio = {"mes": r["mes"], "anio": r["anio"], "periodo": r["periodo"]}
        
        try:
            exporters.exportar_recibo_pdf(liq_res_mock, self.db, path, None, empresa=empresa, mes_anio=mes_anio)
            QMessageBox.information(self, "Exportado", f"Recibo histórico exportado a PDF:\n{path}")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"No se pudo generar el PDF histórico: {e}")

    # ==================================================================
    # PESTAÑA CONSOLA DE FÓRMULAS (Intérprete / Sandbox)
    # ==================================================================
    def _build_tab_consola(self):
        layout = QVBoxLayout(self.tab_consola)
        
        # Panel superior: Seleccionar Empleado y Fecha
        top = QHBoxLayout()
        top.addWidget(QLabel("<b>Empleado:</b>"))
        self.combo_consola_empleado = QComboBox()
        self.combo_consola_empleado.setMinimumWidth(200)
        self.combo_consola_empleado.currentIndexChanged.connect(self._on_combo_consola_empleado_cambiado)
        top.addWidget(self.combo_consola_empleado)
        
        self.lbl_consola_quincena = QLabel("<b>Quincena:</b>")
        top.addWidget(self.lbl_consola_quincena)
        self.combo_consola_quincena = QComboBox()
        top.addWidget(self.combo_consola_quincena)
        
        self.lbl_consola_quincena.hide()
        self.combo_consola_quincena.hide()

        top.addWidget(QLabel("<b>Fecha de Cálculo:</b>"))
        self.inp_consola_fecha = QDateEdit()
        self.inp_consola_fecha.setCalendarPopup(True)
        self.inp_consola_fecha.setDisplayFormat("yyyy-MM-dd")
        self.inp_consola_fecha.setDate(QDate.currentDate())
        top.addWidget(self.inp_consola_fecha)
        top.addStretch()
        layout.addLayout(top)
        
        # Grupo de Entrada de Expresión
        group_input = QGroupBox("Expresión / Fórmula a Evaluar")
        input_layout = QHBoxLayout(group_input)
        
        self.inp_consola_formula = QLineEdit()
        self.inp_consola_formula.setPlaceholderText("Ej: maximo_semestre('bruto', 1, 2025) * 0.5")
        input_layout.addWidget(self.inp_consola_formula)
        
        btn_asist = QPushButton("Asistente...")
        btn_asist.clicked.connect(self._consola_abrir_asistente)
        input_layout.addWidget(btn_asist)
        
        btn_eval = QPushButton("Evaluar")
        btn_eval.setStyleSheet("font-weight: bold; background-color: #2563EB; color: white;")
        btn_eval.clicked.connect(self._consola_evaluar)
        input_layout.addWidget(btn_eval)
        
        layout.addWidget(group_input)
        
        # Grupo de Salida de Resultados
        group_output = QGroupBox("Resultado / Consola de Depuración")
        output_layout = QVBoxLayout(group_output)
        
        self.txt_consola_output = QTextEdit()
        self.txt_consola_output.setReadOnly(True)
        self.txt_consola_output.setStyleSheet("font-family: monospace; font-size: 12px;")
        output_layout.addWidget(self.txt_consola_output)
        
        layout.addWidget(group_output)
        
        # Cargar combos
        self._cargar_combo_consola_empleados()

    def _on_combo_consola_empleado_cambiado(self):
        emp_id = self.combo_consola_empleado.currentData()
        if emp_id is None:
            self.lbl_consola_quincena.hide()
            self.combo_consola_quincena.hide()
            return
            
        empleado = self.db.obtener_empleado(emp_id)
        if empleado and empleado.get("tipo_liquidacion") == "jornal":
            quincenas = self.db.listar_quincenas_empleado(emp_id)
            self.combo_consola_quincena.clear()
            self.combo_consola_quincena.addItem("Q1 (Base)", "Q1")
            for q in quincenas:
                q_code = q["codigo_quincena"]
                if q_code != "Q1":
                    self.combo_consola_quincena.addItem(q_code, q_code)
            self.lbl_consola_quincena.show()
            self.combo_consola_quincena.show()
        else:
            self.lbl_consola_quincena.hide()
            self.combo_consola_quincena.hide()

    def _cargar_combo_consola_empleados(self):
        if not hasattr(self, "combo_consola_empleado"):
            return
        self.combo_consola_empleado.blockSignals(True)
        self.combo_consola_empleado.clear()
        empleados = self.db.listar_empleados()
        for emp in empleados:
            self.combo_consola_empleado.addItem(
                f"[{emp['legajo']}] {emp['nombre_completo']}", emp["id"]
            )
        self.combo_consola_empleado.blockSignals(False)
        self._on_combo_consola_empleado_cambiado()

    def _consola_abrir_asistente(self):
        self._abrir_asistente_variables(self.inp_consola_formula)

    def _consola_evaluar(self):
        self.txt_consola_output.clear()
        emp_id = self.combo_consola_empleado.currentData()
        if emp_id is None:
            self.txt_consola_output.append("Error: Seleccione un empleado.")
            return
            
        formula = self.inp_consola_formula.text().strip()
        if not formula:
            self.txt_consola_output.append("Error: Ingrese una fórmula para evaluar.")
            return
            
        fecha_calc = self.inp_consola_fecha.date().toString("yyyy-MM-dd")
        quincena = self.combo_consola_quincena.currentData() if self.combo_consola_quincena.isVisible() else None
        
        self.txt_consola_output.append(f"--- Evaluando Expresión ---")
        self.txt_consola_output.append(f"Fórmula: {formula}")
        self.txt_consola_output.append(f"Empleado ID: {emp_id}")
        self.txt_consola_output.append(f"Quincena: {quincena}")
        self.txt_consola_output.append(f"Fecha Cálculo: {fecha_calc}")
        self.txt_consola_output.append("----------------------------\n")
        
        logs_historicos = []
        
        try:
            # Calculamos la liquidación actual del mes
            resultado = self.motor.procesar_liquidacion(emp_id, quincena_sel=quincena, fecha_calculo=fecha_calc)
            contexto = resultado["contexto_final"]
            
            from simpleeval import SimpleEval
            evaluador = SimpleEval()
            # Copiar operadores y funciones registradas en el motor
            evaluador.operators = self.motor._evaluador.operators
            evaluador.functions = dict(self.motor._evaluador.functions)
            evaluador.names = contexto
            
            def log_sumatoria_mes(codigo_variable, mes, anio):
                recibos = self.db.buscar_recibos(emp_id, int(mes), int(anio))
                total = 0.0
                for r in recibos:
                    try:
                        datos = json.loads(r["datos_json"])
                        val = datos.get(str(codigo_variable), 0.0)
                        if isinstance(val, (int, float)):
                            total += val
                    except Exception:
                        pass
                logs_historicos.append(f"sumatoria_mes('{codigo_variable}', {mes}, {anio}): Leyó {len(recibos)} recibo(s). Suma acumulada = {_formato_moneda(total)}")
                return total

            def log_maximo_semestre(codigo_variable, semestre, anio):
                semestre = int(semestre)
                anio = int(anio)
                meses_rango = range(1, 7) if semestre == 1 else range(7, 13)
                max_val = 0.0
                logs_historicos.append(f"maximo_semestre('{codigo_variable}', semestre={semestre}, año={anio}):")
                for m in meses_rango:
                    suma_mes = log_sumatoria_mes(codigo_variable, m, anio)
                    if suma_mes > max_val:
                        max_val = suma_mes
                logs_historicos.append(f" -> Valor máximo del semestre = {_formato_moneda(max_val)}")
                return max_val

            def log_promedio_ultimos_n_meses(codigo_variable, meses_hacia_atras, mes_actual, anio_actual):
                meses_hacia_atras = int(meses_hacia_atras)
                mes_actual = int(mes_actual)
                anio_actual = int(anio_actual)
                valores = []
                m, a = mes_actual, anio_actual
                logs_historicos.append(f"promedio_ultimos_n_meses('{codigo_variable}', meses={meses_hacia_atras}, desde={mes_actual}/{anio_actual}):")
                for _ in range(meses_hacia_atras):
                    m -= 1
                    if m < 1:
                        m = 12
                        a -= 1
                    val = log_sumatoria_mes(codigo_variable, m, a)
                    valores.append(val)
                prom = sum(valores) / len(valores) if valores else 0.0
                logs_historicos.append(f" -> Promedio de los {meses_hacia_atras} meses = {_formato_moneda(prom)}")
                return prom

            def log_dias_trabajados_semestre(semestre, anio):
                semestre = int(semestre)
                anio = int(anio)
                f_ing_str = contexto.get("fecha_ingreso", "2020-01-01")
                try:
                    from datetime import datetime, date
                    f_ing = datetime.strptime(str(f_ing_str), "%Y-%m-%d").date()
                except Exception:
                    f_ing = date(2020, 1, 1)

                if semestre == 1:
                    inicio_sem = date(anio, 1, 1)
                    fin_sem = date(anio, 6, 30)
                else:
                    inicio_sem = date(anio, 7, 1)
                    fin_sem = date(anio, 12, 31)

                if f_ing > fin_sem:
                    val = 0
                else:
                    inicio_real = max(f_ing, inicio_sem)
                    val = (fin_sem - inicio_real).days + 1
                logs_historicos.append(f"dias_trabajados_semestre(semestre={semestre}, año={anio}): Fecha ingreso = {f_ing_str} -> Días calculados = {val}")
                return val

            evaluador.functions.update({
                "sumatoria_mes": log_sumatoria_mes,
                "maximo_semestre": log_maximo_semestre,
                "promedio_ultimos_n_meses": log_promedio_ultimos_n_meses,
                "dias_trabajados_semestre": log_dias_trabajados_semestre,
            })
            
            res = evaluador.eval(formula)
            
            if logs_historicos:
                self.txt_consola_output.append("<b>Trazas de Consulta Histórica:</b>")
                for log in logs_historicos:
                    self.txt_consola_output.append(f"  {log}")
                self.txt_consola_output.append("")
                
            res_str = ""
            if isinstance(res, (int, float)) and not isinstance(res, bool):
                res_str = f"<b>RESULTADO:</b> <span style='color: #10B981; font-size: 14px;'>{_formato_moneda(res)}</span>  (Numérico: {res})"
            else:
                res_str = f"<b>RESULTADO:</b> <span style='color: #10B981; font-size: 14px;'>{res}</span>  (Tipo: {type(res).__name__})"
                
            self.txt_consola_output.append(res_str)
            
        except Exception as e:
            self.txt_consola_output.append(f"<span style='color: #EF4444;'><b>Error de Evaluación:</b> {e}</span>")

    # ==================================================================
    # PESTAÑA ASISTENTE IA (GEMINI API)
    # ==================================================================
    def _build_tab_asistente_ia(self):
        layout = QVBoxLayout(self.tab_asistente_ia)

        # Header / Banner
        header = QHBoxLayout()
        lbl_title = QLabel("<b>🤖 Asistente Inteligente MiniERP & Liquidación (Google Gemini API)</b>")
        lbl_title.setStyleSheet("font-size: 14px;")
        header.addWidget(lbl_title)
        header.addStretch()

        btn_limpiar_chat = QPushButton("Limpiar Chat")
        btn_limpiar_chat.clicked.connect(self._limpiar_chat_ia)
        header.addWidget(btn_limpiar_chat)
        layout.addLayout(header)

        # Chat Log Viewer (HTML Formatted)
        self.txt_chat_log = QTextEdit()
        self.txt_chat_log.setReadOnly(True)
        self.txt_chat_log.setStyleSheet("""
            QTextEdit {
                background-color: #1F2937;
                color: #F3F4F6;
                font-family: 'Segoe UI', sans-serif;
                font-size: 13px;
                border: 1px solid #374151;
                border-radius: 6px;
                padding: 10px;
            }
        """)
        layout.addWidget(self.txt_chat_log)

        # Mensaje de bienvenida inicial
        self.historial_gemini = []
        self._append_chat_message("system", "<b>¡Hola! Bienvenido al Asistente IA de Liquidación de Sueldos y MiniERP.</b><br>Puedo ayudarte a crear esquemas de cálculo, agregar conceptos, registrar empleados, definir secciones o explicar fórmulas argentinas.<br><i>Sugerencia:</i> Podés usar las tarjetas rápidas de abajo o escribir directamente tu consulta.")

        # Preset Prompts Quick Bar
        presets_group = QGroupBox("Sugerencias de Peticiones Rápidas")
        presets_layout = QHBoxLayout(presets_group)

        btn_p1 = QPushButton("💡 Crear Esquema COMERCIO")
        btn_p1.clicked.connect(lambda: self._enviar_prompt_ia("Por favor crea un nuevo esquema de cálculo llamado COMERCIO (Convenio Empleados de Comercio) con conceptos para sueldo básico y presentismo (8.33%)."))

        btn_p2 = QPushButton("💡 Registrar empleado Carlos Gardel")
        btn_p2.clicked.connect(lambda: self._enviar_prompt_ia("Por favor registra un nuevo empleado mensual llamado Carlos Gardel con legajo 0100, asignado al esquema MENSUAL y sueldo básico de 650000."))

        btn_p3 = QPushButton("💡 Explicar cálculo del SAC (Aguinaldo)")
        btn_p3.clicked.connect(lambda: self._enviar_prompt_ia("Explicame detalladamente cómo se calcula el Sueldo Anual Complementario (SAC / Aguinaldo) en Argentina según la ley y cómo se expresaría la fórmula en el sistema."))

        btn_p4 = QPushButton("💡 Resumen del estado actual del ERP")
        btn_p4.clicked.connect(lambda: self._enviar_prompt_ia("Por favor consulta el estado actual del ERP y dame un resumen de empleados, esquemas y secciones configuradas."))

        presets_layout.addWidget(btn_p1)
        presets_layout.addWidget(btn_p2)
        presets_layout.addWidget(btn_p3)
        presets_layout.addWidget(btn_p4)
        layout.addWidget(presets_group)

        # Bar Input bottom
        input_bar = QHBoxLayout()
        self.inp_prompt_ia = QLineEdit()
        self.inp_prompt_ia.setPlaceholderText("Escribe tu instrucción para la IA (ej: 'Crear esquema UOCRA con básico e incentivo')...")
        self.inp_prompt_ia.returnPressed.connect(self._enviar_prompt_ia)
        input_bar.addWidget(self.inp_prompt_ia)

        self.btn_enviar_ia = QPushButton("Enviar (Enter)")
        self.btn_enviar_ia.clicked.connect(self._enviar_prompt_ia)
        input_bar.addWidget(self.btn_enviar_ia)

        layout.addLayout(input_bar)

    def _append_chat_message(self, sender: str, text_html: str):
        if sender == "user":
            color_header = "#60A5FA"
            title = "👤 Usuario"
        elif sender == "system":
            color_header = "#10B981"
            title = "🤖 Asistente Gemini"
        else:
            color_header = "#F59E0B"
            title = "⚙ Sistema"

        formatted = f"""
        <div style="margin-bottom: 12px; padding: 8px; border-radius: 6px; background-color: #111827;">
            <b style="color: {color_header}; font-size: 13px;">{title}:</b><br>
            <div style="color: #E5E7EB; margin-top: 4px;">{text_html}</div>
        </div>
        """
        self.txt_chat_log.append(formatted)
        sb = self.txt_chat_log.verticalScrollBar()
        sb.setValue(sb.maximum())

    def _limpiar_chat_ia(self):
        self.txt_chat_log.clear()
        self.historial_gemini = []
        self._append_chat_message("system", "Historial de conversación reiniciado.")

    def _enviar_prompt_ia(self, prompt_override=None):
        prompt = prompt_override if (prompt_override and isinstance(prompt_override, str)) else self.inp_prompt_ia.text().strip()
        if not prompt:
            return

        self.inp_prompt_ia.clear()
        self.btn_enviar_ia.setEnabled(False)
        self._append_chat_message("user", prompt)
        self._append_chat_message("info", "<i>Pensando y procesando respuesta con Gemini API...</i>")

        api_key = self.db.obtener_config("gemini_api_key", "").strip()

        # Iniciar Worker Thread asincrónico
        self.gemini_worker = GeminiWorkerThread(api_key, self.db, prompt, self.historial_gemini)
        self.gemini_worker.finished_signal.connect(self._on_gemini_response)
        self.gemini_worker.error_signal.connect(self._on_gemini_error)
        self.gemini_worker.start()

    def _on_gemini_response(self, respuesta_text: str, db_modificada: bool):
        self.btn_enviar_ia.setEnabled(True)
        # Convertir Markdown básico a HTML para visualización rica en QTextEdit
        html_resp = respuesta_text.replace("\n", "<br>").replace("**", "<b>").replace("`", "<code>")
        self._append_chat_message("system", html_resp)

        if db_modificada:
            self.statusBar().showMessage(" Base de datos actualizada por el Asistente IA.", 5000)
            self._refrescar_todas_las_vistas()

    def _on_gemini_error(self, error_msg: str):
        self.btn_enviar_ia.setEnabled(True)
        self._append_chat_message("info", f"<span style='color: #EF4444;'>❌ Error: {error_msg}</span>")

    def _refrescar_todas_las_vistas(self):
        """Refresca todos los combos y tablas de la interfaz gráfica tras cambios realizados por IA"""
        try:
            if hasattr(self, "_cargar_combos_empleado"): self._cargar_combos_empleado()
            if hasattr(self, "_cargar_lista_empleados"): self._cargar_lista_empleados()
            if hasattr(self, "_cargar_tabla_esquemas"): self._cargar_tabla_esquemas()
            if hasattr(self, "_cargar_tabla_secciones"): self._cargar_tabla_secciones()
            if hasattr(self, "_cargar_tabla_celdas"): self._cargar_tabla_celdas()
            if hasattr(self, "_cargar_combo_empleados"): self._cargar_combo_empleados()
        except Exception:
            pass