# Arquitectura del Backend C++ / Qt

El sistema de Liquidación de Sueldos está construido sobre **C++20** y el framework **Qt 6.5+**, utilizando una arquitectura desacoplada en capas:

```
┌──────────────────────────────────────────────────────────────────┐
│                           Capa QML / UI                          │
│   (Vistas, Componentes reutilizables, Diálogos, Singletons)       │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ Q_INVOKABLE / Q_PROPERTY / Signals
┌─────────────────────────────────▼────────────────────────────────┐
│                   Controladores (src/controllers)                │
│   AppController (Fachada principal de la aplicación para QML)    │
├──────────────────────────────────────────────────────────────────┤
│                       Modelos (src/models)                       │
│   QAbstractListModel especializados para binding reactivo en QML │
│   (EmployeeModel, CellModel, EmployeeVarsModel, ReceiptHistory...)│
├─────────────────────────────────┬────────────────────────────────┤
│       Servicios (src/services)  │     Motores (src/engine)       │
│   ExportService                 │   LiquidationEngine            │
│   (Excel QXlsx, CSV, PDF)       │   FormulaEngine (QJSEngine)    │
│                                 │   QuincenaAggregator           │
└─────────────────────────────────┴────────────────────────────────┘
                                  │
┌─────────────────────────────────▼────────────────────────────────┐
│                   Base de Datos (src/database)                   │
│   DatabaseManager (SQLite WAL, QLockFile, Migraciones, CRUD)     │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📁 Módulos del Sistema

| Directorio | Descripción | Responsabilidad Principal |
|---|---|---|
| [`src/database/`](file:///home/ffunes/Documentos/liquidacion%20sueldo/src/database/README.md) | Capa de Persistencia SQLite | Conexión, esquema relacional, migraciones, transacciones, bloqueo de instancia única y operaciones CRUD. |
| [`src/engine/`](file:///home/ffunes/Documentos/liquidacion%20sueldo/src/engine/README.md) | Motor de Cálculo y Fórmulas | Evaluación de fórmulas JS/Python, orquestación de liquidación, agregación de quincenas y resolución de namespaces (`env.`, `Q1.`, `_history`). |
| [`src/models/`](file:///home/ffunes/Documentos/liquidacion%20sueldo/src/models/README.md) | Modelos de Datos Qt Quick | Implementaciones de `QAbstractListModel` con roles personalizados para binding bidireccional fluido en QML. |
| [`src/services/`](file:///home/ffunes/Documentos/liquidacion%20sueldo/src/services/README.md) | Servicios de Exportación | Generación de recibos PDF vectoriales (`QPdfWriter`), importación/exportación Excel (`QXlsx`) y CSV. |
| [`src/controllers/`](file:///home/ffunes/Documentos/liquidacion%20sueldo/src/controllers/README.md) | Controlador y Fachada | Puente central entre backend C++ y UI QML, diálogos nativos y gestión de ventanas frameless. |

---

## 🔄 Flujo de Ejecución de una Liquidación

1. **Entrada**: El usuario selecciona un empleado, la quincena (si es jornalero) y la fecha de cálculo en `PreviewView.qml`.
2. **Invocación**: `AppController::processLiquidation(employeeId, quincena, fechaCalculo)` delega a `LiquidationEngine::processLiquidation`.
3. **Cálculo de Antigüedad**: Se calcula la antigüedad exacta en años a partir de `fecha_ingreso` y `fecha_calculo`.
4. **Inyección de Insumos**:
   - Variables globales de `variables_globales` (con resolución de sufijos `_Q1`, prefijos `Q1_` o notación de punto `Q1.`).
   - Insumos del empleado desde `schema_fields` y `employee_field_values`.
   - Inyección de metadatos (`legajo`, `nombre`, `cuil`, `valor_hora`, etc.).
5. **Construcción del Objeto `env`**:
   - `env.empleado`: Objeto con metadatos del empleado.
   - `env.quincenas`: Arreglo con datos precalculados de cada quincena.
   - `env.historial`: Arreglo con snapshots JSON de recibos anteriores para cálculos históricos (SAC, vacaciones, promedios).
   - `env.globals`: Mapa de variables globales.
6. **Evaluación Secuencial de Celdas**:
   - Cada celda en `celdas_calculo` evalúa su condición (si existe).
   - Se evalúa según su `tipo_calculo` (`formula`, `porcentaje`, `fijo`, `simple`, `separator`).
   - El resultado numérico se almacena inmediatamente en el contexto para que las siguientes celdas puedan referenciarlo por nombre.
7. **Snapshot y Persistencia**:
   - Al confirmar el guardado, `persistLiquidation` genera un payload JSON exhaustivo con metadata, conceptos con `cell_id` y totales, persistiendo en la tabla `recibos`.
