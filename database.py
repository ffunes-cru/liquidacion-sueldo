"""
database.py — Gestión de base de datos SQLite para Liquidación de Sueldos.
Soporta Esquemas de Cálculo (Mensual, Jornal), Categorías Jornaleras y Modo de Cálculo Simple (tipo Odoo/SAP).
"""

import json
import os
import sqlite3
import sys

DB_FILENAME = "liquidacion_sueldos.db"


class DatabaseManager:
    """Gestiona la conexión, creación de tablas, migraciones y CRUD sobre SQLite."""

    def __init__(self, db_path: str | None = None):
        if db_path is None:
            if getattr(sys, "frozen", False):
                base_dir = os.path.dirname(os.path.abspath(sys.executable))
            else:
                base_dir = os.path.dirname(os.path.abspath(__file__))
            db_path = os.path.join(base_dir, DB_FILENAME)
        self.db_path = db_path
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys = ON")
        self._crear_tablas()

    # ------------------------------------------------------------------
    # Creación de tablas y Migraciones
    # ------------------------------------------------------------------
    def _crear_tablas(self):
        cur = self.conn.cursor()
        
        # 1. Esquemas de Cálculo
        cur.execute("""
            CREATE TABLE IF NOT EXISTS esquemas_calculo (
                codigo TEXT PRIMARY KEY,
                nombre TEXT NOT NULL
            );
        """)

        # 2. Categorías Jornaleras
        cur.execute("""
            CREATE TABLE IF NOT EXISTS categorias_jornal (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre     TEXT    UNIQUE NOT NULL,
                valor_hora REAL    NOT NULL
            );
        """)

        # 3. Secciones
        cur.execute("""
            CREATE TABLE IF NOT EXISTS secciones (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                codigo      TEXT    UNIQUE NOT NULL,
                titulo      TEXT    NOT NULL
            );
        """)

        # 4. Empleados (Legajo y variables de entrada)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS empleados (
                id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                legajo              TEXT,
                nombre_completo     TEXT    NOT NULL,
                tipo_liquidacion    TEXT    NOT NULL DEFAULT 'mensual',
                variables_calculo   TEXT    NOT NULL DEFAULT '{}',
                fecha_ingreso       TEXT    DEFAULT '2020-01-01'
            );
        """)

        # 5. Celdas de Cálculo (Recibo y Fórmulas)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS celdas_calculo (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                seccion_codigo   TEXT    NOT NULL REFERENCES secciones(codigo),
                codigo_variable  TEXT    NOT NULL,
                descripcion      TEXT    NOT NULL,
                condicion        TEXT    DEFAULT '',
                formula_unidad   TEXT    DEFAULT '',
                formula_base     TEXT    DEFAULT '',
                formula_monto    TEXT    NOT NULL,
                orden            INTEGER NOT NULL DEFAULT 0,
                esquema_codigo   TEXT    REFERENCES esquemas_calculo(codigo) DEFAULT 'MENSUAL',
                tipo_calculo     TEXT    NOT NULL DEFAULT 'formula',
                simple_porcentaje REAL,
                simple_base_variable TEXT,
                simple_monto_fijo REAL,
                visible_recibo   INTEGER DEFAULT 1,
                UNIQUE(esquema_codigo, codigo_variable)
            );
        """)

        # 6. Celdas del Gráfico Custom
        cur.execute("""
            CREATE TABLE IF NOT EXISTS celdas_grafico (
                id       INTEGER PRIMARY KEY AUTOINCREMENT,
                etiqueta TEXT    NOT NULL,
                formula  TEXT    NOT NULL,
                orden    INTEGER NOT NULL DEFAULT 0,
                esquema_codigo TEXT REFERENCES esquemas_calculo(codigo) DEFAULT 'MENSUAL',
                UNIQUE(esquema_codigo, etiqueta)
            );
        """)

        # 7. Variables Globales de Sistema
        cur.execute("""
            CREATE TABLE IF NOT EXISTS variables_globales (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                codigo      TEXT    UNIQUE NOT NULL,
                valor       TEXT    NOT NULL,
                descripcion TEXT    DEFAULT ''
            );
        """)

        # 8. Empresa (Singleton — datos para cabecera PDF)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS empresa (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                razon_social   TEXT    NOT NULL DEFAULT '',
                direccion      TEXT    DEFAULT '',
                cuit           TEXT    DEFAULT '',
                lugar_de_pago  TEXT    DEFAULT ''
            );
        """)

        # 9. Recibos (Patrón Snapshot — historial de liquidaciones)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS recibos (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                empleado_id    INTEGER NOT NULL REFERENCES empleados(id),
                esquema_codigo TEXT    NOT NULL,
                mes            INTEGER NOT NULL,
                anio           INTEGER NOT NULL,
                periodo        TEXT    NOT NULL DEFAULT 'M',
                datos_json     TEXT    NOT NULL,
                fecha_emision  TEXT    NOT NULL,
                UNIQUE(empleado_id, esquema_codigo, mes, anio, periodo)
            );
        """)

        self.conn.commit()

        # --- Migraciones dinámicas: Añadir columnas nuevas si no existen ---
        alteraciones = [
            ("empleados", "esquema_codigo", "TEXT REFERENCES esquemas_calculo(codigo) DEFAULT 'MENSUAL'"),
            ("empleados", "categoria_jornal_id", "INTEGER REFERENCES categorias_jornal(id)"),
            ("celdas_calculo", "esquema_codigo", "TEXT REFERENCES esquemas_calculo(codigo) DEFAULT 'MENSUAL'"),
            ("celdas_calculo", "tipo_calculo", "TEXT NOT NULL DEFAULT 'formula'"),
            ("celdas_calculo", "simple_porcentaje", "REAL"),
            ("celdas_calculo", "simple_base_variable", "TEXT"),
            ("celdas_calculo", "simple_monto_fijo", "REAL"),
            ("celdas_grafico", "esquema_codigo", "TEXT REFERENCES esquemas_calculo(codigo) DEFAULT 'MENSUAL'"),
            ("empleados", "fecha_ingreso", "TEXT DEFAULT '2020-01-01'"),
            ("celdas_calculo", "visible_recibo", "INTEGER DEFAULT 1"),
            ("empleados", "cuil", "TEXT DEFAULT ''"),
        ]

        for tabla, columna, definicion in alteraciones:
            try:
                cur.execute(f"ALTER TABLE {tabla} ADD COLUMN {columna} {definicion}")
            except sqlite3.OperationalError:
                # La columna ya existe, ignoramos
                pass
        self.conn.commit()

        # Sembrar datos iniciales si la tabla de esquemas está vacía
        if cur.execute("SELECT COUNT(*) FROM esquemas_calculo").fetchone()[0] == 0:
            self._seed_datos_iniciales()

        # Sembrar empresa singleton si no existe
        if cur.execute("SELECT COUNT(*) FROM empresa").fetchone()[0] == 0:
            cur.execute("INSERT INTO empresa (razon_social) VALUES ('')")
            self.conn.commit()

    # ------------------------------------------------------------------
    # Seed de datos reales
    # ------------------------------------------------------------------
    def _seed_datos_iniciales(self):
        cur = self.conn.cursor()

        # 1. Sembrar Esquemas de Cálculo
        esquemas = [
            ("MENSUAL", "Comercio Mensualizado"),
            ("JORNAL", "Comercio Jornalero (Por hora)"),
        ]
        cur.executemany("INSERT INTO esquemas_calculo (codigo, nombre) VALUES (?, ?)", esquemas)

        # 2. Sembrar Categorías Jornaleras
        categorias = [
            ("Maestranza A Jornal", 5540.61),
            ("Administrativo A Jornal", 5600.00),
            ("Vendedor A Jornal", 5650.00),
        ]
        cur.executemany("INSERT INTO categorias_jornal (nombre, valor_hora) VALUES (?, ?)", categorias)

        # 3. Sembrar Secciones
        secciones = [
            ("COMPOSICION", "Composición Salarial"),
            ("RECIBO", "Recibo de Sueldo"),
            ("COSTO_EMP", "Costo Empleador"),
        ]
        cur.executemany("INSERT INTO secciones (codigo, titulo) VALUES (?, ?)", secciones)

        # 4. Sembrar Empleados (Uno mensual y uno jornalero de prueba)
        emp_mensual = {
            "basico_categoria": 1108122,
            "antiguedad_anios": 20,
            "asistencia_perfecta": True,
            "horas_extras_50": 0,
            "horas_extras_100": 0,
            "dias_vacaciones": 0,
            "adicional_convenio": 0,
        }
        cur.execute(
            """INSERT INTO empleados (legajo, nombre_completo, tipo_liquidacion, variables_calculo, esquema_codigo, categoria_jornal_id)
               VALUES (?, ?, ?, ?, ?, ?)""",
            ("0001", "Juan Pérez", "mensual", json.dumps(emp_mensual), "MENSUAL", None),
        )

        emp_jornal = {
            "horas_trabajadas": 150,
            "antiguedad_anios": 5,
            "asistencia_perfecta": True,
            "horas_extras_50": 10,
        }
        cur.execute(
            """INSERT INTO empleados (legajo, nombre_completo, tipo_liquidacion, variables_calculo, esquema_codigo, categoria_jornal_id)
               VALUES (?, ?, ?, ?, ?, ?)""",
            ("0002", "Pedro Gómez", "jornal", json.dumps(emp_jornal), "JORNAL", 1),
        )

        # 5. Sembrar Celdas de Cálculo
        # --- Esquema MENSUAL (Comercio) ---
        celdas_mensual = [
            # Composición
            ("COMPOSICION", "basico", "Sueldo Básico", "", "", "", "basico_categoria", 100, "MENSUAL", "formula", None, "", None),
            ("COMPOSICION", "antiguedad", "Antigüedad", "", "antiguedad_anios", "basico_categoria", "unidad * 0.01 * base", 110, "MENSUAL", "formula", None, "", None),
            ("COMPOSICION", "presentismo", "Presentismo", "asistencia_perfecta == True", "", "", "round((basico + antiguedad) * 0.0833, 2)", 120, "MENSUAL", "formula", None, "", None),
            ("COMPOSICION", "horas_extras_50_monto", "Horas Extras 50%", "horas_extras_50 > 0", "horas_extras_50", "", "round(unidad * (basico / 200) * 1.5, 2)", 130, "MENSUAL", "formula", None, "", None),
            ("COMPOSICION", "horas_extras_100_monto", "Horas Extras 100%", "horas_extras_100 > 0", "horas_extras_100", "", "round(unidad * (basico / 200) * 2, 2)", 135, "MENSUAL", "formula", None, "", None),
            ("COMPOSICION", "vacaciones_monto", "Vacaciones", "dias_vacaciones > 0", "dias_vacaciones", "", "round(unidad * (basico + antiguedad) / 25, 2)", 140, "MENSUAL", "formula", None, "", None),
            ("COMPOSICION", "bruto", "TOTAL BRUTO (Remuneraciones)", "", "", "", "basico + antiguedad + presentismo + horas_extras_50_monto + horas_extras_100_monto + vacaciones_monto", 150, "MENSUAL", "formula", None, "", None),
            # Deducciones (Modo Simple con Porcentajes)
            ("RECIBO", "jubilacion", "Jubilación (11%)", "", "", "", "", 200, "MENSUAL", "porcentaje", 11.0, "bruto", None),
            ("RECIBO", "ley19032", "INSSJP Ley 19032 (3%)", "", "", "", "", 210, "MENSUAL", "porcentaje", 3.0, "bruto", None),
            ("RECIBO", "obra_social", "Obra Social (3%)", "", "", "", "", 220, "MENSUAL", "porcentaje", 3.0, "bruto", None),
            ("RECIBO", "cuota_sindical", "Cuota Sindical (2%)", "", "", "", "", 230, "MENSUAL", "porcentaje", 2.0, "bruto", None),
            ("RECIBO", "faecys", "FAECYS (0.5%)", "", "", "", "", 240, "MENSUAL", "porcentaje", 0.5, "bruto", None),
            ("RECIBO", "sec", "SEC (2%)", "", "", "", "", 250, "MENSUAL", "porcentaje", 2.0, "bruto", None),
            ("RECIBO", "total_deducciones", "TOTAL DEDUCCIONES", "", "", "", "jubilacion + ley19032 + obra_social + cuota_sindical + faecys + sec", 260, "MENSUAL", "formula", None, "", None),
            ("RECIBO", "neto", "SUELDO NETO", "", "", "", "round(bruto - total_deducciones, 2)", 270, "MENSUAL", "formula", None, "", None),
            # Cargas Patronales (Modo Simple con Porcentajes)
            ("COSTO_EMP", "sipa_patronal", "SIPA Patronal (18%)", "", "", "", "", 300, "MENSUAL", "porcentaje", 18.0, "bruto", None),
            ("COSTO_EMP", "inssjp_patronal", "INSSJP Patronal (1.5%)", "", "", "", "", 310, "MENSUAL", "porcentaje", 1.5, "bruto", None),
            ("COSTO_EMP", "os_patronal", "Obra Social Patronal (6%)", "", "", "", "", 320, "MENSUAL", "porcentaje", 6.0, "bruto", None),
            ("COSTO_EMP", "asignaciones_familiares", "Asignaciones Familiares (4.44%)", "", "", "", "", 330, "MENSUAL", "porcentaje", 4.44, "bruto", None),
            ("COSTO_EMP", "fondo_empleo", "Fondo Nacional de Empleo (0.89%)", "", "", "", "", 340, "MENSUAL", "porcentaje", 0.89, "bruto", None),
            ("COSTO_EMP", "art_ffep", "ART + FFEP", "", "", "", "", 350, "MENSUAL", "porcentaje", 6.0, "bruto", None),
            ("COSTO_EMP", "total_cargas_patronales", "TOTAL CARGAS PATRONALES", "", "", "", "sipa_patronal + inssjp_patronal + os_patronal + asignaciones_familiares + fondo_empleo + art_ffep", 360, "MENSUAL", "formula", None, "", None),
            ("COSTO_EMP", "costo_laboral_total", "COSTO LABORAL TOTAL", "", "", "", "bruto + total_cargas_patronales", 370, "MENSUAL", "formula", None, "", None),
        ]

        # --- Esquema JORNAL (Comercio) ---
        celdas_jornal = [
            # Composición
            ("COMPOSICION", "basico", "Básico por Horas", "", "horas_trabajadas", "", "round(unidad * valor_hora, 2)", 100, "JORNAL", "formula", None, "", None),
            ("COMPOSICION", "antiguedad", "Antigüedad", "", "antiguedad_anios", "basico", "round(unidad * 0.01 * base, 2)", 110, "JORNAL", "formula", None, "", None),
            ("COMPOSICION", "presentismo", "Presentismo", "asistencia_perfecta == True", "", "", "round((basico + antiguedad) * 0.0833, 2)", 120, "JORNAL", "formula", None, "", None),
            ("COMPOSICION", "horas_extras_50_monto", "Horas Extras 50%", "horas_extras_50 > 0", "horas_extras_50", "valor_hora", "round(unidad * base * 1.5, 2)", 130, "JORNAL", "formula", None, "", None),
            ("COMPOSICION", "bruto", "TOTAL BRUTO (Remuneraciones)", "", "", "", "basico + antiguedad + presentismo + horas_extras_50_monto", 150, "JORNAL", "formula", None, "", None),
            # Deducciones
            ("RECIBO", "jubilacion", "Jubilación (11%)", "", "", "", "", 200, "JORNAL", "porcentaje", 11.0, "bruto", None),
            ("RECIBO", "ley19032", "INSSJP Ley 19032 (3%)", "", "", "", "", 210, "JORNAL", "porcentaje", 3.0, "bruto", None),
            ("RECIBO", "obra_social", "Obra Social (3%)", "", "", "", "", 220, "JORNAL", "porcentaje", 3.0, "bruto", None),
            ("RECIBO", "cuota_sindical", "Cuota Sindical (2%)", "", "", "", "", 230, "JORNAL", "porcentaje", 2.0, "bruto", None),
            ("RECIBO", "total_deducciones", "TOTAL DEDUCCIONES", "", "", "", "jubilacion + ley19032 + obra_social + cuota_sindical", 260, "JORNAL", "formula", None, "", None),
            ("RECIBO", "neto", "SUELDO NETO", "", "", "", "round(bruto - total_deducciones, 2)", 270, "JORNAL", "formula", None, "", None),
            # Cargas Patronales
            ("COSTO_EMP", "sipa_patronal", "SIPA Patronal (18%)", "", "", "", "", 300, "JORNAL", "porcentaje", 18.0, "bruto", None),
            ("COSTO_EMP", "os_patronal", "Obra Social Patronal (6%)", "", "", "", "", 320, "JORNAL", "porcentaje", 6.0, "bruto", None),
            ("COSTO_EMP", "total_cargas_patronales", "TOTAL CARGAS PATRONALES", "", "", "", "sipa_patronal + os_patronal", 360, "JORNAL", "formula", None, "", None),
            ("COSTO_EMP", "costo_laboral_total", "COSTO LABORAL TOTAL", "", "", "", "bruto + total_cargas_patronales", 370, "JORNAL", "formula", None, "", None),
        ]

        # Insertar celdas en la BD
        cur.executemany(
            """INSERT INTO celdas_calculo
               (seccion_codigo, codigo_variable, descripcion, condicion,
                formula_unidad, formula_base, formula_monto, orden, esquema_codigo,
                tipo_calculo, simple_porcentaje, simple_base_variable, simple_monto_fijo)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            celdas_mensual + celdas_jornal,
        )

        # 6. Sembrar celdas de gráficos
        graficos = [
            ("Sueldo Neto (Bolsillo)", "neto", 10, "MENSUAL"),
            ("Seguridad Social (Aportes/Contribuciones)", "jubilacion + ley19032 + obra_social + sipa_patronal + inssjp_patronal + os_patronal + asignaciones_familiares + fondo_empleo", 20, "MENSUAL"),
            ("Aportes Sindicales", "cuota_sindical + faecys + sec", 30, "MENSUAL"),
            ("ART y Seguro Ley", "art_ffep", 40, "MENSUAL"),

            ("Sueldo Neto (Bolsillo)", "neto", 10, "JORNAL"),
            ("Seguridad Social", "jubilacion + ley19032 + obra_social + sipa_patronal + os_patronal", 20, "JORNAL"),
            ("Aportes Sindicales", "cuota_sindical", 30, "JORNAL"),
        ]
        cur.executemany(
            "INSERT INTO celdas_grafico (etiqueta, formula, orden, esquema_codigo) VALUES (?, ?, ?, ?)",
            graficos,
        )

        self.conn.commit()

    # ------------------------------------------------------------------
    # CRUD Variables Globales (Campos Globales de Sistema)
    # ------------------------------------------------------------------
    def listar_variables_globales(self) -> list[dict]:
        rows = self.conn.execute("SELECT * FROM variables_globales ORDER BY codigo").fetchall()
        return [dict(r) for r in rows]

    def guardar_variable_global(self, var_id: int | None, codigo: str, valor: str, descripcion: str) -> int:
        if var_id:
            self.conn.execute(
                "UPDATE variables_globales SET codigo=?, valor=?, descripcion=? WHERE id=?",
                (codigo, valor, descripcion, var_id),
            )
        else:
            cur = self.conn.execute(
                "INSERT INTO variables_globales (codigo, valor, descripcion) VALUES (?, ?, ?)",
                (codigo, valor, descripcion),
            )
            var_id = cur.lastrowid
        self.conn.commit()
        return var_id

    def eliminar_variable_global(self, var_id: int):
        self.conn.execute("DELETE FROM variables_globales WHERE id = ?", (var_id,))
        self.conn.commit()

    # ------------------------------------------------------------------
    # CRUD Esquemas
    # ------------------------------------------------------------------
    def listar_esquemas(self) -> list[dict]:
        rows = self.conn.execute("SELECT * FROM esquemas_calculo ORDER BY codigo").fetchall()
        print(rows)
        return [dict(r) for r in rows]

    # ------------------------------------------------------------------
    # CRUD Categorías Jornaleras
    # ------------------------------------------------------------------
    def listar_categorias_jornal(self) -> list[dict]:
        rows = self.conn.execute("SELECT * FROM categorias_jornal ORDER BY nombre").fetchall()
        return [dict(r) for r in rows]

    def guardar_categoria_jornal(self, cat_id: int | None, nombre: str, valor_hora: float) -> int:
        if cat_id:
            self.conn.execute(
                "UPDATE categorias_jornal SET nombre=?, valor_hora=? WHERE id=?",
                (nombre, valor_hora, cat_id),
            )
        else:
            cur = self.conn.execute(
                "INSERT INTO categorias_jornal (nombre, valor_hora) VALUES (?, ?)",
                (nombre, valor_hora),
            )
            cat_id = cur.lastrowid
        self.conn.commit()
        return cat_id

    def eliminar_categoria_jornal(self, cat_id: int):
        self.conn.execute("DELETE FROM categorias_jornal WHERE id = ?", (cat_id,))
        self.conn.commit()

    # ------------------------------------------------------------------
    # CRUD Empleados
    # ------------------------------------------------------------------
    def listar_empleados(self) -> list[dict]:
        rows = self.conn.execute(
            """SELECT e.*, c.nombre AS categoria_nombre
               FROM empleados e
               LEFT JOIN categorias_jornal c ON c.id = e.categoria_jornal_id
               ORDER BY e.legajo"""
        ).fetchall()
        return [dict(r) for r in rows]

    def obtener_empleado(self, emp_id: int) -> dict | None:
        row = self.conn.execute(
            """SELECT e.*, c.nombre AS categoria_nombre
               FROM empleados e
               LEFT JOIN categorias_jornal c ON c.id = e.categoria_jornal_id
               WHERE e.id = ?""", (emp_id,)
        ).fetchone()
        return dict(row) if row else None

    def guardar_empleado(self, emp_id: int | None, legajo: str, nombre: str,
                         tipo_liq: str, variables_json: str, esquema_codigo: str,
                         categoria_jornal_id: int | None, fecha_ingreso: str = "2020-01-01",
                         cuil: str = "") -> int:
        if emp_id:
            self.conn.execute(
                """UPDATE empleados
                   SET legajo=?, nombre_completo=?, tipo_liquidacion=?, variables_calculo=?,
                       esquema_codigo=?, categoria_jornal_id=?, fecha_ingreso=?, cuil=?
                   WHERE id=?""",
                (legajo, nombre, tipo_liq, variables_json, esquema_codigo,
                 categoria_jornal_id, fecha_ingreso, cuil, emp_id),
            )
        else:
            cur = self.conn.execute(
                """INSERT INTO empleados (legajo, nombre_completo, tipo_liquidacion, variables_calculo,
                    esquema_codigo, categoria_jornal_id, fecha_ingreso, cuil)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (legajo, nombre, tipo_liq, variables_json, esquema_codigo,
                 categoria_jornal_id, fecha_ingreso, cuil),
            )
            emp_id = cur.lastrowid
        self.conn.commit()
        return emp_id

    def eliminar_empleado(self, emp_id: int):
        self.conn.execute("DELETE FROM empleados WHERE id = ?", (emp_id,))
        self.conn.commit()

    # ------------------------------------------------------------------
    # CRUD Secciones
    # ------------------------------------------------------------------
    def listar_secciones(self) -> list[dict]:
        rows = self.conn.execute("SELECT * FROM secciones ORDER BY id").fetchall()
        return [dict(r) for r in rows]

    # ------------------------------------------------------------------
    # CRUD Celdas de Cálculo
    # ------------------------------------------------------------------
    def listar_celdas(self) -> list[dict]:
        rows = self.conn.execute(
            """SELECT c.*, s.titulo AS seccion_titulo
               FROM celdas_calculo c
               JOIN secciones s ON s.codigo = c.seccion_codigo
               ORDER BY c.esquema_codigo, c.orden"""
        ).fetchall()
        return [dict(r) for r in rows]

    def listar_celdas_por_esquema(self, esquema_codigo: str) -> list[dict]:
        rows = self.conn.execute(
            """SELECT * FROM celdas_calculo
               WHERE esquema_codigo = ? ORDER BY orden""",
            (esquema_codigo,),
        ).fetchall()
        return [dict(r) for r in rows]

    def guardar_celda(self, celda_id: int | None, seccion_codigo: str,
                      codigo_variable: str, descripcion: str, condicion: str,
                      formula_unidad: str, formula_base: str, formula_monto: str,
                      orden: int, esquema_codigo: str, tipo_calculo: str,
                      simple_porcentaje: float | None, simple_base_variable: str | None,
                      simple_monto_fijo: float | None, visible_recibo: int = 1) -> int:
        if celda_id:
            self.conn.execute(
                """UPDATE celdas_calculo
                   SET seccion_codigo=?, codigo_variable=?, descripcion=?, condicion=?,
                       formula_unidad=?, formula_base=?, formula_monto=?, orden=?,
                       esquema_codigo=?, tipo_calculo=?, simple_porcentaje=?,
                       simple_base_variable=?, simple_monto_fijo=?, visible_recibo=?
                   WHERE id=?""",
                (seccion_codigo, codigo_variable, descripcion, condicion,
                 formula_unidad, formula_base, formula_monto, orden,
                 esquema_codigo, tipo_calculo, simple_porcentaje,
                 simple_base_variable, simple_monto_fijo, visible_recibo, celda_id),
            )
        else:
            cur = self.conn.execute(
                """INSERT INTO celdas_calculo
                   (seccion_codigo, codigo_variable, descripcion, condicion,
                    formula_unidad, formula_base, formula_monto, orden, esquema_codigo,
                    tipo_calculo, simple_porcentaje, simple_base_variable, simple_monto_fijo, visible_recibo)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (seccion_codigo, codigo_variable, descripcion, condicion,
                 formula_unidad, formula_base, formula_monto, orden,
                 esquema_codigo, tipo_calculo, simple_porcentaje,
                 simple_base_variable, simple_monto_fijo, visible_recibo),
            )
            celda_id = cur.lastrowid
        self.conn.commit()
        return celda_id

    def eliminar_celda(self, celda_id: int):
        self.conn.execute("DELETE FROM celdas_calculo WHERE id = ?", (celda_id,))
        self.conn.commit()

    # ------------------------------------------------------------------
    # CRUD Celdas de Gráfico Custom
    # ------------------------------------------------------------------
    def listar_celdas_grafico(self) -> list[dict]:
        rows = self.conn.execute("SELECT * FROM celdas_grafico ORDER BY esquema_codigo, orden").fetchall()
        return [dict(r) for r in rows]

    def listar_celdas_grafico_por_esquema(self, esquema_codigo: str) -> list[dict]:
        rows = self.conn.execute(
            "SELECT * FROM celdas_grafico WHERE esquema_codigo = ? ORDER BY orden",
            (esquema_codigo,),
        ).fetchall()
        return [dict(r) for r in rows]

    def guardar_celda_grafico(self, celda_id: int | None, etiqueta: str, formula: str,
                              orden: int, esquema_codigo: str) -> int:
        if celda_id:
            self.conn.execute(
                "UPDATE celdas_grafico SET etiqueta=?, formula=?, orden=?, esquema_codigo=? WHERE id=?",
                (etiqueta, formula, orden, esquema_codigo, celda_id),
            )
        else:
            cur = self.conn.execute(
                "INSERT INTO celdas_grafico (etiqueta, formula, orden, esquema_codigo) VALUES (?, ?, ?, ?)",
                (etiqueta, formula, orden, esquema_codigo),
            )
            celda_id = cur.lastrowid
        self.conn.commit()
        return celda_id

    def eliminar_celda_grafico(self, celda_id: int):
        self.conn.execute("DELETE FROM celdas_grafico WHERE id = ?", (celda_id,))
        self.conn.commit()

    # ------------------------------------------------------------------
    # CRUD Esquemas Adicionales
    # ------------------------------------------------------------------
    def guardar_esquema(self, original_codigo: str | None, nuevo_codigo: str, nombre: str):
        cur = self.conn.cursor()
        if original_codigo:
            cur.execute(
                "UPDATE esquemas_calculo SET codigo=?, nombre=? WHERE codigo=?",
                (nuevo_codigo, nombre, original_codigo)
            )
        else:
            cur.execute(
                "INSERT INTO esquemas_calculo (codigo, nombre) VALUES (?, ?)",
                (nuevo_codigo, nombre)
            )
        self.conn.commit()

    def eliminar_esquema(self, codigo: str):
        cur = self.conn.cursor()
        emp_count = cur.execute("SELECT COUNT(*) FROM empleados WHERE esquema_codigo = ?", (codigo,)).fetchone()[0]
        if emp_count > 0:
            raise ValueError(f"No se puede eliminar el esquema '{codigo}' porque está asignado a {emp_count} empleado(s).")
            
        celdas_count = cur.execute("SELECT COUNT(*) FROM celdas_calculo WHERE esquema_codigo = ?", (codigo,)).fetchone()[0]
        if celdas_count > 0:
            raise ValueError(f"No se puede eliminar el esquema '{codigo}' porque tiene {celdas_count} celda(s) de cálculo asociadas.")
            
        cur.execute("DELETE FROM esquemas_calculo WHERE codigo = ?", (codigo,))
        self.conn.commit()

    def crear_backup(self) -> str:
        import shutil
        from datetime import datetime
        
        dir_name = os.path.dirname(self.db_path)
        base_name = os.path.basename(self.db_path)
        name_no_ext, ext = os.path.splitext(base_name)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"{name_no_ext}_backup_{timestamp}{ext}"
        backup_path = os.path.join(dir_name, backup_name)
        
        self.conn.close()
        try:
            shutil.copy2(self.db_path, backup_path)
        finally:
            self.conn = sqlite3.connect(self.db_path)
            self.conn.row_factory = sqlite3.Row
            self.conn.execute("PRAGMA foreign_keys = ON")
            
        return backup_path

    def reinicializar_nuevo_mes(self) -> str:
        backup_path = self.crear_backup()
        cur = self.conn.cursor()
        empleados = cur.execute("SELECT id, tipo_liquidacion, variables_calculo FROM empleados").fetchall()
        
        keys_to_reset = {"horas_trabajadas", "horas_extras_50", "horas_extras_100", "dias_vacaciones"}
        
        for emp in empleados:
            emp_id = emp["id"]
            tipo = emp["tipo_liquidacion"]
            try:
                variables = json.loads(emp["variables_calculo"])
            except Exception:
                variables = {}
                
            if tipo == "jornal":
                if "quincenas" in variables:
                    q1 = variables["quincenas"].get("Q1", {})
                else:
                    q1 = variables
                    
                for k in keys_to_reset:
                    if k in q1:
                        q1[k] = 0
                        
                variables = {
                    "quincenas": {
                        "Q1": q1
                    }
                }
            else:
                if "quincenas" in variables:
                    variables = variables["quincenas"].get("Q1", {})
                    
                for k in keys_to_reset:
                    if k in variables:
                        variables[k] = 0
            
            cur.execute(
                "UPDATE empleados SET variables_calculo = ? WHERE id = ?",
                (json.dumps(variables, ensure_ascii=False), emp_id)
            )
            
        self.conn.commit()
        return backup_path

    def listar_quincenas_empleado(self, emp_id: int) -> list[dict]:
        cur = self.conn.cursor()
        row = cur.execute("SELECT variables_calculo FROM empleados WHERE id = ?", (emp_id,)).fetchone()
        if not row:
            return []
        try:
            data = json.loads(row["variables_calculo"]) if row["variables_calculo"] else {}
        except Exception:
            data = {}
        
        quincenas_list = []
        if isinstance(data, dict) and "quincenas" in data:
            for q_code, q_vars in sorted(data["quincenas"].items()):
                quincenas_list.append({
                    "codigo_quincena": q_code,
                    "variables": q_vars
                })
        else:
            quincenas_list.append({
                "codigo_quincena": "Q1",
                "variables": data if isinstance(data, dict) else {}
            })
        return quincenas_list

    def guardar_quincena_empleado(self, emp_id: int, codigo_quincena: str, variables_input: str | dict):
        cur = self.conn.cursor()
        row = cur.execute("SELECT variables_calculo FROM empleados WHERE id = ?", (emp_id,)).fetchone()
        if not row:
            return
        try:
            data = json.loads(row["variables_calculo"]) if row["variables_calculo"] else {}
        except Exception:
            data = {}
            
        if not isinstance(data, dict):
            data = {}
            
        if "quincenas" not in data:
            data = {
                "quincenas": {
                    "Q1": data
                }
            }
            
        if isinstance(variables_input, str):
            parsed_vars = {}
            for line in variables_input.splitlines():
                if "=" in line:
                    parts = line.split("=", 1)
                    k = parts[0].strip()
                    v_raw = parts[1].strip()
                    try:
                        v = int(v_raw)
                    except ValueError:
                        try:
                            v = float(v_raw)
                        except ValueError:
                            v = v_raw
                    parsed_vars[k] = v
        else:
            parsed_vars = variables_input
            
        data["quincenas"][codigo_quincena] = parsed_vars
        
        cur.execute(
            "UPDATE empleados SET variables_calculo = ? WHERE id = ?",
            (json.dumps(data, ensure_ascii=False), emp_id)
        )
        self.conn.commit()

    # ------------------------------------------------------------------
    # CRUD Empresa (Singleton)
    # ------------------------------------------------------------------
    def obtener_empresa(self) -> dict:
        row = self.conn.execute("SELECT * FROM empresa LIMIT 1").fetchone()
        if row:
            return dict(row)
        return {"id": None, "razon_social": "", "direccion": "", "cuit": "", "lugar_de_pago": ""}

    def guardar_empresa(self, razon_social: str, direccion: str, cuit: str, lugar_de_pago: str):
        emp = self.obtener_empresa()
        if emp["id"]:
            self.conn.execute(
                "UPDATE empresa SET razon_social=?, direccion=?, cuit=?, lugar_de_pago=? WHERE id=?",
                (razon_social, direccion, cuit, lugar_de_pago, emp["id"]),
            )
        else:
            self.conn.execute(
                "INSERT INTO empresa (razon_social, direccion, cuit, lugar_de_pago) VALUES (?, ?, ?, ?)",
                (razon_social, direccion, cuit, lugar_de_pago),
            )
        self.conn.commit()

    # ------------------------------------------------------------------
    # CRUD Recibos (Patrón Snapshot)
    # ------------------------------------------------------------------
    def persistir_recibo(self, empleado_id: int, esquema_codigo: str,
                         mes: int, anio: int, periodo: str, datos_json: str) -> int:
        """Persiste un snapshot de liquidación. Si ya existe para el mismo
        empleado/esquema/mes/año/período, lo reemplaza."""
        from datetime import datetime
        fecha = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        # Intentar reemplazar si ya existe
        existing = self.conn.execute(
            """SELECT id FROM recibos
               WHERE empleado_id=? AND esquema_codigo=? AND mes=? AND anio=? AND periodo=?""",
            (empleado_id, esquema_codigo, mes, anio, periodo),
        ).fetchone()
        if existing:
            self.conn.execute(
                "UPDATE recibos SET datos_json=?, fecha_emision=? WHERE id=?",
                (datos_json, fecha, existing["id"]),
            )
            self.conn.commit()
            return existing["id"]
        else:
            cur = self.conn.execute(
                """INSERT INTO recibos (empleado_id, esquema_codigo, mes, anio, periodo, datos_json, fecha_emision)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (empleado_id, esquema_codigo, mes, anio, periodo, datos_json, fecha),
            )
            self.conn.commit()
            return cur.lastrowid

    def listar_recibos_empleado(self, empleado_id: int) -> list[dict]:
        rows = self.conn.execute(
            """SELECT r.*, e.nombre_completo, e.legajo
               FROM recibos r
               JOIN empleados e ON e.id = r.empleado_id
               WHERE r.empleado_id = ?
               ORDER BY r.anio DESC, r.mes DESC, r.periodo""",
            (empleado_id,),
        ).fetchall()
        return [dict(r) for r in rows]

    def obtener_recibo(self, recibo_id: int) -> dict | None:
        row = self.conn.execute(
            "SELECT * FROM recibos WHERE id = ?", (recibo_id,)
        ).fetchone()
        return dict(row) if row else None

    def eliminar_recibo(self, recibo_id: int):
        self.conn.execute("DELETE FROM recibos WHERE id = ?", (recibo_id,))
        self.conn.commit()

    def buscar_recibos(self, empleado_id: int, mes: int, anio: int) -> list[dict]:
        """Busca todos los recibos de un empleado para un mes/año dados (Q1, Q2, M)."""
        rows = self.conn.execute(
            "SELECT * FROM recibos WHERE empleado_id=? AND mes=? AND anio=? ORDER BY periodo",
            (empleado_id, mes, anio),
        ).fetchall()
        return [dict(r) for r in rows]

    def buscar_recibos_rango(self, empleado_id: int, mes_desde: int, anio_desde: int,
                             mes_hasta: int, anio_hasta: int) -> list[dict]:
        """Busca recibos en un rango de meses para funciones históricas."""
        rows = self.conn.execute(
            """SELECT * FROM recibos
               WHERE empleado_id = ?
                 AND (anio * 100 + mes) BETWEEN ? AND ?
               ORDER BY anio, mes, periodo""",
            (empleado_id, anio_desde * 100 + mes_desde, anio_hasta * 100 + mes_hasta),
        ).fetchall()
        return [dict(r) for r in rows]

    # ------------------------------------------------------------------
    # Utilidades
    # ------------------------------------------------------------------
    def ruta_db(self) -> str:
        return self.db_path

    def cerrar(self):
        self.conn.close()
