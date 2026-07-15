"""
database.py — Gestión de base de datos SQLite para Liquidación de Sueldos.
Soporta Esquemas de Cálculo (Mensual, Jornal), Categorías Jornaleras y Modo de Cálculo Simple (tipo Odoo/SAP).
"""

import json
import os
import sqlite3

DB_FILENAME = "liquidacion_sueldos.db"


class DatabaseManager:
    """Gestiona la conexión, creación de tablas, migraciones y CRUD sobre SQLite."""

    def __init__(self, db_path: str | None = None):
        if db_path is None:
            db_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), DB_FILENAME)
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
                variables_calculo   TEXT    NOT NULL DEFAULT '{}'
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
            "SELECT * FROM empleados WHERE id = ?", (emp_id,)
        ).fetchone()
        return dict(row) if row else None

    def guardar_empleado(self, emp_id: int | None, legajo: str, nombre: str,
                         tipo_liq: str, variables_json: str, esquema_codigo: str,
                         categoria_jornal_id: int | None) -> int:
        if emp_id:
            self.conn.execute(
                """UPDATE empleados
                   SET legajo=?, nombre_completo=?, tipo_liquidacion=?, variables_calculo=?, esquema_codigo=?, categoria_jornal_id=?
                   WHERE id=?""",
                (legajo, nombre, tipo_liq, variables_json, esquema_codigo, categoria_jornal_id, emp_id),
            )
        else:
            cur = self.conn.execute(
                """INSERT INTO empleados (legajo, nombre_completo, tipo_liquidacion, variables_calculo, esquema_codigo, categoria_jornal_id)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (legajo, nombre, tipo_liq, variables_json, esquema_codigo, categoria_jornal_id),
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
                      simple_monto_fijo: float | None) -> int:
        if celda_id:
            self.conn.execute(
                """UPDATE celdas_calculo
                   SET seccion_codigo=?, codigo_variable=?, descripcion=?, condicion=?,
                       formula_unidad=?, formula_base=?, formula_monto=?, orden=?,
                       esquema_codigo=?, tipo_calculo=?, simple_porcentaje=?,
                       simple_base_variable=?, simple_monto_fijo=?
                   WHERE id=?""",
                (seccion_codigo, codigo_variable, descripcion, condicion,
                 formula_unidad, formula_base, formula_monto, orden,
                 esquema_codigo, tipo_calculo, simple_porcentaje,
                 simple_base_variable, simple_monto_fijo, celda_id),
            )
        else:
            cur = self.conn.execute(
                """INSERT INTO celdas_calculo
                   (seccion_codigo, codigo_variable, descripcion, condicion,
                    formula_unidad, formula_base, formula_monto, orden, esquema_codigo,
                    tipo_calculo, simple_porcentaje, simple_base_variable, simple_monto_fijo)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (seccion_codigo, codigo_variable, descripcion, condicion,
                 formula_unidad, formula_base, formula_monto, orden,
                 esquema_codigo, tipo_calculo, simple_porcentaje,
                 simple_base_variable, simple_monto_fijo),
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
    # Utilidades
    # ------------------------------------------------------------------
    def ruta_db(self) -> str:
        return self.db_path

    def cerrar(self):
        self.conn.close()
