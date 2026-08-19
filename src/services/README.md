# Módulo de Servicios de Exportación (`src/services`)

El módulo `ExportService` gestiona la interoperabilidad y exportación documental del sistema:
1. **Generación de Recibos de Sueldo en PDF**: Renderizado vectorial A4 con `QPdfWriter` y `QPainter`.
2. **Importación y Exportación Excel (`.xlsx`)**: Lectura y escritura de planillas mediante la biblioteca `QXlsx`.
3. **Exportación e Importación CSV**: Volcado y restauración de tablas en texto plano delimitado.

---

## 📄 Generación de Recibos en PDF (`exportReceiptPdf`)

### Características Técnicas del Renderizado PDF
- **Dispositivo de Salida**: `QPdfWriter` configurado en tamaño A4 (`QPageSize(QPageSize::A4)`), orientación vertical (`QPageLayout::Portrait`) y márgenes compactos de 8 mm para garantizar que todo el contenido entre en una sola página.
- **Renderizado Vectorial**: Tipografía Helvetica nítida, líneas separadoras y tabla de conceptos con columnas alineadas (Código, Descripción, Unidad, Base Imponible, Remunerativo, No Remunerativo, Descuentos).
- **Control de Pincel (`QBrush`)**: Para prevenir artefactos y caracteres cuadrados vacíos (`□`) en Helvetica al escribir texto luego de dibujar formas geométricas rellenas, se invoca explícitamente `painter.setBrush(Qt::NoBrush)` antes de cada llamada a `drawText()`.
- **Encabezado Institucional Completo**:
  - Datos de la empresa (Razón Social, CUIT, Domicilio).
  - Datos del empleado (Legajo, Nombre, CUIL, Categoría, Fecha de Ingreso, Período Liquidado, Fecha de Pago/Emisión).
- **Gráfico de Composición Salarial (Donut Chart)**:
  - Renderizado vectorial proporcional con sectores coloreados según la configuración de cada concepto.
  - Leyenda lateral con nombres de conceptos, importes formateados en moneda argentina (`$ 123.456,78`) y porcentaje de participación sobre el total de referencia.
- **Bloque de Firmas**:
  - Líneas de firma para Empleador y Trabajador ubicadas al pie de la página (`qMax(y + 50, pageH - 90)`), garantizando un diseño profesional listo para impresión y archivo.

---

## 📊 Importación y Exportación Excel (`.xlsx`)

### Estructura de Hojas en el Archivo Excel
El formato de exportación/importación mantiene compatibilidad con la estructura del sistema original:
- **`Empleados`**: Padrón de empleados con datos personales y columnas dinámicas para los insumos del esquema.
- **`Categorias`**: Lista de categorías y valores horarios.
- **`Esquemas`**: Definición de esquemas de liquidación.
- **`Celdas`**: Fórmulas, conceptos, secciones y tipos de cálculo.
- **`Variables_Globales`**: Variables de configuración compartidas.
- **`Custom_Functions`**: Funciones JavaScript personalizadas.

---

## 📚 Referencia de Métodos de `ExportService`

- `ExportService(DatabaseManager *db, QObject *parent = nullptr)`: Constructor. Recibe el puntero a la base de datos.
- `QString exportReceiptPdf(const QVariantMap &liquidationResult, const QVariantMap &companyData, const QVariantMap &employeeData, const QString &path)`: Genera el recibo de sueldo en formato PDF vectorial. Devuelve la ruta absoluta del archivo generado.
- `QString exportDataXlsx(const QString &path)`: Exporta todas las tablas de la base de datos a un libro Excel `.xlsx` estructurado.
- `bool importDataXlsx(const QString &path)`: Lee un libro `.xlsx`, valida su estructura e importa los datos en la base de datos SQLite dentro de una transacción.
- `QString exportDataCsv(const QString &directoryPath)`: Exporta cada tabla de la base de datos como un archivo `.csv` independiente dentro del directorio especificado.
- `bool importDataCsv(const QString &directoryPath)`: Importa archivos CSV desde el directorio a sus tablas correspondientes.
- `QString ensurePdfPath(const QString &path) const`: Asegura que la ruta de salida posea extensión `.pdf` y directorio válido.
- `QString ensureXlsxPath(const QString &path) const`: Garantiza la extensión `.xlsx`.
- `QString ensureCsvDir(const QString &path) const`: Garantiza la existencia del directorio destino de los archivos CSV.
