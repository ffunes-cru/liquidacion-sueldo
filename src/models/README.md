# Módulo de Modelos Qt Quick (`src/models`)

Este módulo contiene todas las implementaciones de `QAbstractListModel` que conectan las tablas de la base de datos con las vistas de Qt Quick/QML. Proporcionan binding reactivo, filtrado en tiempo real, roles personalizados y métodos invocables (`Q_INVOKABLE`) para operaciones CRUD desde la interfaz de usuario.

---

## 📋 Lista de Modelos

| Modelo | Tabla Origen | Roles Principales | Uso en UI |
|---|---|---|---|
| `EmployeeModel` | `empleados` | `legajo`, `nombre`, `tipoLiquidacion`, `esquema`, `categoriaId`, `categoriaNombre`, `cuil` | `EmployeesView.qml`, selectores de empleados en vistas y diálogos. |
| `EmployeeVarsModel` | `schema_fields` + `employee_field_values` | `fieldId`, `fieldCode`, `fieldLabel`, `fieldType`, `value`, `defaultValue` | Editor de variables e insumos por quincena en `EmployeesView.qml`. |
| `CellModel` | `celdas_calculo` | `codigoVariable`, `descripcion`, `condicion`, `formulaMonto`, `tipoCalculo`, `simplePorcentaje`, `enGrafico` | `ReceiptStructureView.qml` (Editor de fórmulas y conceptos). |
| `ReceiptHistoryModel` | `recibos` | `receiptId`, `empleadoId`, `esquemaCodigo`, `mes`, `anio`, `periodo`, `datosJson`, `fechaEmision` | `ReceiptHistoryView.qml` (Explorador de historial y reimpresión). |
| `SchemaModel` | `esquemas_calculo` | `code`, `name`, `tipoLiquidacion` | `SchemasView.qml`, selectores de esquema. |
| `CategoryModel` | `categorias_jornal` | `id`, `name`, `valorHora` | `CategoriesView.qml`, asignación de categorías. |
| `GlobalVarsModel` | `variables_globales` | `id`, `code`, `value`, `description` | `GlobalVarsView.qml` (Variables generales del sistema). |
| `ChartCellModel` | `celdas_grafico` | `id`, `etiqueta`, `formula`, `orden`, `esquemaCodigo` | Configuración de gráficos independientes. |
| `CustomFunctionModel` | `custom_functions` | `id`, `name`, `params`, `body`, `description`, `esquemaCodigo` | `CustomFunctionsView.qml` (Editor de funciones de usuario). |

---

## 🔍 Referencia Detallada de Modelos y Métodos

### 1. `EmployeeModel`
Maneja el padrón de empleados con soporte para búsqueda y filtrado en vivo.
- **Propiedades**:
  - `count` (int, READ): Cantidad de empleados visibles tras aplicar filtros.
  - `filterText` (QString, READ/WRITE): Texto de filtro que busca por nombre o legajo.
- **Métodos Invocables (`Q_INVOKABLE`)**:
  - `void refresh()`: Recarga los empleados desde la base de datos y re-aplica el filtro.
  - `QVariantMap get(int row) const`: Devuelve los datos completos del empleado en la fila indicada.
  - `int idAtRow(int row) const`: Obtiene el ID primario del empleado en la fila dada.
  - `int addEmployee(...)`: Crea un nuevo empleado e inicializa sus campos de esquema.
  - `bool saveEmployee(...)`: Modifica los datos de un empleado existente.
  - `bool removeEmployee(int id)`: Elimina el empleado y sus valores de variables.
  - `int duplicateEmployee(int id)`: Clona el empleado y sus variables para todas las quincenas.

---

### 2. `EmployeeVarsModel`
Modelo dinámico que combina el esquema de variables (`schema_fields`) con los valores cargados del empleado (`employee_field_values`) para una quincena particular.
- **Propiedades**:
  - `employeeId` (int, READ/WRITE): ID del empleado actualmente seleccionado.
  - `quincena` (QString, READ/WRITE): Código de la quincena activa (`"Q1"`, `"Q2"`).
- **Métodos Invocables (`Q_INVOKABLE`)**:
  - `void refresh()`: Recarga la estructura de campos y los valores asignados.
  - `bool setValue(int row, const QString &value)`: Actualiza el valor de un campo específico en la base de datos y en el modelo.

---

### 3. `CellModel`
Gestiona la lista ordenada de celdas y conceptos de cálculo correspondientes al esquema activo.
- **Propiedades**:
  - `esquemaCodigo` (QString, READ/WRITE): Esquema activo cuyas celdas se presentan.
  - `count` (int, READ): Total de celdas en el esquema.
- **Métodos Invocables (`Q_INVOKABLE`)**:
  - `void refresh()`: Recarga las celdas ordenadas por `orden`.
  - `QVariantMap get(int row) const`: Obtiene todos los atributos de una celda.
  - `int saveCell(...)`: Guarda o modifica una celda, gestionando flags de gráfico y porcentajes.
  - `bool updateCellColor(int id, const QString &colorHex)`: Actualiza el color de visualización del concepto en el gráfico.
  - `bool removeCell(int id)`: Elimina la celda de cálculo.
  - `bool moveCellUp(int index)` / `bool moveCellDown(int index)`: Reordena la posición de cálculo secuencial de la celda.
  - `bool moveCell(int fromIndex, int toIndex)`: Mueve una celda a una posición específica actualizando los índices en la base de datos.

---

### 4. `ReceiptHistoryModel`
Permite consultar, filtrar y gestionar los snapshots históricos de liquidaciones emitidas.
- **Propiedades**:
  - `employeeId` (int, READ/WRITE): Filtra los recibos por empleado.
  - `count` (int, READ): Cantidad de recibos históricos disponibles.
- **Métodos Invocables (`Q_INVOKABLE`)**:
  - `void refresh()`: Consulta los recibos del empleado en la base de datos.
  - `bool removeReceipt(int id)`: Elimina un recibo histórico específico.
  - `QVariantMap getReceipt(int id) const`: Retorna el registro del recibo y su payload JSON.

---

### 5. `SchemaModel`, `CategoryModel`, `GlobalVarsModel`, `ChartCellModel`, `CustomFunctionModel`
Modelos CRUD directos que implementan:
- `refresh()`: Sincronización completa con la base de datos.
- `get(int index)`: Consulta de registro por índice.
- `save...()`: Inserción o actualización atómica.
- `remove...()`: Eliminación por ID o código primario.
