"""
motor.py — Motor de Liquidación Secuencial.
Evalúa celdas paramétricas (simples o fórmulas) y propaga resultados.
Soporta inyección de categorías jornaleras, esquemas de cálculo y inicialización de variables para evitar errores.
"""

import json
from simpleeval import SimpleEval, DEFAULT_OPERATORS
from database import DatabaseManager


class MotorLiquidacion:
    """Procesa la liquidación completa de un empleado evaluando
    secuencialmente las celdas de cálculo de su esquema."""

    def __init__(self, db: DatabaseManager):
        self.db = db
        # Configurar evaluador seguro
        self._evaluador = SimpleEval()
        self._evaluador.operators = DEFAULT_OPERATORS
        # Funciones permitidas dentro de las fórmulas
        self._evaluador.functions = {
            "round": round,
            "max": max,
            "min": min,
            "abs": abs,
            "int": int,
            "float": float,
        }

    # ------------------------------------------------------------------
    # API pública
    # ------------------------------------------------------------------
    def procesar_liquidacion(self, empleado_id: int) -> dict:
        """
        Ejecuta toda la liquidación de un empleado.

        Retorna:
            {
                "empleado": { ... datos del empleado ... },
                "resultados_por_seccion": { ... },
                "resultados_grafico_custom": [ ... ],
                "contexto_final": { ... },
                "errores": [ ... ]
            }
        """
        empleado = self.db.obtener_empleado(empleado_id)
        if not empleado:
            return {"empleado": None, "resultados_por_seccion": {},
                    "resultados_grafico_custom": [], "contexto_final": {},
                    "errores": ["Empleado no encontrado"]}

        # 1. Inicializar contexto con variables de entrada del empleado
        try:
            variables = json.loads(empleado["variables_calculo"])
        except (json.JSONDecodeError, TypeError):
            variables = {}

        contexto: dict = {}
        contexto.update(variables)
        contexto["tipo_liquidacion"] = empleado["tipo_liquidacion"]

        # Inyectar valor de la hora de la categoría jornalera si existe
        if empleado["categoria_jornal_id"]:
            # Obtener valor
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

        # 2. Leer celdas del esquema
        celdas = self.db.listar_celdas_por_esquema(esquema)
        errores: list[str] = []

        # --- Clave del sistema ---
        # Pre-inicializar TODAS las variables que se calcularán en el esquema a 0.0.
        # Esto previene que si una celda es ignorada por su condición (ej: horas extras = 0),
        # las fórmulas siguientes que la sumen o utilicen (ej: bruto o neto) no rompan por variable indefinida.
        for celda in celdas:
            codigo = celda["codigo_variable"]
            contexto.setdefault(codigo, 0.0)

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
                        # La celda no se evalúa (se mantiene en 0.0 en el contexto)
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
                # Modo Simple: Porcentaje de otra variable
                pct = celda.get("simple_porcentaje") or 0.0
                base_var = celda.get("simple_base_variable") or ""
                
                unidad = pct / 100.0
                base = contexto.get(base_var, 0.0)
                monto = round(unidad * base, 2)

            elif tipo_calc == "fijo":
                # Modo Simple: Monto Fijo directo
                monto = celda.get("simple_monto_fijo") or 0.0
                unidad = None
                base = None

            else:
                # Modo Avanzado: Fórmulas matemáticas
                # Evaluar unidad
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

                # Evaluar base
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

                # Evaluar monto
                formula_m = (celda["formula_monto"] or "").strip()
                if formula_m:
                    try:
                        monto = self._eval(formula_m, contexto)
                    except Exception as e:
                        errores.append(
                            f"[{codigo}] Error en fórmula monto '{formula_m}': {e}"
                        )
                        monto = 0.0

            # --- Inyectar resultado calculado en el contexto de evaluación ---
            contexto[codigo] = monto

            # --- Guardar resultado formateado ---
            fila = {
                "codigo": codigo,
                "descripcion": celda["descripcion"],
                "unidad": unidad,
                "base": base,
                "monto": monto,
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
        }

    # ------------------------------------------------------------------
    # Evaluador interno
    # ------------------------------------------------------------------
    def _eval(self, expresion: str, contexto: dict):
        """Evalúa una expresión con el contexto dado usando simpleeval."""
        self._evaluador.names = contexto
        return self._evaluador.eval(expresion)
