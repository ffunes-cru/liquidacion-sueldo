"""
motor.py — Motor de Liquidación Secuencial.
Evalúa celdas paramétricas (simples o fórmulas) y propaga resultados.
Soporta inyección de categorías jornaleras, esquemas de cálculo, variables globales y inicialización de variables para evitar errores.
"""

import calendar
import json
import re
from datetime import datetime, date
from simpleeval import SimpleEval, DEFAULT_OPERATORS
from database import DatabaseManager


class QuincenaNamespace:
    """Namespace para acceso mediante notación de puntos en fórmulas (ej: Q1.horas_trabajadas)"""
    def __init__(self, variables: dict):
        self.__dict__.update(variables)
    def __getattr__(self, name):
        # Por defecto devuelve 0.0 si la variable no existe en el namespace
        return self.__dict__.get(name, 0.0)
    def __repr__(self):
        return f"QuincenaNamespace({self.__dict__})"


class MotorContextDict(dict):
    def __init__(self, base_dict, sumar_q_fn, promedio_q_fn, max_q_fn, min_q_fn):
        super().__init__(base_dict)
        self.sumar_q = sumar_q_fn
        self.promedio_q = promedio_q_fn
        self.max_q = max_q_fn
        self.min_q = min_q_fn

    def __contains__(self, key):
        if super().__contains__(key):
            return True
        if key.startswith(("Q_sum_", "Q_avg_", "Q_max_", "Q_min_")):
            return True
        return False

    def __getitem__(self, key):
        try:
            return super().__getitem__(key)
        except KeyError:
            if key.startswith("Q_sum_"):
                return self.sumar_q(key[6:])
            if key.startswith("Q_avg_"):
                return self.promedio_q(key[6:])
            if key.startswith("Q_max_"):
                return self.max_q(key[6:])
            if key.startswith("Q_min_"):
                return self.min_q(key[6:])
            raise


def parse_value(val_str: str):
    """Auxiliar para parsear strings a tipos de datos nativos de Python."""
    val_str = val_str.strip()
    if val_str.lower() == "true":
        return True
    elif val_str.lower() == "false":
        return False
    else:
        try:
            return int(val_str)
        except ValueError:
            try:
                return float(val_str)
            except ValueError:
                return val_str


def calcular_antiguedad_anios(fecha_ingreso_str: str, fecha_calculo_str: str) -> int:
    """Calcula los años de antigüedad transcurridos entre dos fechas en formato YYYY-MM-DD."""
    try:
        f_ing = datetime.strptime(fecha_ingreso_str, "%Y-%m-%d")
        f_calc = datetime.strptime(fecha_calculo_str, "%Y-%m-%d")
        
        anios = f_calc.year - f_ing.year
        # Si la fecha de hoy es anterior al día de aniversario de este año, se resta 1
        if (f_calc.month, f_calc.day) < (f_ing.month, f_ing.day):
            anios -= 1
        return max(0, anios)
    except Exception:
        return 0


class MotorLiquidacion:
    """Procesa la liquidación completa de un empleado evaluando
    secuencialmente las celdas de cálculo de su esquema."""

    def __init__(self, db: DatabaseManager):
        self.db = db
        self._evaluador = SimpleEval()
        self._evaluador.operators = DEFAULT_OPERATORS
        self._evaluador.functions = {
            "round": round,
            "max": max,
            "min": min,
            "abs": abs,
            "int": int,
            "float": float,
        }

    def procesar_liquidacion(self, empleado_id: int, quincena_sel: str | None = None, fecha_calculo: str | None = None) -> dict:
        """
        Ejecuta toda la liquidación de un empleado.

        Retorna:
            {
                "empleado": { ... datos del empleado ... },
                "resultados_por_seccion": { ... },
                "resultados_grafico_custom": [ ... ],
                "contexto_final": { ... },
                "errores": [ ... ],
                "quincena_sel": "Q1" / "Q2" / None
            }
        """
        empleado = self.db.obtener_empleado(empleado_id)
        if not empleado:
            return {"empleado": None, "resultados_por_seccion": {},
                    "resultados_grafico_custom": [], "contexto_final": {},
                    "errores": ["Empleado no encontrado"]}

        errores: list[str] = []
        contexto: dict = {}

        # ==================================================================
        # PASO 0: Calcular Antigüedad Implícita por Fecha
        # ==================================================================
        if not fecha_calculo:
            fecha_calculo = date.today().strftime("%Y-%m-%d")
            
        f_ingreso = empleado.get("fecha_ingreso") or "2020-01-01"
        antiguedad_anios = calcular_antiguedad_anios(f_ingreso, fecha_calculo)
        contexto["antiguedad_anios"] = antiguedad_anios
        contexto["antiguedad"] = antiguedad_anios
        contexto["fecha_ingreso"] = f_ingreso
        contexto["fecha_calculo"] = fecha_calculo

        # ==================================================================
        # PASO 1: Inyectar Variables Globales desde SQLite
        # ==================================================================
        global_namespaces = {}  # ej: {"Q1": {"tope_sipa": 9000}}
        global_flat = {}
        try:
            glob_vars = self.db.listar_variables_globales()
            for g in glob_vars:
                cod = g["codigo"].strip()
                val_str = g["valor"].strip()
                val = parse_value(val_str)
                
                # Intentamos matchear patrones de quincena en el nombre de la variable
                q_match = None
                base_name = cod
                
                # Caso A: Notación de punto, ej: Q1.Horas_Mes
                if "." in cod:
                    ns, var_name = cod.split(".", 1)
                    ns_clean = ns.strip().upper()
                    if re.match(r'^Q\d+$', ns_clean):
                        q_match = ns_clean
                        base_name = var_name.strip()
                
                # Caso B: Sufijo de quincena, ej: Horas_Q1 o Horas_Mes_Q1
                elif re.search(r'_[qQ]\d+$', cod):
                    parts = cod.rsplit("_", 1)
                    q_match = parts[1].upper()
                    base_name = parts[0]
                    
                # Caso C: Prefijo con guion bajo, ej: Q1_Horas o Q2_Horas_Mes
                elif re.match(r'^[qQ]\d+_', cod):
                    parts = cod.split("_", 1)
                    q_match = parts[0].upper()
                    base_name = parts[1]
                
                if q_match:
                    # Lo guardamos en el namespace de la quincena con el nombre base
                    global_namespaces.setdefault(q_match, {})[base_name] = val
                    # También mantenemos el nombre original en el namespace por las dudas
                    global_namespaces[q_match][cod] = val
                else:
                    global_flat[cod] = val
        except Exception as e:
            errores.append(f"Error cargando variables globales desde la base de datos: {e}")

        # Inyectar las variables globales generales
        contexto.update(global_flat)

        # ==================================================================
        # PASO 2: Inyectar Variables del Empleado
        # ==================================================================
        try:
            variables_emp = json.loads(empleado["variables_calculo"])
        except (json.JSONDecodeError, TypeError):
            variables_emp = {}

        es_jornal = empleado["tipo_liquidacion"] == "jornal"
        quincenas_dict = {}

        if es_jornal:
            # Si el JSON tiene la estructura de quincenas
            if isinstance(variables_emp, dict) and "quincenas" in variables_emp:
                quincenas_dict = variables_emp["quincenas"]
            else:
                # Si es un dict plano (ej: empleado jornal viejo sin migrar en BD todavía)
                quincenas_dict = {"Q1": variables_emp if isinstance(variables_emp, dict) else {}}
            
            # Asegurar que al menos existe Q1
            if "Q1" not in quincenas_dict:
                quincenas_dict["Q1"] = {}
                
            # Determinar qué quincena estamos calculando
            if not quincena_sel or quincena_sel not in quincenas_dict:
                quincena_sel = sorted(quincenas_dict.keys())[0]
                
            # 1. Inyectar variables de la quincena seleccionada a nivel superior
            variables_q_sel = quincenas_dict.get(quincena_sel, {})
            contexto.update(variables_q_sel)
            
            # 2. Inyectar variables globales de esta quincena a nivel superior
            if quincena_sel in global_namespaces:
                contexto.update(global_namespaces[quincena_sel])
                
            # 3. Crear objetos de namespace para CADA quincena (Q1, Q2, etc.) y namespaces globales
            all_q_names = set(quincenas_dict.keys()) | set(global_namespaces.keys())
            for q_name in all_q_names:
                q_vars = {}
                # Variables globales específicas de la quincena
                q_vars.update(global_namespaces.get(q_name, {}))
                # Variables del empleado para la quincena (toman prioridad)
                q_vars.update(quincenas_dict.get(q_name, {}))
                
                contexto[q_name] = QuincenaNamespace(q_vars)
        else:
            # Mensual (plano)
            # Si tuviese estructura de quincenas por cambio de tipo, aplanamos Q1
            if isinstance(variables_emp, dict) and "quincenas" in variables_emp:
                variables_emp = variables_emp["quincenas"].get("Q1", {})
            contexto.update(variables_emp)
            quincena_sel = None

        # Asegurar que la antigüedad calculada por fecha sobreescribe cualquier valor manual de la BD/JSON
        contexto["antiguedad_anios"] = antiguedad_anios
        contexto["antiguedad"] = antiguedad_anios

        contexto["tipo_liquidacion"] = empleado["tipo_liquidacion"]

        # Inyectar valor de la hora de la categoría jornalera si existe
        if empleado["categoria_jornal_id"]:
            cur = self.db.conn.cursor()
            res_cat = cur.execute(
                "SELECT valor_hora FROM categorias_jornal WHERE id = ?",
                (empleado["categoria_jornal_id"],)
            ).fetchone()
            if res_cat:
                contexto["valor_hora"] = res_cat[0]
            else:
                contexto["valor_hora"] = 0.0
        else:
            contexto["valor_hora"] = 0.0

        # Obtener el esquema asignado (mensual por defecto)
        esquema = empleado.get("esquema_codigo") or "MENSUAL"

        # Leer celdas del esquema
        celdas = self.db.listar_celdas_por_esquema(esquema)

        # Pre-inicializar variables a calcular en el esquema a 0.0
        for celda in celdas:
            codigo = celda["codigo_variable"]
            contexto.setdefault(codigo, 0.0)

        # ==================================================================
        # PASO 3: Pre-computar cada quincena para agregaciones Q_sum_, etc.
        # ==================================================================
        # Esto permite que Q_sum_bruto, Q_sum_neto funcionen con campos
        # calculados del esquema, no solo variables de entrada del empleado.
        quincena_computed: dict[str, dict] = {}
        if es_jornal and quincenas_dict:
            valor_hora_ctx = contexto.get("valor_hora", 0.0)
            for q_name, q_vars in quincenas_dict.items():
                tmp = dict(global_flat)
                tmp.update(q_vars)
                if q_name in global_namespaces:
                    tmp.update(global_namespaces[q_name])
                tmp["antiguedad_anios"] = antiguedad_anios
                tmp["antiguedad"] = antiguedad_anios
                tmp["tipo_liquidacion"] = empleado["tipo_liquidacion"]
                tmp["valor_hora"] = valor_hora_ctx
                for c in celdas:
                    tmp.setdefault(c["codigo_variable"], 0.0)

                # Evaluar todas las celdas secuencialmente para esta quincena
                for c in celdas:
                    cod = c["codigo_variable"]
                    tc = c.get("tipo_calculo") or "formula"
                    cond = (c["condicion"] or "").strip()
                    if cond:
                        try:
                            if not self._eval(cond, tmp):
                                continue
                        except Exception:
                            continue
                    m = 0.0
                    if tc == "porcentaje":
                        pct = c.get("simple_porcentaje") or 0.0
                        bvar = c.get("simple_base_variable") or ""
                        m = round((pct / 100.0) * tmp.get(bvar, 0.0), 2)
                    elif tc == "fijo":
                        m = c.get("simple_monto_fijo") or 0.0
                    else:
                        fu = (c["formula_unidad"] or "").strip()
                        u = 0.0
                        if fu:
                            try:
                                u = self._eval(fu, tmp)
                            except Exception:
                                pass
                        tmp["unidad"] = u
                        fb = (c["formula_base"] or "").strip()
                        b = 0.0
                        if fb:
                            try:
                                b = self._eval(fb, tmp)
                            except Exception:
                                pass
                        tmp["base"] = b
                        fm = (c["formula_monto"] or "").strip()
                        if fm:
                            try:
                                m = self._eval(fm, tmp)
                            except Exception:
                                pass
                    if isinstance(m, (int, float)):
                        tmp[cod] = m
                quincena_computed[q_name] = tmp

        # ==================================================================
        # PASO 4: Registrar funciones agregadoras en simpleeval
        # ==================================================================
        def _q_val(q_name, var_name):
            """Obtener el valor de una variable para una quincena dada,
            buscando primero en los resultados pre-computados (incluye campos
            calculados como bruto, neto, etc.)."""
            if q_name in quincena_computed:
                val = quincena_computed[q_name].get(var_name)
                if val is not None:
                    return val
            val = quincenas_dict.get(q_name, {}).get(var_name)
            if val is not None:
                return val
            return global_namespaces.get(q_name, {}).get(var_name, 0.0)

        def sumar_q(var_name):
            total = 0.0
            for q_name in quincenas_dict:
                val = _q_val(q_name, var_name)
                if isinstance(val, (int, float)):
                    total += val
            return total

        def promedio_q(var_name):
            vals = []
            for q_name in quincenas_dict:
                val = _q_val(q_name, var_name)
                if isinstance(val, (int, float)):
                    vals.append(val)
            return sum(vals) / len(vals) if vals else 0.0

        def max_q(var_name):
            vals = []
            for q_name in quincenas_dict:
                val = _q_val(q_name, var_name)
                if isinstance(val, (int, float)):
                    vals.append(val)
            return max(vals) if vals else 0.0

        def min_q(var_name):
            vals = []
            for q_name in quincenas_dict:
                val = _q_val(q_name, var_name)
                if isinstance(val, (int, float)):
                    vals.append(val)
            return min(vals) if vals else 0.0

        def cant_q():
            return len(quincenas_dict) if es_jornal else 1

        # ==================================================================
        # PASO 5: Funciones Históricas (consultan tabla recibos)
        # ==================================================================
        emp_id_for_hist = empleado["id"]

        def sumatoria_mes(codigo_variable, mes, anio):
            """Suma el valor de una variable en todos los recibos del empleado para un mes/año."""
            recibos = self.db.buscar_recibos(emp_id_for_hist, int(mes), int(anio))
            total = 0.0
            for r in recibos:
                try:
                    datos = json.loads(r["datos_json"])
                    val = datos.get(str(codigo_variable), 0.0)
                    if isinstance(val, (int, float)):
                        total += val
                except Exception:
                    pass
            return total

        def maximo_semestre(codigo_variable, semestre, anio):
            """Retorna la mayor suma mensual de una variable dentro de un semestre."""
            semestre = int(semestre)
            anio = int(anio)
            meses_rango = range(1, 7) if semestre == 1 else range(7, 13)
            max_val = 0.0
            for m in meses_rango:
                suma_mes = sumatoria_mes(codigo_variable, m, anio)
                if suma_mes > max_val:
                    max_val = suma_mes
            return max_val

        def promedio_ultimos_n_meses(codigo_variable, meses_hacia_atras, mes_actual, anio_actual):
            """Promedio de una variable en los últimos N meses hacia atrás."""
            meses_hacia_atras = int(meses_hacia_atras)
            mes_actual = int(mes_actual)
            anio_actual = int(anio_actual)
            valores = []
            m, a = mes_actual, anio_actual
            for _ in range(meses_hacia_atras):
                m -= 1
                if m < 1:
                    m = 12
                    a -= 1
                val = sumatoria_mes(codigo_variable, m, a)
                valores.append(val)
            return sum(valores) / len(valores) if valores else 0.0

        def dias_trabajados_semestre(semestre, anio):
            """Calcula días trabajados en un semestre según fecha de ingreso del empleado."""
            semestre = int(semestre)
            anio = int(anio)
            f_ing_str = contexto.get("fecha_ingreso", "2020-01-01")
            try:
                f_ing = datetime.strptime(str(f_ing_str), "%Y-%m-%d").date()
            except Exception:
                f_ing = date(2020, 1, 1)

            if semestre == 1:
                inicio_sem = date(anio, 1, 1)
                fin_sem = date(anio, 6, 30)
            else:
                inicio_sem = date(anio, 7, 1)
                fin_sem = date(anio, 12, 31)

            # Si ingresó después del semestre, 0 días
            if f_ing > fin_sem:
                return 0
            # Si ingresó durante el semestre, contar desde fecha de ingreso
            inicio_real = max(f_ing, inicio_sem)
            return (fin_sem - inicio_real).days + 1

        self._evaluador.functions.update({
            "sumar_q": sumar_q,
            "promedio_q": promedio_q,
            "max_q": max_q,
            "min_q": min_q,
            "cant_q": cant_q,
            "sumatoria_mes": sumatoria_mes,
            "maximo_semestre": maximo_semestre,
            "promedio_ultimos_n_meses": promedio_ultimos_n_meses,
            "dias_trabajados_semestre": dias_trabajados_semestre,
        })

        contexto = MotorContextDict(contexto, sumar_q, promedio_q, max_q, min_q)

        resultados_por_seccion: dict[str, list[dict]] = {}

        for celda in celdas:
            seccion = celda["seccion_codigo"]
            codigo = celda["codigo_variable"]
            tipo_calc = celda.get("tipo_calculo") or "formula"

            # --- Evaluar condición ---
            condicion_str = (celda["condicion"] or "").strip()
            if condicion_str:
                try:
                    if not self._eval(condicion_str, contexto):
                        continue
                except Exception as e:
                    errores.append(
                        f"[{codigo}] Error en condición '{condicion_str}': {e}"
                    )
                    continue

            # --- Evaluar según el tipo de cálculo ---
            unidad = None
            base = None
            monto = 0.0

            if tipo_calc == "porcentaje":
                pct = celda.get("simple_porcentaje") or 0.0
                base_var = celda.get("simple_base_variable") or ""
                
                unidad = pct / 100.0
                base = contexto.get(base_var, 0.0)
                monto = round(unidad * base, 2)

            elif tipo_calc == "fijo":
                monto = celda.get("simple_monto_fijo") or 0.0
                unidad = None
                base = None

            else:
                formula_u = (celda["formula_unidad"] or "").strip()
                if formula_u:
                    try:
                        unidad = self._eval(formula_u, contexto)
                    except Exception as e:
                        errores.append(
                            f"[{codigo}] Error en fórmula unidad '{formula_u}': {e}"
                        )
                        unidad = 0.0
                contexto["unidad"] = unidad if unidad is not None else 0.0

                formula_b = (celda["formula_base"] or "").strip()
                if formula_b:
                    try:
                        base = self._eval(formula_b, contexto)
                    except Exception as e:
                        errores.append(
                            f"[{codigo}] Error en fórmula base '{formula_b}': {e}"
                        )
                        base = 0.0
                contexto["base"] = base if base is not None else 0.0

                formula_m = (celda["formula_monto"] or "").strip()
                if formula_m:
                    try:
                        monto = self._eval(formula_m, contexto)
                    except Exception as e:
                        errores.append(
                            f"[{codigo}] Error en fórmula monto '{formula_m}': {e}"
                        )
                        monto = 0.0

            contexto[codigo] = monto

            fila = {
                "codigo": codigo,
                "descripcion": celda["descripcion"],
                "unidad": unidad,
                "base": base,
                "monto": monto,
                "visible_recibo": celda.get("visible_recibo", 1),
            }
            resultados_por_seccion.setdefault(seccion, []).append(fila)

        # 3. Evaluar celdas del gráfico custom asociadas a este esquema
        resultados_grafico_custom = []
        try:
            celdas_g = self.db.listar_celdas_grafico_por_esquema(esquema)
            for cg in celdas_g:
                formula_g = cg["formula"].strip()
                valor_g = 0.0
                if formula_g:
                    try:
                        valor_g = self._eval(formula_g, contexto)
                    except Exception as e:
                        errores.append(f"[Gráfico: {cg['etiqueta']}] Error en fórmula '{formula_g}': {e}")
                resultados_grafico_custom.append({
                    "id": cg["id"],
                    "etiqueta": cg["etiqueta"],
                    "valor": valor_g
                })
        except Exception as e:
            errores.append(f"Error al obtener celdas del gráfico: {e}")

        return {
            "empleado": dict(empleado),
            "resultados_por_seccion": resultados_por_seccion,
            "resultados_grafico_custom": resultados_grafico_custom,
            "contexto_final": contexto,
            "errores": errores,
            "quincena_sel": quincena_sel
        }

    # ------------------------------------------------------------------
    # Persistir liquidación actual como recibo histórico
    # ------------------------------------------------------------------
    def persistir_liquidacion_actual(self, resultado: dict, mes: int, anio: int, periodo: str) -> int:
        """Toma el resultado de procesar_liquidacion y lo persiste como un recibo snapshot."""
        emp = resultado["empleado"]
        esquema = emp.get("esquema_codigo") or "MENSUAL"
        # Serializar el contexto final (contiene todas las variables calculadas)
        datos = dict(resultado["contexto_final"])
        # Limpiar objetos no-serializables (QuincenaNamespace, etc.)
        datos_limpio = {}
        for k, v in datos.items():
            if isinstance(v, (int, float, str, bool, type(None))):
                datos_limpio[k] = v
        datos_json = json.dumps(datos_limpio, ensure_ascii=False)
        return self.db.persistir_recibo(emp["id"], esquema, mes, anio, periodo, datos_json)

    def _eval(self, expresion: str, contexto: dict):
        """Evalúa una expresión con el contexto dado usando simpleeval."""
        self._evaluador.names = contexto
        return self._evaluador.eval(expresion)