# Módulo de Controladores (`src/controllers`)

El módulo `AppController` actúa como la **Fachada Principal (Façade Pattern)** de la aplicación para la capa de presentación QML. Expone todos los modelos de datos, orquesta las operaciones de liquidación, gestiona el control de ventanas y brinda acceso a diálogos nativos del sistema operativo.

---

## 🏛️ Responsabilidades de `AppController`

1. **Exposición de Modelos**: Provee punteros a todos los modelos de datos (`employeeModel`, `cellModel`, `receiptHistoryModel`, etc.) como propiedades `Q_PROPERTY` de sólo lectura y con constantes de acceso para QML.
2. **Orquestación de Liquidación**: Conecta la vista previa (`PreviewView.qml`) con `LiquidationEngine` para procesar y persistir liquidaciones.
3. **Gestión de Ventana Frameless**: Métodos para mover, minimizar, alternar maximizado y cerrar la ventana sin bordes nativos del sistema operativo.
4. **Asistente de Fórmulas**: Genera la lista clasificada de variables y funciones disponibles (`getAvailableFormulaVariables`) para autocompletado y asistencia en el editor de fórmulas.
5. **Diálogos de Archivos Nativos**: Invoca `QFileDialog` del sistema operativo (`selectSaveFile`, `selectOpenFile`, `selectFolder`) para que el usuario elija dónde guardar o abrir archivos sin rutas fijas.
6. **Gestión de Roles y Tema**: Controla el rol activo (`"admin"` / `"user"`) y el modo oscuro.

---

## 📚 Referencia de Propiedades y Métodos de `AppController`

### Propiedades (`Q_PROPERTY`)
- `currentRole` (QString, READ/WRITE, NOTIFY `roleChanged`): Rol de usuario activo (`"admin"` o `"user"`).
- `darkMode` (bool, READ/WRITE, NOTIFY `darkModeChanged`): Estado del tema oscuro.
- `employeeModel` (EmployeeModel*, CONSTANT): Modelo de padrón de empleados.
- `employeeVarsModel` (EmployeeVarsModel*, CONSTANT): Modelo de variables por empleado/quincena.
- `globalVarsModel` (GlobalVarsModel*, CONSTANT): Modelo de variables globales.
- `schemaModel` (SchemaModel*, CONSTANT): Modelo de esquemas de cálculo.
- `categoryModel` (CategoryModel*, CONSTANT): Modelo de categorías salariales.
- `cellModel` (CellModel*, CONSTANT): Modelo de celdas de cálculo.
- `chartCellModel` (ChartCellModel*, CONSTANT): Modelo de celdas de gráfico.
- `receiptHistoryModel` (ReceiptHistoryModel*, CONSTANT): Modelo del historial de recibos emitidos.
- `customFunctionModel` (CustomFunctionModel*, CONSTANT): Modelo de funciones JavaScript de usuario.

### Control de Ventanas (`Q_INVOKABLE`)
- `void startWindowMove(QQuickWindow *window)`: Inicia el arrastre interactivo de la ventana personalizada.
- `void minimizeWindow(QQuickWindow *window)`: Minimiza la ventana a la barra de tareas.
- `void toggleMaximizeWindow(QQuickWindow *window)`: Alterna entre estado maximizado y restaurado.
- `void closeWindow(QQuickWindow *window)`: Cierra la ventana y termina la aplicación.

### Liquidación y Persistencia (`Q_INVOKABLE`)
- `QVariantMap processLiquidation(int employeeId, const QString &quincenaSel = "", const QString &fechaCalculo = "")`: Ejecuta el cálculo completo de la liquidación y emite la señal `calculationErrorOccurred` si se detectan advertencias o errores.
- `int persistLiquidation(const QVariantMap &result, int mes, int anio, const QString &periodo)`: Persiste el recibo histórico y actualiza el modelo del historial.
- `QString resetNewMonth()`: Ejecuta el reseteo de nuevo mes (backup + limpieza de variables temporales) y refresca los modelos.
- `QString createBackup()`: Crea una copia de seguridad manual de la base de datos.

### Diálogos Nativos de Archivos (`Q_INVOKABLE`)
- `QString selectSaveFile(const QString &title, const QString &defaultName, const QString &filter)`: Abre el diálogo nativo de guardar archivo y devuelve la ruta seleccionada.
- `QString selectOpenFile(const QString &title, const QString &defaultDir, const QString &filter)`: Abre el diálogo nativo para seleccionar un archivo existente.
- `QString selectFolder(const QString &title, const QString &defaultDir)`: Abre el diálogo nativo para seleccionar una carpeta.

### Asistente y CRUD Auxiliares (`Q_INVOKABLE`)
- `QVariantList getAvailableFormulaVariables(const QString &esquemaCodigo)`: Devuelve una lista estructurada con funciones predefinidas, variables del empleado, variables de fecha, acumuladores y conceptos del esquema para el asistente de fórmulas.
- `QString validateVariableCode(const QString &code)`: Valida si un nombre de variable cumple con las reglas de identificador válido.
- `QVariantMap getCompany() const` / `bool saveCompany(...)`: Lectura y escritura de datos de la empresa.
- `QVariantList listSections()` / `listSchemas()` / `listCategories()`: Consultas rápidas para combos y selectores.
- `addSchemaField(...)` / `renameSchemaField(...)` / `updateSchemaField(...)` / `removeSchemaField(...)`: Gestión del modelo de insumos del esquema.
- `exportDataXlsx(...)` / `importDataXlsx(...)` / `exportDataCsv(...)` / `exportReceiptPdf(...)`: Operaciones de importación/exportación delegadas al `ExportService`.
