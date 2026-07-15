"""
ui.py — Interfaz gráfica PyQt6 nativa para la aplicación de Liquidación de Sueldos.
Cuatro pestañas principales: Empleados, Categorías Jornal, Estructura de Recibo, Estructura de Gráfico, Vista Previa.
Menú para importar/exportar la base de datos (SQLite, Excel, CSV).
"""

import json
import os
import shutil

from PyQt6.QtCore import Qt, QSize
from PyQt6.QtGui import QAction, QFont, QColor
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QFormLayout,
    QTabWidget, QTableWidget, QTableWidgetItem, QTreeWidget, QTreeWidgetItem,
    QComboBox, QPushButton, QLineEdit, QTextEdit, QLabel, QSplitter,
    QListWidget, QListWidgetItem, QMessageBox, QFileDialog, QHeaderView,
    QFrame, QGroupBox, QAbstractItemView, QDoubleSpinBox, QRadioButton, QButtonGroup,
    QStackedWidget,
)

from database import DatabaseManager
from motor import MotorLiquidacion

# Importar canvas de Matplotlib
from matplotlib.figure import Figure
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas

# Importar exportadores
import exporters


# ======================================================================
# Helpers de formato
# ======================================================================
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

        # 2. Categorías Jornaleras
        self.tab_categorias = QWidget()
        self.tabs.addTab(self.tab_categorias, "Categorías Jornal")
        self._build_tab_categorias()

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
        btn_nuevo = QPushButton("Nuevo")
        btn_nuevo.clicked.connect(self._nuevo_empleado)
        btn_bar.addWidget(btn_nuevo)

        btn_eliminar = QPushButton("Eliminar")
        btn_eliminar.clicked.connect(self._eliminar_empleado)
        btn_bar.addWidget(btn_eliminar)
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

        self.inp_tipo = QComboBox()
        self.inp_tipo.addItems(["mensual", "jornal"])
        self.inp_tipo.currentIndexChanged.connect(self._on_tipo_liquidacion_cambiado)
        form.addRow("Tipo Liquidación:", self.inp_tipo)

        self.inp_esquema = QComboBox()
        form.addRow("Esquema de Cálculo:", self.inp_esquema)

        self.inp_categoria_jornal = QComboBox()
        form.addRow("Categoría Jornalera:", self.inp_categoria_jornal)

        group_datos.setLayout(form)
        right_layout.addWidget(group_datos)

        # Variables JSON
        group_vars = QGroupBox("Variables de Cálculo (JSON)")
        vars_layout = QVBoxLayout()

        self.inp_variables = QTextEdit()
        self.inp_variables.setPlaceholderText('{"antiguedad_anios": 20, "asistencia_perfecta": true, ...}')
        mono_font = QFont("Monospace")
        mono_font.setStyleHint(QFont.StyleHint.Monospace)
        mono_font.setPointSize(10)
        self.inp_variables.setFont(mono_font)
        self.inp_variables.setMinimumHeight(160)
        vars_layout.addWidget(self.inp_variables)

        self.lbl_json_status = QLabel("")
        vars_layout.addWidget(self.lbl_json_status)
        self.inp_variables.textChanged.connect(self._validar_json)

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

    def _cargar_lista_empleados(self):
        self.lista_empleados.blockSignals(True)
        self.lista_empleados.clear()
        self._empleados_data = self.db.listar_empleados()
        for emp in self._empleados_data:
            item = QListWidgetItem(f"[{emp['legajo']}]  {emp['nombre_completo']}")
            item.setData(Qt.ItemDataRole.UserRole, emp["id"])
            self.lista_empleados.addItem(item)
        self.lista_empleados.blockSignals(False)
        if self._empleados_data:
            self.lista_empleados.setCurrentRow(0)

    def _on_empleado_seleccionado(self, row: int):
        if row < 0 or row >= len(self._empleados_data):
            return
        emp = self._empleados_data[row]
        self.inp_legajo.setText(emp["legajo"] or "")
        self.inp_nombre.setText(emp["nombre_completo"] or "")
        
        idx_tipo = self.inp_tipo.findText(emp["tipo_liquidacion"])
        if idx_tipo >= 0:
            self.inp_tipo.setCurrentIndex(idx_tipo)

        idx_esq = self.inp_esquema.findData(emp["esquema_codigo"])
        if idx_esq >= 0:
            self.inp_esquema.setCurrentIndex(idx_esq)

        idx_cat = self.inp_categoria_jornal.findData(emp["categoria_jornal_id"])
        if idx_cat >= 0:
            self.inp_categoria_jornal.setCurrentIndex(idx_cat)

        try:
            variables = json.loads(emp["variables_calculo"])
            self.inp_variables.setPlainText(json.dumps(variables, indent=2, ensure_ascii=False))
        except Exception:
            self.inp_variables.setPlainText(emp["variables_calculo"] or "{}")

    def _validar_json(self):
        txt = self.inp_variables.toPlainText().strip()
        if not txt:
            self.lbl_json_status.setText("")
            return
        try:
            json.loads(txt)
            self.lbl_json_status.setText("✓ JSON válido")
            self.lbl_json_status.setStyleSheet("color: green;")
        except json.JSONDecodeError as e:
            self.lbl_json_status.setText(f"✗ Error: {e.msg} (línea {e.lineno})")
            self.lbl_json_status.setStyleSheet("color: red;")

    def _guardar_empleado(self):
        row = self.lista_empleados.currentRow()
        emp_id = None
        if 0 <= row < len(self._empleados_data):
            emp_id = self._empleados_data[row]["id"]

        nombre = self.inp_nombre.text().strip()
        if not nombre:
            QMessageBox.warning(self, "Error", "El nombre es obligatorio.")
            return

        variables_txt = self.inp_variables.toPlainText().strip() or "{}"
        try:
            json.loads(variables_txt)
        except json.JSONDecodeError:
            QMessageBox.warning(self, "Error", "El JSON de variables no es válido.")
            return

        esquema = self.inp_esquema.currentData()
        cat_id = self.inp_categoria_jornal.currentData()

        self.db.guardar_empleado(
            emp_id, self.inp_legajo.text().strip(),
            nombre, self.inp_tipo.currentText(), variables_txt, esquema, cat_id
        )
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
        self.db.guardar_empleado(None, "", "Nuevo Empleado", "mensual", variables_default, "MENSUAL", None)
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
            self._cargar_combo_empleados()
            self.statusBar().showMessage("Empleado eliminado.", 4000)

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
    # PESTAÑA 3 — ESTRUCTURA DEL RECIBO (Con Editor Simple estilo SAP/Odoo)
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
        self.tabla_celdas.setColumnCount(9)
        self.tabla_celdas.setHorizontalHeaderLabels([
            "Sección", "Código Variable", "Descripción", "Condición",
            "Tipo Cálculo", "Fórmula Unidad / Pct", "Fórmula Base", "Fórmula Monto", "Orden",
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

        # 3. Panel Avanzado (Fórmulas)
        self.pane_formula = QWidget()
        l_form = QFormLayout(self.pane_formula)
        l_form.setContentsMargins(0, 0, 0, 0)
        self.inp_formula_unidad = QLineEdit()
        self.inp_formula_unidad.setPlaceholderText("Ej: antiguedad_anios")
        l_form.addRow("Fórmula Unidad:", self.inp_formula_unidad)

        self.inp_formula_base = QLineEdit()
        self.inp_formula_base.setPlaceholderText("Ej: basico_categoria")
        l_form.addRow("Fórmula Base:", self.inp_formula_base)

        self.inp_formula_monto = QLineEdit()
        self.inp_formula_monto.setPlaceholderText("Ej: unidad * base  o  bruto * 0.11")
        l_form.addRow("Fórmula Monto:", self.inp_formula_monto)
        self.editor_stack.addWidget(self.pane_formula)

        form_simple.addRow(self.editor_stack)
        editor_layout.addLayout(form_simple)

        # Conectar widgets del editor a actualizaciones de la tabla
        self.spin_pct_valor.valueChanged.connect(self._sync_editor_hacia_tabla)
        self.combo_pct_base.currentIndexChanged.connect(self._sync_editor_hacia_tabla)
        self.spin_fijo_valor.valueChanged.connect(self._sync_editor_hacia_tabla)
        self.inp_formula_unidad.textChanged.connect(self._sync_editor_hacia_tabla)
        self.inp_formula_base.textChanged.connect(self._sync_editor_hacia_tabla)
        self.inp_formula_monto.textChanged.connect(self._sync_editor_hacia_tabla)

        splitter.addWidget(self.editor_celda_group)
        splitter.setSizes([450, 250])

        self._cargar_tabla_celdas()

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
            # Vincular cambio de sección para actualizar
            self.tabla_celdas.setCellWidget(i, 0, combo)

            self.tabla_celdas.setItem(i, 1, QTableWidgetItem(c["codigo_variable"]))
            self.tabla_celdas.setItem(i, 2, QTableWidgetItem(c["descripcion"]))
            self.tabla_celdas.setItem(i, 3, QTableWidgetItem(c["condicion"] or ""))
            self.tabla_celdas.setItem(i, 4, QTableWidgetItem(c["tipo_calculo"]))

            # Mostrar según tipo cálculo
            t = c["tipo_calculo"]
            if t == "porcentaje":
                self.tabla_celdas.setItem(i, 5, QTableWidgetItem(f"{c['simple_porcentaje'] or 0.0}%"))
                self.tabla_celdas.setItem(i, 6, QTableWidgetItem(f"sobre {c['simple_base_variable'] or ''}"))
                self.tabla_celdas.setItem(i, 7, QTableWidgetItem("calculado"))
            elif t == "fijo":
                self.tabla_celdas.setItem(i, 5, QTableWidgetItem("-"))
                self.tabla_celdas.setItem(i, 6, QTableWidgetItem("-"))
                self.tabla_celdas.setItem(i, 7, QTableWidgetItem(f"Fijo: ${c['simple_monto_fijo'] or 0.0}"))
            else:
                self.tabla_celdas.setItem(i, 5, QTableWidgetItem(c["formula_unidad"] or ""))
                self.tabla_celdas.setItem(i, 6, QTableWidgetItem(c["formula_base"] or ""))
                self.tabla_celdas.setItem(i, 7, QTableWidgetItem(c["formula_monto"] or ""))

            self.tabla_celdas.setItem(i, 8, QTableWidgetItem(str(c["orden"])))

            # Guardar el ID de BD, los campos simples y las fórmulas originales como atributos
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

        self.tabla_celdas.blockSignals(False)

        # Column widths
        self.tabla_celdas.setColumnWidth(0, 130)
        self.tabla_celdas.setColumnWidth(1, 160)
        self.tabla_celdas.setColumnWidth(2, 180)
        self.tabla_celdas.setColumnWidth(3, 140)
        self.tabla_celdas.setColumnWidth(4, 100)
        self.tabla_celdas.setColumnWidth(5, 150)
        self.tabla_celdas.setColumnWidth(6, 150)
        self.tabla_celdas.setColumnWidth(7, 240)
        self.tabla_celdas.setColumnWidth(8, 60)

        # Si hay filas, seleccionar la primera para popular el editor
        if self.tabla_celdas.rowCount() > 0:
            self.tabla_celdas.selectRow(0)

    def _on_celda_seleccionada_tabla(self):
        row = self.tabla_celdas.currentRow()
        if row < 0:
            return

        item_codigo = self.tabla_celdas.item(row, 1)
        if not item_codigo:
            return

        self.spin_pct_valor.blockSignals(True)
        self.combo_pct_base.blockSignals(True)
        self.spin_fijo_valor.blockSignals(True)
        self.inp_formula_unidad.blockSignals(True)
        self.inp_formula_base.blockSignals(True)
        self.inp_formula_monto.blockSignals(True)
        self.combo_editor_tipo.blockSignals(True)

        tipo_calculo = item_codigo.data(Qt.ItemDataRole.UserRole + 1) or "formula"
        simple_porcentaje = item_codigo.data(Qt.ItemDataRole.UserRole + 2)
        simple_base_variable = item_codigo.data(Qt.ItemDataRole.UserRole + 3)
        simple_monto_fijo = item_codigo.data(Qt.ItemDataRole.UserRole + 4)
        formula_unidad = item_codigo.data(Qt.ItemDataRole.UserRole + 5) or ""
        formula_base = item_codigo.data(Qt.ItemDataRole.UserRole + 6) or ""
        formula_monto = item_codigo.data(Qt.ItemDataRole.UserRole + 7) or ""

        # Rellenar combo de variables base del mismo esquema
        self.combo_pct_base.clear()
        for r_i in range(self.tabla_celdas.rowCount()):
            it = self.tabla_celdas.item(r_i, 1)
            if it:
                v_code = it.text().strip()
                if v_code and v_code != item_codigo.text().strip():
                    self.combo_pct_base.addItem(v_code, v_code)

        # Asignar valores
        idx = self.combo_editor_tipo.findData(tipo_calculo)
        if idx >= 0:
            self.combo_editor_tipo.setCurrentIndex(idx)

        self._on_tipo_calculo_editor_cambiado()

        self.spin_pct_valor.setValue(simple_porcentaje if simple_porcentaje is not None else 0.0)
        idx_base = self.combo_pct_base.findData(simple_base_variable)
        if idx_base >= 0:
            self.combo_pct_base.setCurrentIndex(idx_base)

        self.spin_fijo_valor.setValue(simple_monto_fijo if simple_monto_fijo is not None else 0.0)
        self.inp_formula_unidad.setText(formula_unidad)
        self.inp_formula_base.setText(formula_base)
        self.inp_formula_monto.setText(formula_monto)

        self.spin_pct_valor.blockSignals(False)
        self.combo_pct_base.blockSignals(False)
        self.spin_fijo_valor.blockSignals(False)
        self.inp_formula_unidad.blockSignals(False)
        self.inp_formula_base.blockSignals(False)
        self.inp_formula_monto.blockSignals(False)
        self.combo_editor_tipo.blockSignals(False)

    def _on_tipo_calculo_editor_cambiado(self):
        t = self.combo_editor_tipo.currentData()
        if t == "porcentaje":
            self.editor_stack.setCurrentWidget(self.pane_porcentaje)
        elif t == "fijo":
            self.editor_stack.setCurrentWidget(self.pane_fijo)
        else:
            self.editor_stack.setCurrentWidget(self.pane_formula)
        self._sync_editor_hacia_tabla()

    def _sync_editor_hacia_tabla(self):
        """Toma los valores del panel inferior y los plasma temporalmente en los metadatos de la celda de la tabla."""
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

        # Actualizar visualización en la tabla
        self.tabla_celdas.blockSignals(True)
        self.tabla_celdas.setItem(row, 4, QTableWidgetItem(tipo_calculo))
        if tipo_calculo == "porcentaje":
            self.tabla_celdas.setItem(row, 5, QTableWidgetItem(f"{self.spin_pct_valor.value()}%"))
            self.tabla_celdas.setItem(row, 6, QTableWidgetItem(f"sobre {self.combo_pct_base.currentText()}"))
            self.tabla_celdas.setItem(row, 7, QTableWidgetItem("calculado"))
        elif tipo_calculo == "fijo":
            self.tabla_celdas.setItem(row, 5, QTableWidgetItem("-"))
            self.tabla_celdas.setItem(row, 6, QTableWidgetItem("-"))
            self.tabla_celdas.setItem(row, 7, QTableWidgetItem(f"Fijo: ${self.spin_fijo_valor.value()}"))
        else:
            self.tabla_celdas.setItem(row, 5, QTableWidgetItem(self.inp_formula_unidad.text()))
            self.tabla_celdas.setItem(row, 6, QTableWidgetItem(self.inp_formula_base.text()))
            self.tabla_celdas.setItem(row, 7, QTableWidgetItem(self.inp_formula_monto.text()))
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
            cond = (self.tabla_celdas.item(i, 3).text() or "").strip()
            orden_str = (self.tabla_celdas.item(i, 8).text() or "0").strip()

            item_codigo = self.tabla_celdas.item(i, 1)
            tipo_calc = item_codigo.data(Qt.ItemDataRole.UserRole + 1) or "formula"
            simple_porcentaje = item_codigo.data(Qt.ItemDataRole.UserRole + 2)
            simple_base_variable = item_codigo.data(Qt.ItemDataRole.UserRole + 3)
            simple_monto_fijo = item_codigo.data(Qt.ItemDataRole.UserRole + 4)
            formula_unidad = item_codigo.data(Qt.ItemDataRole.UserRole + 5)
            formula_base = item_codigo.data(Qt.ItemDataRole.UserRole + 6)
            formula_monto = item_codigo.data(Qt.ItemDataRole.UserRole + 7)

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
                    orden, esq, tipo_calc, simple_porcentaje, simple_base_variable, simple_monto_fijo
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
        self.combo_empleado.setMinimumWidth(280)
        top.addWidget(self.combo_empleado)

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

    def _calcular_liquidacion(self):
        emp_id = self.combo_empleado.currentData()
        if emp_id is None:
            QMessageBox.warning(self, "Error", "Seleccione un empleado.")
            return

        resultado = self.motor.procesar_liquidacion(emp_id)
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

        orden_secciones = ["COMPOSICION", "RECIBO", "COSTO_EMP"]
        for sec_codigo in orden_secciones:
            filas = resultado["resultados_por_seccion"].get(sec_codigo, [])
            if not filas:
                continue

            sec_titulo = secciones_info.get(sec_codigo, sec_codigo)
            parent = QTreeWidgetItem(self.tree_resultado, [sec_titulo, "", "", ""])
            parent_font = QFont()
            parent_font.setBold(True)
            parent_font.setPointSize(11)
            parent.setFont(0, parent_font)
            parent.setExpanded(True)

            for fila in filas:
                es_total = fila["codigo"] in (
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
            items = [f for f in filas if f["codigo"] not in ignorar and f["monto"] > 0]
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

        try:
            exporters.exportar_recibo_pdf(self.ultimo_resultado, self.db, path, temp_chart if chart_generado else None)
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
