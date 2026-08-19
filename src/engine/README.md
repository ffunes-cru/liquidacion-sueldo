# Módulo de Motores de Cálculo (`src/engine`)

El motor de cálculo es el núcleo aritmético y normativo del sistema. Se compone de tres subsistemas coordinados:

1. **`FormulaEngine`**: Intérprete de fórmulas matemáticas y lógicas basado en `QJSEngine`, con soporte para sintaxis Python y funciones nativas.
2. **`LiquidationEngine`**: Orquestador del pipeline completo de liquidación, resolución de contextos, evaluación de conceptos y persistencia de snapshots.
3. **`QuincenaAggregator`**: Módulo de agregación matemática para liquidaciones jornaleras (`sumar_q`, `promedio_q`, `max_q`, `min_q`, `cant_q`).

---

## 🚀 `FormulaEngine`

### Características Principales
- **Intérprete ECMAScript Seguro**: Ejecuta expresiones aisladas usando `QJSEngine`.
- **Transpilación Python -> JavaScript**:
  - Operador ternario Python: `A if COND else B` -> `((COND) ? (A) : (B))`.
  - Operadores lógicos: `and` -> `&&`, `or` -> `||`, `not` -> `!`.
  - Literales booleanos: `True` -> `true`, `False` -> `false`.
- **Funciones Matemáticas Incorporadas**:
  - `round(value, decimals)`: Redondeo aritmético estándar.
  - `abs(x)`, `floor(x)`, `ceil(x)`, `int_(x)` (truncamiento a entero).
  - `min(a, b, ...)` y `max(a, b, ...)`: Soporte variádico estilo Python.
- **Auto-inicialización Segura de Variables No Definidas**:
  - Para evitar que errores de tipeo o referencias a variables condicionales detengan el proceso con `ReferenceError`, las variables no reconocidas fuera de cadenas de texto se inicializan a `0.0` y se registra una advertencia en el log y en el resultado de la liquidación.
- **Inyección del Objeto `env`**:
  - Expone un objeto global estructurado para funciones de usuario avanzadas (`env.empleado`, `env.quincenas`, `env.historial`, `env.globals`).

### Referencia de Métodos de `FormulaEngine`
- `FormulaEngine(QObject *parent = nullptr)`: Constructor. Instancia el motor `QJSEngine` e instala las funciones globales.
- `~FormulaEngine()`: Destructor.
- `void setContext(const QVariantMap &context)`: Carga el mapa de variables en el contexto del motor.
- `void setVariable(const QString &name, const QVariant &value)`: Actualiza o añade una variable individual en el contexto.
- `QVariant getVariable(const QString &name) const`: Obtiene el valor actual de una variable del contexto.
- `void registerFunction(const QString &name, QJSValue callable)`: Registra una función invocable en el scope global.
- `QVariant evaluate(const QString &formula, QString *error = nullptr)`: Evalúa una fórmula o expresión matemática/lógica y devuelve el resultado tipado (`double`, `bool`, `QString`).
- `void registerCustomFunctions(const QVariantList &functions)`: Registra funciones de usuario escritas en JavaScript desde la base de datos.
- `void setEnvObject(const QVariantMap &envData)`: Inyecta el objeto estructurado global `env`.
- `bool evaluateCondition(const QString &condition, QString *error = nullptr)`: Evalúa una condición booleana. Si está vacía, devuelve `true`.
- `void reset()`: Limpia variables, estado y reinicializa el motor `QJSEngine`.
- `QStringList autoInitializedVars() const`: Lista las variables que fueron auto-inicializadas a 0.0 durante la última evaluación.
- `void clearAutoInitializedVars()`: Limpia el registro de auto-inicializaciones.

---

## ⚙️ `LiquidationEngine`

### Pipeline de Liquidación (`processLiquidation`)

1. **Paso 0 - Antigüedad**:
   Calcula la antigüedad en años cumplidos considerando año, mes y día entre `fecha_ingreso` y `fecha_calculo`.
2. **Paso 1 - Inyección de Variables Globales**:
   Carga variables de `variables_globales`. Si tienen prefijos/sufijos de quincena (`Q1.`, `_Q1`, `Q1_`), las organiza en namespaces de quincenas.
3. **Paso 2 - Inyección de Insumos de Empleado**:
   - Carga insumos desde `employee_field_values`.
   - Inyecta metadatos del empleado (`legajo`, `nombre`, `cuil`, `valor_hora`, `jornal`, etc.).
   - Inyecta variables de fecha (`FECHA_CALCULO`, `MES_CALCULO`, `ANIO_CALCULO`, `DIA_CALCULO`).
4. **Paso 3 - Pre-cálculo de Quincenas**:
   Evalúa previamente cada quincena activa mediante `buildQuincenaContext` para alimentar los agregadores de quincenas (`sumar_q`, etc.) y `env.quincenas`.
5. **Paso 4 - Carga de Historial y Objeto `env`**:
   - Lee los recibos históricos emitidos del empleado (`listReceiptsByEmployee`).
   - Mapea los importes históricos por `cell_id` y por nombre actual del concepto (resolución de renombrado).
   - Inyecta `env.historial`, `env.empleado`, `env.quincenas` y `env.globals`.
6. **Paso 5 - Evaluación Secuencial de Celdas**:
   - Itera las celdas ordenadas por `orden`.
   - Evalúa `condicion`. Si no se cumple, omite la celda.
   - Evalúa según `tipo_calculo`:
     - `formula`: evalúa `formula_unidad`, `formula_base`, `formula_monto`.
     - `porcentaje`: `base * (pct / 100)`.
     - `fijo`: asigna importe fijo.
     - `simple`: `(base * pct / 100) + montoFijo`.
     - `separator`: monto = 0.
   - Inserta el resultado en el contexto para uso de las celdas posteriores.
7. **Paso 6 - Evaluación de Celdas de Gráfico**:
   Evalúa fórmulas de gráficos configurados.

### Persistencia de Recibos (`persistLiquidation`)
Genera un snapshot JSON completo estructurado en:
- `meta`: `empleado_id`, `esquema_codigo`, `mes`, `anio`, `periodo`, `fecha_calculo`.
- `totales`: `total_remunerativo`, `total_no_remunerativo`, `total_descuentos`, `neto_a_cobrar`.
- `variables`: Mapa exhaustivo de insumos y variables intermedias.
- `conceptos`: Lista de filas con `cell_id`, `codigo`, `descripcion`, `seccion`, `unidad`, `base`, `monto`, `tipo_calculo`.

### Referencia de Métodos de `LiquidationEngine`
- `LiquidationEngine(DatabaseManager *db, QObject *parent = nullptr)`: Constructor.
- `QVariantMap processLiquidation(int employeeId, const QString &quincenaSel = "", const QString &fechaCalculo = "")`: Ejecuta el cálculo integral de la liquidación.
- `int persistLiquidation(const QVariantMap &result, int mes, int anio, const QString &periodo)`: Persiste el recibo histórico en la base de datos como snapshot inmutable.
- `int calculateSeniorityYears(const QString &fechaIngreso, const QString &fechaCalculo) const`: Función auxiliar de cálculo de antigüedad exacta.
- `QVariantMap buildQuincenaContext(...)`: Construye y evalúa el contexto aislado de una quincena particular.

---

## 📊 `QuincenaAggregator`

Módulo matemático utilitario para consolidar datos entre quincenas de un empleado jornalero.

### Referencia de Métodos de `QuincenaAggregator`
- `void setQuincenaData(const QMap<QString, QVariantMap> &data)`: Establece los datos precalculados de las quincenas.
- `double sumarQ(const QString &varName) const`: Suma el valor de la variable en todas las quincenas.
- `double promedioQ(const QString &varName) const`: Promedio del valor de la variable en las quincenas.
- `double maxQ(const QString &varName) const`: Valor máximo registrado.
- `double minQ(const QString &varName) const`: Valor mínimo registrado.
- `int cantQ() const`: Cantidad de quincenas cargadas.
- `double getQuincenaValue(const QString &quincenaCode, const QString &varName) const`: Obtiene el valor puntual de una quincena.
- `QStringList quincenaCodes() const`: Lista de quincenas disponibles.
