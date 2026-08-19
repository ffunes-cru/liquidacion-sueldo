# Módulo de Base de Datos (`src/database`)

Este módulo encapsula toda la interacción con SQLite 3 mediante `QSqlDatabase` y `QSqlQuery`. Garantiza la integridad referencial (`PRAGMA foreign_keys = ON`), la concurrencia eficiente mediante modo WAL (`PRAGMA journal_mode = WAL`), y el bloqueo de instancia única mediante `QLockFile`.

---

## 🗄️ Esquema Relacional de Tablas

### 1. `esquemas_calculo`
Define los tipos o plantillas de liquidación (ej. mensual, jornal, convenio comercio, etc.).
- `codigo` (TEXT PRIMARY KEY): Identificador único del esquema (ej. `"MENSUAL"`, `"JORNAL"`).
- `nombre` (TEXT NOT NULL): Nombre descriptivo.
- `tipo_liquidacion` (TEXT NOT NULL DEFAULT 'mensual'): Tipo base (`'mensual'` o `'jornal'`).

### 2. `categorias_jornal`
Categorías salariales para empleados por jornal/hora.
- `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
- `nombre` (TEXT UNIQUE NOT NULL): Nombre de la categoría (ej. `"Oficial Especializado"`).
- `valor_hora` (REAL NOT NULL): Tarifa monetaria horaria o base.

### 3. `secciones`
Secciones de agrupación de conceptos para presentación en el recibo.
- `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
- `codigo` (TEXT UNIQUE NOT NULL): Código de sección (`'COMPOSICION'`, `'RECIBO'`, `'COSTO_EMP'`).
- `titulo` (TEXT NOT NULL): Título visible en UI/PDF.
- `orden` (INTEGER NOT NULL DEFAULT 0): Orden de visualización.

### 4. `empleados`
Padrón de empleados de la empresa.
- `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
- `legajo` (TEXT): Número de legajo.
- `nombre_completo` (TEXT NOT NULL): Nombre y apellido.
- `tipo_liquidacion` (TEXT NOT NULL DEFAULT 'mensual'): Modalidad (`'mensual'` o `'jornal'`).
- `esquema_codigo` (TEXT REFERENCES esquemas_calculo(codigo)): Esquema asociado.
- `categoria_jornal_id` (INTEGER REFERENCES categorias_jornal(id)): Categoría (para jornaleros).
- `fecha_ingreso` (TEXT DEFAULT '2020-01-01'): Fecha de ingreso (formato `YYYY-MM-DD`).
- `cuil` (TEXT DEFAULT ''): Código Único de Identificación Laboral.

### 5. `schema_fields`
Modelo abstracto de variables/insumos de entrada definidos a nivel de esquema.
- `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
- `esquema_codigo` (TEXT NOT NULL REFERENCES esquemas_calculo(codigo) ON DELETE CASCADE).
- `field_code` (TEXT NOT NULL): Nombre de variable técnica (ej. `"horas_trabajadas"`).
- `field_label` (TEXT NOT NULL): Etiqueta legible para la UI.
- `field_type` (TEXT NOT NULL DEFAULT 'number'): Tipo de dato (`'number'`, `'text'`, `'boolean'`).
- `default_value` (TEXT NOT NULL DEFAULT '0'): Valor por defecto para nuevos empleados.
- `display_order` (INTEGER NOT NULL DEFAULT 0): Orden en el formulario de variables.
- *Constraint*: `UNIQUE(esquema_codigo, field_code)`.

### 6. `employee_field_values`
Valores concretos de insumos para cada empleado y período/quincena.
- `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
- `empleado_id` (INTEGER NOT NULL REFERENCES empleados(id) ON DELETE CASCADE).
- `field_id` (INTEGER NOT NULL REFERENCES schema_fields(id) ON DELETE CASCADE).
- `quincena` (TEXT NOT NULL DEFAULT 'Q1'): Código de quincena (`'Q1'`, `'Q2'`).
- `value` (TEXT NOT NULL DEFAULT '0'): Valor asignado.
- *Constraint*: `UNIQUE(empleado_id, field_id, quincena)`.

### 7. `quincenas_empleado`
Registro de quincenas activas habilitadas por empleado jornalero.
- `empleado_id` (INTEGER NOT NULL REFERENCES empleados(id) ON DELETE CASCADE).
- `quincena` (TEXT NOT NULL): Código de la quincena.
- *Constraint*: `PRIMARY KEY(empleado_id, quincena)`.

### 8. `celdas_calculo`
Fórmulas y conceptos dinámicos que integran la liquidación.
- `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
- `seccion_codigo` (TEXT NOT NULL REFERENCES secciones(codigo)).
- `codigo_variable` (TEXT NOT NULL): Identificador de la variable resultante (ej. `"basico"`, `"jubilacion"`).
- `descripcion` (TEXT NOT NULL): Descripción legible en el recibo.
- `condicion` (TEXT DEFAULT ''): Expresión condicional para evaluar si la celda se liquida.
- `formula_unidad` (TEXT DEFAULT ''): Fórmula para la columna Unidad/Cantidad.
- `formula_base` (TEXT DEFAULT ''): Fórmula para la columna Base Imponible.
- `formula_monto` (TEXT NOT NULL): Fórmula del importe final o expresión de cálculo.
- `orden` (INTEGER NOT NULL DEFAULT 0): Posición de cálculo secuencial.
- `esquema_codigo` (TEXT REFERENCES esquemas_calculo(codigo)).
- `tipo_calculo` (TEXT NOT NULL DEFAULT 'formula'): Modo (`'formula'`, `'porcentaje'`, `'fijo'`, `'simple'`, `'separator'`).
- `simple_porcentaje` (REAL): Porcentaje si tipo es porcentaje/simple.
- `simple_base_variable` (TEXT): Variable base de aplicación.
- `simple_monto_fijo` (REAL): Importe fijo monetario.
- `visible_recibo` (INTEGER DEFAULT 1): Indicador de impresión en recibo PDF.
- `color_hex` (TEXT DEFAULT ''): Color para el gráfico de torta.
- `en_grafico` (INTEGER DEFAULT 0): Flag para incluir en gráfico de composición salarial.
- `es_grafico_total` (INTEGER DEFAULT 0): Flag de referencia base (100%) para el gráfico.
- *Constraint*: `UNIQUE(esquema_codigo, codigo_variable)`.

### 9. `variables_globales`
Parámetros compartidos por toda la empresa (topes, salarios mínimos, SMVM).
- `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
- `codigo` (TEXT UNIQUE NOT NULL): Nombre de la variable global.
- `valor` (TEXT NOT NULL): Valor escalar o alfanumérico.
- `descripcion` (TEXT DEFAULT ''): Detalle explicativo.

### 10. `empresa`
Datos institucionales y fiscales de la empresa empleadora.
- `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
- `razon_social` (TEXT NOT NULL DEFAULT '').
- `direccion` (TEXT DEFAULT '').
- `cuit` (TEXT DEFAULT '').
- `lugar_de_pago` (TEXT DEFAULT '').

### 11. `recibos` (Historial de Liquidaciones)
Tabla de almacenamiento histórico e inmutable de recibos emitidos.
- `id` (INTEGER PRIMARY KEY AUTOINCREMENT).
- `empleado_id` (INTEGER NOT NULL REFERENCES empleados(id)).
- `esquema_codigo` (TEXT NOT NULL).
- `mes` (INTEGER NOT NULL): Número de mes (1 al 12).
- `anio` (INTEGER NOT NULL): Año (ej. 2026).
- `periodo` (TEXT NOT NULL DEFAULT 'M'): Descripción del período (ej. `"Mes 8/2026 (Q1)"` o `"M"`).
- `datos_json` (TEXT NOT NULL): Snapshot JSON exhaustivo con conceptos, importes, variables y totales.
- `fecha_emision` (TEXT NOT NULL): Marca temporal exacta de persistencia.
- *Constraint*: `UNIQUE(empleado_id, esquema_codigo, mes, anio, periodo)`.

### 12. `configuraciones` y `custom_functions`
- `configuraciones`: Parámetros de configuración clave-valor persistentes.
- `custom_functions`: Funciones de usuario en JavaScript persistidas en la BD (`name`, `params`, `body`, `description`, `esquema_codigo`).

---

## 📚 Referencia de Funciones de `DatabaseManager`

### Ciclo de Vida y Concurrencia
- `DatabaseManager(const QString &dbPath, QObject *parent = nullptr)`: Abre la conexión SQLite, inicializa el bloqueo mediante `QLockFile` (si no es `:memory:`), habilita WAL y Foreign Keys, crea tablas y ejecuta migraciones.
- `~DatabaseManager()`: Cierra la base de datos de manera limpia y libera el archivo de bloqueo `.lock`.
- `bool isOpen() const`: Devuelve `true` si la base de datos está abierta.
- `bool isLockedByOtherInstance() const`: Devuelve `true` si otra instancia del proceso tiene bloqueado el archivo.
- `QString lockError() const`: Mensaje descriptivo con el PID del proceso bloqueante.
- `qint64 lockingPid() const`: PID del proceso que retiene el bloqueo.
- `QString databasePath() const`: Ruta física al archivo de base de datos.

### Transacciones
- `bool transaction()`: Inicia una transacción SQLite atómica.
- `bool commit()`: Confirma los cambios de la transacción.
- `bool rollback()`: Revierte los cambios ante fallas.

### Gestión de Esquemas (`esquemas_calculo`)
- `QVariantList listSchemas() const`: Obtiene todos los esquemas ordenados por código.
- `QVariantMap getSchema(const QString &code) const`: Obtiene un esquema por su código.
- `bool saveSchema(const QString &originalCode, const QString &newCode, const QString &name, const QString &tipoLiquidacion)`: Inserta o actualiza un esquema.
- `bool deleteSchema(const QString &code)`: Elimina un esquema y sus celdas/campos asociados en cascada si no posee empleados asignados.

### Gestión de Categorías (`categorias_jornal`)
- `QVariantList listCategories() const`: Lista todas las categorías por nombre.
- `QVariantMap getCategory(int id) const`: Retorna los datos de una categoría.
- `int saveCategory(int id, const QString &name, double valorHora)`: Inserta o actualiza una categoría. Retorna su ID.
- `bool deleteCategory(int id)`: Elimina una categoría si no está en uso.

### Gestión de Secciones (`secciones`)
- `QVariantList listSections() const`: Retorna las secciones ordenadas por `orden`.

### Gestión de Empleados (`empleados`)
- `QVariantList listEmployees() const`: Lista todos los empleados con nombre de categoría y esquema.
- `QVariantMap getEmployee(int id) const`: Obtiene la ficha completa de un empleado.
- `int saveEmployee(...)`: Inserta o actualiza un empleado y sincroniza sus variables predeterminadas.
- `bool deleteEmployee(int id)`: Elimina un empleado y sus valores de variables (en cascada).
- `int duplicateEmployee(int sourceId)`: Duplica un empleado existente clonando su ficha y todos sus valores de variables para todas las quincenas.

### Modelo de Variables de Esquema (`schema_fields` y `employee_field_values`)
- `QVariantList listSchemaFields(const QString &esquemaCodigo) const`: Lista los campos de insumo de un esquema.
- `int addSchemaField(...)`: Añade un nuevo campo a un esquema e inicializa su valor por defecto para todos los empleados de ese esquema.
- `bool removeSchemaField(int fieldId)`: Elimina un campo y todos sus valores asociados en los empleados.
- `bool renameSchemaField(int fieldId, const QString &newCode, const QString &newLabel)`: Renombra el código y etiqueta de un campo.
- `bool updateSchemaField(...)`: Actualiza tipo, valor por defecto y etiqueta de un campo.
- `QVariantList getEmployeeFieldValues(int employeeId, const QString &quincena) const`: Retorna los valores de insumo de un empleado para una quincena específica.
- `bool setEmployeeFieldValue(int employeeId, int fieldId, const QString &quincena, const QString &value)`: Actualiza o inserta un valor puntual.
- `bool setEmployeeFieldValues(int employeeId, const QString &quincena, const QVariantMap &values)`: Actualiza en lote los valores de un empleado mediante transacción.
- `void syncEmployeeFieldsForSchema(const QString &esquemaCodigo)`: Asegura que todos los empleados de un esquema tengan registros creados para todos los campos definidos.

### Gestión de Quincenas (`quincenas_empleado`)
- `QStringList listEmployeeQuincenas(int employeeId) const`: Lista las quincenas asignadas a un empleado.
- `bool addQuincena(int employeeId, const QString &quincenaCode)`: Habilita una nueva quincena para un empleado y clona los valores por defecto.
- `bool removeQuincena(int employeeId, const QString &quincenaCode)`: Elimina una quincena y sus valores para el empleado.

### Celdas de Cálculo (`celdas_calculo`)
- `QVariantList listCellsBySchema(const QString &esquemaCodigo) const`: Retorna las celdas de un esquema ordenadas por la columna `orden`.
- `int saveCell(...)`: Inserta o actualiza una celda de cálculo. Si `esGraficoTotal` es `true`, desmarca automáticamente cualquier otra celda totalizadora en el mismo esquema.
- `bool updateCellColor(int id, const QString &colorHex)`: Actualiza únicamente el color de gráfico de una celda.
- `bool deleteCell(int id)`: Elimina una celda de cálculo.

### Celdas de Gráfico (`celdas_grafico`)
- `QVariantList listChartCellsBySchema(const QString &esquemaCodigo) const`: Retorna celdas de gráfico independientes.
- `int saveChartCell(...)`: Inserta o actualiza una celda de gráfico.
- `bool deleteChartCell(int id)`: Elimina una celda de gráfico.

### Variables Globales y Funciones Personalizadas
- `QVariantList listGlobalVariables() const`: Lista todas las variables globales.
- `int saveGlobalVariable(...)`: Inserta o actualiza una variable global.
- `bool deleteGlobalVariable(int id)`: Elimina una variable global.
- `QVariantList listCustomFunctions(const QString &esquemaCodigo) const`: Lista funciones JavaScript definidas por el usuario.
- `int saveCustomFunction(...)`: Guarda o actualiza una función de usuario.
- `bool deleteCustomFunction(int id)`: Elimina una función de usuario.

### Empresa y Configuración
- `QVariantMap getCompany() const`: Retorna los datos de la empresa.
- `bool saveCompany(...)`: Guarda la información fiscal e institucional.
- `QString getConfig(const QString &key, const QString &defaultValue) const`: Lee un valor de configuración.
- `void setConfig(const QString &key, const QString &value)`: Guarda un valor de configuración.

### Recibos Históricos (`recibos`)
- `QVariantList listReceiptsByEmployee(int employeeId) const`: Lista los recibos emitidos para un empleado ordenados cronológicamente descendente.
- `QVariantMap getReceipt(int id) const`: Retorna el registro de un recibo histórico con su snapshot JSON completo.
- `int saveReceipt(int employeeId, const QString &esquemaCodigo, int mes, int anio, const QString &periodo, const QString &datosJson)`: Inserta o actualiza (upsert) un recibo histórico.
- `bool deleteReceipt(int id)`: Elimina un recibo histórico por ID.
- `QVariantList searchReceipts(int employeeId, int mes, int anio) const`: Busca recibos de un empleado en un mes y año dados.

### Mantenimiento y Backups
- `QString createBackup()`: Crea una copia timestamped de la base de datos en el mismo directorio.
- `QString resetNewMonth()`: Ejecuta una copia de seguridad automática y resetea las variables mensuales de horas y días de vacaciones a `0`, eliminando quincenas adicionales distintas de `Q1`.
