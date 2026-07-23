"""
gemini_assistant.py — Integración con Google Gemini API para asistente ERP de liquidación de sueldos.
Soporta auditoría inteligente, validación no harcodeada de esquemas, simulación de cálculos,
modificación de fórmulas y gestión de gráficos.
"""

import json
import urllib.request
import urllib.error
from database import DatabaseManager
from motor import MotorLiquidacion

GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

TOOLS_DECLARATION = [
    {
        "function_declarations": [
            {
                "name": "auditar_y_obtener_esquema_completo",
                "description": "Obtiene la estructura completa de un esquema (conceptos, fórmulas, secciones, orden, barras de gráfico y variables de empleado) para inspeccionar, analizar o auditar de punta a punta.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "esquema_codigo": {"type": "STRING", "description": "Código del esquema a auditar (ej: UOM, COMERCIO, MENSUAL)"}
                    },
                    "required": ["esquema_codigo"]
                }
            },
            {
                "name": "simular_y_evaluar_esquema",
                "description": "Ejecuta una liquidación simulada de prueba para evaluar la exactitud matemática y detectar errores de fórmula en un esquema.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "esquema_codigo": {"type": "STRING", "description": "Código del esquema a simular"},
                        "fecha_calculo": {"type": "STRING", "description": "Fecha del cálculo 'YYYY-MM-DD'"},
                        "quincena": {"type": "STRING", "description": "Opcional: 'Q1' o 'Q2' para liquidación jornalera"}
                    },
                    "required": ["esquema_codigo"]
                }
            },
            {
                "name": "crear_esquema",
                "description": "Crea un nuevo esquema de cálculo en la base de datos (ej: COMERCIO, UOCRA, UOM, CONSTRUCCION).",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "codigo": {"type": "STRING", "description": "Código único en mayúsculas sin espacios (ej: COMERCIO)"},
                        "nombre": {"type": "STRING", "description": "Nombre descriptivo del convenio o esquema (ej: Convenio Empleados de Comercio)"}
                    },
                    "required": ["codigo", "nombre"]
                }
            },
            {
                "name": "agregar_concepto_calculo",
                "description": "Agrega un concepto de liquidación o fórmula a un esquema de cálculo existente.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "esquema_codigo": {"type": "STRING", "description": "Código del esquema asignado (ej: MENSUAL, COMERCIO, UOM)"},
                        "seccion_codigo": {"type": "STRING", "description": "Código de la sección en el recibo (ej: COMPOSICION, RECIBO, COSTO_EMP)"},
                        "codigo_variable": {"type": "STRING", "description": "Nombre de la variable de salida (ej: basico, presentismo, total_remunerativo, jubilacion, neto)"},
                        "descripcion": {"type": "STRING", "description": "Descripción del concepto impreso en el recibo"},
                        "formula_monto": {"type": "STRING", "description": "Fórmula matemática o expresión de simpleeval para el monto (ej: basico * 0.0833)"},
                        "condicion": {"type": "STRING", "description": "Condición lógica para incluir el concepto (ej: asistencia_perfecta == True)"},
                        "formula_unidad": {"type": "STRING", "description": "Expresión para la columna Unidad/% (ej: 0.0833 para 8.33%)"},
                        "formula_base": {"type": "STRING", "description": "Expresión para la columna Base imponible (ej: basico)"},
                        "orden": {"type": "INTEGER", "description": "Número de orden relativo de impresión (ej: 10, 20, 30)"},
                        "tipo_calculo": {"type": "STRING", "description": "'formula', 'porcentaje' o 'fijo'"}
                    },
                    "required": ["esquema_codigo", "seccion_codigo", "codigo_variable", "descripcion", "formula_monto"]
                }
            },
            {
                "name": "modificar_concepto_calculo",
                "description": "Modifica la fórmula, descripción, sección o parámetros de un concepto existente en un esquema.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "esquema_codigo": {"type": "STRING", "description": "Código del esquema (ej: UOM)"},
                        "codigo_variable": {"type": "STRING", "description": "Nombre de la variable a modificar (ej: jubilacion)"},
                        "nueva_descripcion": {"type": "STRING", "description": "Nueva descripción para el recibo"},
                        "nueva_formula_monto": {"type": "STRING", "description": "Nueva fórmula matemática para el cálculo"},
                        "nueva_condicion": {"type": "STRING", "description": "Nueva condición lógica"},
                        "nueva_seccion": {"type": "STRING", "description": "Nueva sección (ej: RECIBO)"},
                        "nuevo_orden": {"type": "INTEGER", "description": "Nuevo orden de impresión"}
                    },
                    "required": ["esquema_codigo", "codigo_variable"]
                }
            },
            {
                "name": "eliminar_concepto_calculo",
                "description": "Elimina un concepto de cálculo de un esquema.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "esquema_codigo": {"type": "STRING", "description": "Código del esquema"},
                        "codigo_variable": {"type": "STRING", "description": "Nombre de la variable a eliminar"}
                    },
                    "required": ["esquema_codigo", "codigo_variable"]
                }
            },
            {
                "name": "crear_empleado",
                "description": "Registra un nuevo empleado en la base de datos.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "legajo": {"type": "STRING", "description": "Número de legajo (ej: 0001)"},
                        "nombre_completo": {"type": "STRING", "description": "Nombre completo del empleado"},
                        "tipo_liquidacion": {"type": "STRING", "description": "'mensual' o 'jornal'"},
                        "esquema_codigo": {"type": "STRING", "description": "Código del esquema asignado (ej: MENSUAL, JORNAL, COMERCIO)"},
                        "variables_json": {"type": "STRING", "description": "JSON string con las variables iniciales (ej: '{\"basico\": 600000, \"antiguedad_anios\": 3}')"},
                        "fecha_ingreso": {"type": "STRING", "description": "Fecha de ingreso 'YYYY-MM-DD'"},
                        "cuil": {"type": "STRING", "description": "CUIL del empleado (ej: 20-12345678-9)"}
                    },
                    "required": ["nombre_completo", "tipo_liquidacion", "esquema_codigo"]
                }
            },
            {
                "name": "crear_seccion",
                "description": "Crea una nueva sección para organizar conceptos en el recibo de sueldo.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "codigo": {"type": "STRING", "description": "Código único en mayúsculas (ej: PREMIOS)"},
                        "titulo": {"type": "STRING", "description": "Título mostrado en la cabecera (ej: Premios y Bonificaciones)"},
                        "orden": {"type": "INTEGER", "description": "Número de orden de impresión (ej: 15)"}
                    },
                    "required": ["codigo", "titulo"]
                }
            },
            {
                "name": "gestionar_celdas_grafico",
                "description": "Permite listar, crear o eliminar barras de gráfico custom para la visualización del recibo de sueldo en un esquema.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "accion": {"type": "STRING", "description": "'listar', 'crear' o 'eliminar'"},
                        "esquema_codigo": {"type": "STRING", "description": "Código del esquema (ej: UOM, MENSUAL)"},
                        "celda_id": {"type": "INTEGER", "description": "ID de la barra a eliminar (para accion='eliminar')"},
                        "etiqueta": {"type": "STRING", "description": "Nombre visible en el gráfico (ej: Neto UOM)"},
                        "formula": {"type": "STRING", "description": "Fórmula para el valor de la barra (ej: neto)"},
                        "orden": {"type": "INTEGER", "description": "Orden en el gráfico (ej: 10, 20)"}
                    },
                    "required": ["accion"]
                }
            },
            {
                "name": "crear_esquema_uom_completo",
                "description": "Crea o reconfigura automáticamente el esquema UOM (Convenio Metalúrgico CCT 260/75) con todos los conceptos, deducciones legales AFIP, cuota sindical UOM y barras de gráfico.",
                "parameters": {"type": "OBJECT", "properties": {}}
            },
            {
                "name": "listar_esquemas",
                "description": "Lista todos los esquemas de cálculo definidos en el sistema.",
                "parameters": {"type": "OBJECT", "properties": {}}
            },
            {
                "name": "listar_empleados",
                "description": "Lista los empleados registrados en el sistema.",
                "parameters": {"type": "OBJECT", "properties": {}}
            },
            {
                "name": "obtener_resumen_erp",
                "description": "Obtiene un resumen cuantitativo del estado actual del ERP (empresa, cantidad de empleados, esquemas, secciones y recibos históricos).",
                "parameters": {"type": "OBJECT", "properties": {}}
            }
        ]
    }
]


class GeminiToolExecutor:
    """Ejecuta llamadas a funciones solicitadas por Gemini sobre la base de datos."""

    def __init__(self, db: DatabaseManager):
        self.db = db

    def ejecutar(self, name: str, args: dict) -> dict:
        try:
            if name == "auditar_y_obtener_esquema_completo":
                esq_code = args["esquema_codigo"].strip().upper()
                esquemas = self.db.listar_esquemas()
                esq_info = next((e for e in esquemas if e["codigo"] == esq_code), None)
                if not esq_info:
                    return {"status": "error", "message": f"Esquema '{esq_code}' no encontrado."}

                celdas = self.db.listar_celdas_por_esquema(esq_code)
                secciones = self.db.listar_secciones()
                graficos = self.db.listar_celdas_grafico_por_esquema(esq_code)
                empleados = [e for e in self.db.listar_empleados() if e["esquema_codigo"] == esq_code]

                vars_ejemplo = {}
                if empleados:
                    try:
                        vars_ejemplo = json.loads(empleados[0]["variables_calculo"] or "{}")
                    except Exception:
                        pass

                return {
                    "status": "ok",
                    "esquema": esq_info,
                    "total_conceptos": len(celdas),
                    "conceptos": [
                        {
                            "id": c["id"],
                            "seccion": c["seccion_codigo"],
                            "variable": c["codigo_variable"],
                            "descripcion": c["descripcion"],
                            "formula": c["formula_monto"],
                            "condicion": c.get("condicion", ""),
                            "orden": c.get("orden", 0),
                            "tipo_calculo": c.get("tipo_calculo", "formula")
                        }
                        for c in celdas
                    ],
                    "secciones_sistema": [s["codigo"] for s in secciones],
                    "barras_grafico": [
                        {"id": g["id"], "etiqueta": g["etiqueta"], "formula": g["formula"], "orden": g["orden"]}
                        for g in graficos
                    ],
                    "variables_empleado_muestra": vars_ejemplo
                }

            elif name == "simular_y_evaluar_esquema":
                esq_code = args["esquema_codigo"].strip().upper()
                fecha_calc = args.get("fecha_calculo", "2026-07-20")
                quincena = args.get("quincena")

                motor = MotorLiquidacion(self.db)
                empleados = [e for e in self.db.listar_empleados() if e["esquema_codigo"] == esq_code]
                if empleados:
                    emp_id = empleados[0]["id"]
                else:
                    emp_id = self.db.guardar_empleado(None, "9999", "Empleado Pruebas Simulación", "mensual", json.dumps({"basico": 500000}), esq_code, None)

                res = motor.procesar_liquidacion(emp_id, quincena_sel=quincena, fecha_calculo=fecha_calc)
                
                resumen_secciones = {}
                for sec, filas in res["resultados_por_seccion"].items():
                    resumen_secciones[sec] = [{"variable": f["codigo"], "descripcion": f["descripcion"], "monto": f["monto"]} for f in filas]

                return {
                    "status": "ok",
                    "esquema": esq_code,
                    "empleado_prueba": res["empleado"]["nombre_completo"],
                    "errores_calculo": res["errores"],
                    "resultados_calculados": resumen_secciones,
                    "contexto_final_totales": {
                        "bruto": res["contexto_final"].get("bruto", 0),
                        "total_deducciones": res["contexto_final"].get("total_deducciones", 0),
                        "neto": res["contexto_final"].get("neto", 0),
                        "costo_laboral_total": res["contexto_final"].get("costo_laboral_total", 0)
                    }
                }

            elif name == "modificar_concepto_calculo":
                esq = args["esquema_codigo"].strip().upper()
                var = args["codigo_variable"].strip()
                celdas = self.db.listar_celdas_por_esquema(esq)
                target = next((c for c in celdas if c["codigo_variable"] == var), None)
                if not target:
                    return {"status": "error", "message": f"Concepto '{var}' no encontrado en esquema '{esq}'."}
                
                self.db.guardar_celda(
                    celda_id=target["id"],
                    seccion_codigo=(args.get("nueva_seccion") or target["seccion_codigo"]).strip().upper(),
                    codigo_variable=var,
                    descripcion=(args.get("nueva_descripcion") or target["descripcion"]).strip(),
                    condicion=(args["nueva_condicion"] if "nueva_condicion" in args else target.get("condicion", "")),
                    formula_unidad=target.get("formula_unidad", ""),
                    formula_base=target.get("formula_base", ""),
                    formula_monto=(args.get("nueva_formula_monto") or target["formula_monto"]).strip(),
                    orden=(args["nuevo_orden"] if "nuevo_orden" in args else target.get("orden", 0)),
                    esquema_codigo=esq,
                    tipo_calculo=target.get("tipo_calculo", "formula"),
                    simple_porcentaje=target.get("simple_porcentaje"),
                    simple_base_variable=target.get("simple_base_variable"),
                    simple_monto_fijo=target.get("simple_monto_fijo")
                )
                return {"status": "ok", "message": f"Concepto '{var}' del esquema '{esq}' modificado correctamente."}

            elif name == "eliminar_concepto_calculo":
                esq = args["esquema_codigo"].strip().upper()
                var = args["codigo_variable"].strip()
                celdas = self.db.listar_celdas_por_esquema(esq)
                target = next((c for c in celdas if c["codigo_variable"] == var), None)
                if not target:
                    return {"status": "error", "message": f"Concepto '{var}' no existe en esquema '{esq}'."}
                
                self.db.eliminar_celda(target["id"])
                return {"status": "ok", "message": f"Concepto '{var}' eliminado del esquema '{esq}'."}

            elif name == "crear_esquema":
                codigo = args["codigo"].strip().upper()
                nombre = args["nombre"].strip()
                self.db.guardar_esquema(None, codigo, nombre)
                return {"status": "ok", "message": f"Esquema '{codigo}' ({nombre}) creado correctamente."}

            elif name == "agregar_concepto_calculo":
                self.db.guardar_celda(
                    celda_id=None,
                    seccion_codigo=args["seccion_codigo"].strip().upper(),
                    codigo_variable=args["codigo_variable"].strip(),
                    descripcion=args["descripcion"].strip(),
                    condicion=args.get("condicion", ""),
                    formula_unidad=args.get("formula_unidad", ""),
                    formula_base=args.get("formula_base", ""),
                    formula_monto=args["formula_monto"].strip(),
                    orden=args.get("orden", 0),
                    esquema_codigo=args["esquema_codigo"].strip().upper(),
                    tipo_calculo=args.get("tipo_calculo", "formula"),
                    simple_porcentaje=args.get("simple_porcentaje"),
                    simple_base_variable=args.get("simple_base_variable"),
                    simple_monto_fijo=args.get("simple_monto_fijo")
                )
                return {"status": "ok", "message": f"Concepto '{args['codigo_variable']}' agregado al esquema '{args['esquema_codigo']}'."}

            elif name == "crear_empleado":
                v_json = args.get("variables_json", "{}")
                if isinstance(v_json, dict):
                    v_json = json.dumps(v_json)
                emp_id = self.db.guardar_empleado(
                    emp_id=None,
                    legajo=args.get("legajo", ""),
                    nombre=args["nombre_completo"],
                    tipo_liq=args.get("tipo_liquidacion", "mensual"),
                    variables_json=v_json,
                    esquema_codigo=args.get("esquema_codigo", "MENSUAL"),
                    categoria_jornal_id=None,
                    fecha_ingreso=args.get("fecha_ingreso", "2020-01-01"),
                    cuil=args.get("cuil", "")
                )
                return {"status": "ok", "message": f"Empleado '{args['nombre_completo']}' registrado con ID {emp_id}."}

            elif name == "crear_seccion":
                sec_id = self.db.guardar_seccion(
                    sec_id=None,
                    codigo=args["codigo"].strip().upper(),
                    titulo=args["titulo"].strip(),
                    orden=args.get("orden", 0)
                )
                return {"status": "ok", "message": f"Sección '{args['codigo']}' ({args['titulo']}) creada con ID {sec_id}."}

            elif name == "listar_esquemas":
                esquemas = self.db.listar_esquemas()
                return {"status": "ok", "esquemas": esquemas}

            elif name == "listar_empleados":
                empleados = self.db.listar_empleados()
                result = [{"id": e["id"], "legajo": e["legajo"], "nombre": e["nombre_completo"], "esquema": e["esquema_codigo"], "tipo": e["tipo_liquidacion"]} for e in empleados]
                return {"status": "ok", "empleados": result}

            elif name == "obtener_resumen_erp":
                empresa = self.db.obtener_empresa()
                num_emp = len(self.db.listar_empleados())
                num_esq = len(self.db.listar_esquemas())
                num_sec = len(self.db.listar_secciones())
                return {
                    "status": "ok",
                    "empresa": empresa.get("razon_social") or "Sin definir",
                    "total_empleados": num_emp,
                    "total_esquemas": num_esq,
                    "total_secciones": num_sec
                }

            elif name == "crear_esquema_uom_completo":
                esq_code = "UOM"
                self.db.guardar_esquema(None, esq_code, "Convenio Metalúrgico CCT 260/75 (UOM)")
                
                conceptos_uom = [
                    ("COMPOSICION", "basico", "Sueldo Básico Metalúrgico", "basico", "", "", "", 10, "formula"),
                    ("COMPOSICION", "presentismo_uom", "Presentismo UOM (10% CCT 260/75)", "basico * 0.10", "presentismo == True", "0.10", "basico", 20, "formula"),
                    ("COMPOSICION", "antiguedad_uom", "Antigüedad Metalúrgica (1% x Año)", "basico * 0.01 * antiguedad_anios", "antiguedad_anios > 0", "antiguedad_anios * 0.01", "basico", 30, "formula"),
                    ("COMPOSICION", "total_remunerativo", "Total Remunerativo Metalúrgico", "basico + presentismo_uom + antiguedad_uom", "", "", "", 40, "formula"),
                    
                    ("RECIBO", "jubilacion", "Jubilación (Ley 24.241 - 11%)", "total_remunerativo * 0.11", "", "0.11", "total_remunerativo", 50, "formula"),
                    ("RECIBO", "ley_19032", "INSSJP (Ley 19.032 - 3%)", "total_remunerativo * 0.03", "", "0.03", "total_remunerativo", 60, "formula"),
                    ("RECIBO", "obra_social", "Obra Social Metalúrgica (OSUOMRA - 3%)", "total_remunerativo * 0.03", "", "0.03", "total_remunerativo", 70, "formula"),
                    ("RECIBO", "sindicato_uom", "Cuota Sindical UOM (2.5%)", "total_remunerativo * 0.025", "afiliado_sindicato == True", "0.025", "total_remunerativo", 80, "formula"),
                    ("RECIBO", "total_deducciones", "Total Deducciones de Ley y Convenio", "jubilacion + ley_19032 + obra_social + sindicato_uom", "", "", "", 90, "formula"),
                    ("RECIBO", "neto", "Sueldo Neto a Cobrar (UOM)", "total_remunerativo - total_deducciones", "", "", "", 100, "formula"),

                    ("COSTO_EMP", "contrib_jubilacion", "Contribución Patronal Jubilación (10.77%)", "total_remunerativo * 0.1077", "", "0.1077", "total_remunerativo", 110, "formula"),
                    ("COSTO_EMP", "contrib_obra_social", "Contribución Patronal OSUOMRA (6%)", "total_remunerativo * 0.06", "", "0.06", "total_remunerativo", 120, "formula"),
                    ("COSTO_EMP", "total_cargas_patronales", "Total Cargas Patronales UOM", "contrib_jubilacion + contrib_obra_social", "", "", "", 130, "formula"),
                    ("COSTO_EMP", "costo_laboral_total", "Costo Laboral Total Empresa UOM", "total_remunerativo + total_cargas_patronales", "", "", "", 140, "formula"),
                ]

                for sec, var, desc, form, cond, un, base, ord_val, tipo in conceptos_uom:
                    self.db.guardar_celda(None, sec, var, desc, cond, un, base, form, ord_val, esq_code, tipo, None, None, None)

                graficos_uom = [
                    ("Remunerativo UOM", "total_remunerativo", 10),
                    ("Deducciones UOM", "total_deducciones", 20),
                    ("Neto a Cobrar UOM", "neto", 30),
                    ("Costo Laboral UOM", "costo_laboral_total", 40)
                ]
                for etiq, form, ord_val in graficos_uom:
                    self.db.guardar_celda_grafico(None, etiq, form, ord_val, esq_code)

                return {"status": "ok", "message": "Esquema UOM (Convenio Metalúrgico CCT 260/75) configurado completamente con 14 conceptos, deducciones AFIP y 4 barras de gráfico."}

            elif name == "gestionar_celdas_grafico":
                accion = args.get("accion", "listar").lower()
                esquema = args.get("esquema_codigo", "MENSUAL").upper()

                if accion == "listar":
                    celdas_g = self.db.listar_celdas_grafico_por_esquema(esquema)
                    return {"status": "ok", "esquema": esquema, "celdas_grafico": celdas_g}
                elif accion == "crear":
                    etiq = args.get("etiqueta", "Barra Gráfica").strip()
                    form = args.get("formula", "neto").strip()
                    ord_val = args.get("orden", 10)
                    cid = self.db.guardar_celda_grafico(None, etiq, form, ord_val, esquema)
                    return {"status": "ok", "message": f"Barra gráfica '{etiq}' creada para el esquema '{esquema}' con ID {cid}."}
                elif accion == "eliminar":
                    cid = args.get("celda_id")
                    if cid:
                        self.db.eliminar_celda_grafico(cid)
                        return {"status": "ok", "message": f"Barra gráfica con ID {cid} eliminada."}
                    return {"status": "error", "message": "Se requiere celda_id para eliminar."}

            else:
                return {"status": "error", "message": f"Función '{name}' no soportada."}
        except Exception as e:
            return {"status": "error", "message": str(e)}


class GeminiAssistantClient:
    """Cliente para comunicarse con Google Gemini API con soporte multi-turn y Tool Calling."""

    def __init__(self, api_key: str, db: DatabaseManager):
        self.api_key = api_key
        self.executor = GeminiToolExecutor(db)
        self.system_instruction = (
            "Sos el Asistente Inteligente y Auditor Principal de Liquidación de Sueldos y MiniERP en Argentina. "
            "Tenés capacidades plenas para auditar, inspeccionar, validar, simular y corregir cualquier esquema de cálculo, concepto, fórmula o gráfico en tiempo real sin restricciones harcodeadas.\n"
            "Cuando el usuario te pida validar, revisar o corregir un esquema de cálculo (como UOM, Comercio, Mensual, etc.):\n"
            "1. Utilizá 'auditar_y_obtener_esquema_completo' y 'simular_y_evaluar_esquema' para obtener todos los conceptos, secciones, barras de gráfico y simular el cálculo de sueldo real.\n"
            "2. Evaluá con tu amplio conocimiento de la legislación argentina (Ley 20.744, AFIP, Libro de Sueldos Digital, Jubilación 11%, INSSJP 3%, Obra Social 3%, Total Remunerativo, Total Descuentos, Neto, Leyes de Convenio) si el esquema está correcto.\n"
            "3. Inspeccioná si las fórmulas matemáticas o condiciones tienen errores de sintaxis o variables no definidas.\n"
            "4. También podés gestionar o auditar las barras de gráfico del recibo con 'gestionar_celdas_grafico'.\n"
            "5. Si encontrás errores o faltantes, explicáselos al usuario claramente en Markdown y utilizá las herramientas 'agregar_concepto_calculo', 'modificar_concepto_calculo', 'eliminar_concepto_calculo' o 'gestionar_celdas_grafico' para realizar o proponer las correcciones en la base de datos automáticamente.\n"
            "Sé amable, técnico, conciso y profesional."
        )

    def enviar_mensaje(self, prompt: str, historial: list = None) -> tuple[str, bool]:
        """
        Envía un prompt a Gemini. Retorna (respuesta_texto, fue_modificada_db).
        """
        if not self.api_key:
            return ("⚠ **No se configuró la clave de API de Gemini.**\n\nPor favor diríjase a **Menú -> Modo -> Configuración del Sistema** e ingrese su **GEMINI_API_KEY**.", False)

        contents = []
        if historial:
            contents.extend(historial)
            
        contents.append({
            "role": "user",
            "parts": [{"text": prompt}]
        })

        payload = {
            "contents": contents,
            "system_instruction": {
                "parts": [{"text": self.system_instruction}]
            },
            "tools": TOOLS_DECLARATION
        }

        url = f"{GEMINI_API_URL}?key={self.api_key}"
        db_modificada = False

        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode("utf-8"))

            candidates = data.get("candidates", [])
            if not candidates:
                return ("No se recibió respuesta de Gemini API.", False)

            content = candidates[0].get("content", {})
            parts = content.get("parts", [])
            
            # Verificar si Gemini solicita llamar una función (Function Call)
            function_calls = [p for p in parts if "functionCall" in p]
            
            if function_calls:
                tool_results_parts = []
                for fc in function_calls:
                    call_data = fc["functionCall"]
                    fn_name = call_data["name"]
                    fn_args = call_data.get("args", {})

                    exec_res = self.executor.ejecutar(fn_name, fn_args)
                    db_modificada = True

                    tool_results_parts.append({
                        "functionResponse": {
                            "name": fn_name,
                            "response": exec_res
                        }
                    })

                contents.append(content)
                contents.append({
                    "role": "user",
                    "parts": tool_results_parts
                })

                payload_turn2 = {
                    "contents": contents,
                    "system_instruction": {
                        "parts": [{"text": self.system_instruction}]
                    },
                    "tools": TOOLS_DECLARATION
                }

                req2 = urllib.request.Request(
                    url,
                    data=json.dumps(payload_turn2).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST"
                )
                with urllib.request.urlopen(req2, timeout=30) as resp2:
                    data2 = json.loads(resp2.read().decode("utf-8"))

                cand2 = data2.get("candidates", [])
                if cand2:
                    text_parts = [p.get("text", "") for p in cand2[0].get("content", {}).get("parts", []) if "text" in p]
                    return ("\n".join(text_parts), db_modificada)

            text_parts = [p.get("text", "") for p in parts if "text" in p]
            return ("\n".join(text_parts), db_modificada)

        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8")
            return (f"❌ **Error de la API de Gemini (HTTP {e.code}):**\n`{err_body}`", False)
        except Exception as e:
            return (f"❌ **Error al comunicar con Gemini:** {e}", False)
