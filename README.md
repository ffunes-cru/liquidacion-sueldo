# Manual de Usuario — Sistema de Liquidación de Sueldos y Costo Laboral

Este documento proporciona una guía de usuario completa para comprender y operar el mini-sistema de liquidación de sueldos. El sistema ha sido diseñado bajo una filosofía flexible, permitiendo la adaptación de conceptos, fórmulas y visualizaciones a través de una interfaz interactiva.

---

## 1. Modos de Acceso (Roles)

En la parte superior de la ventana principal, el selector **Modo** permite alternar entre dos roles con diferentes niveles de privilegios:

### Modo Administrador (Acceso Total)
Diseñado para la configuración estructural de la empresa y del motor de cálculo. Permite:
- **Gestión Estructural**: Modificar, añadir y eliminar categorías jornaleras, esquemas de cálculo (ABM), estructuras de recibos (orden, fórmulas, condiciones de aplicación y visibilidad) y la distribución del gráfico de torta.
- **Acciones de Riesgo**: Botón **⚠ Nuevo Mes** para resetear los acumuladores de los empleados con generación de copias de seguridad de la base de datos.
- **Campos Globales**: Agregar y eliminar variables globales libremente (código, valor y descripción).
- **Empleados**: Modificación completa de fichas, incluyendo agregar/quitar variables de cálculo y añadir/eliminar quincenas.

### Modo Usuario (Acceso Operativo Controlado)
Diseñado para la liquidación mensual de manera segura y sin posibilidad de romper fórmulas o la estructura del sistema. Sus restricciones son:
- **Pestañas Ocultas**: Solo son visibles las pestañas de **Empleados**, **Campos Globales** y **Vista Previa**. Las pestañas de configuración y fórmulas están ocultas.
- **Variables de Cálculo Inteligentes**:
  - En la pestaña de empleados, las variables de cálculo se muestran con controles específicos: **Checkboxes** para valores booleanos (verdadero/falso), **SpinBoxes** numéricos con flechas para ingresar horas o montos con facilidad, y cuadros de texto estándar para cadenas.
  - Los nombres de las variables son de solo lectura (en fondo gris) y el botón de eliminación está desactivado. No se pueden agregar variables ni quincenas.
- **Acceso a Empleados**: El usuario solo puede duplicar empleados existentes para crear nuevos y modificar sus datos básicos (nombre, legajo, tipo asignado, categoría, fecha de ingreso).
- **Variables Globales Protegidas**: Solo se permite cambiar el valor de las variables existentes. No se pueden agregar, borrar ni modificar los códigos ni descripciones.
- **Seguridad**: El botón global de reinicio "Nuevo Mes" y los botones de eliminación de empleados están ocultos para prevenir la pérdida accidental de datos.

---

## 2. Sistema de Quincenas para Empleados Jornaleros

Para empleados que cobran de forma quincenal (jornaleros), el sistema ofrece un flujo especializado:

### Carga de Quincenas
En la pestaña de **Empleados**, las variables dinámicas se organizan en sub-pestañas por quincena (`Q1`, `Q2`, etc.).
- En modo Administrador, es posible agregar quincenas pulsando **+ Agregar Quincena** (que duplicará las variables de la quincena base Q1 para agilizar la carga) o eliminar quincenas no deseadas.

### Variables Quincenales Globales
Para evitar tener que cargar variables comunes (como el total de horas laborales del mes de forma manual en cada empleado), se puede definir en **Campos Globales** variables quincenales usando sufijos (`_Q1`/`_Q2`), prefijos (`Q1_`/`Q2_`) o puntos (`Q1.`/`Q2.`):
- *Ejemplo*: Si definís la variable global `Horas_Mes_Q1 = 97` y `Horas_Mes_Q2 = 105`.
- Al realizar la liquidación de la quincena **Q1**, la variable estará disponible en el motor de fórmulas directamente como `Horas_Mes` (con valor 97).
- Al liquidar la quincena **Q2**, `Horas_Mes` resolverá automáticamente a 105.

### Fórmulas y Agregadores Quincenales
El motor matemático expone variables de agregación integradas para realizar cálculos acumulativos del mes:
- **Prefijos Dinámicos**:
  - `Q_sum_<variable>`: Suma el valor a través de todas las quincenas. Ej: `Q_sum_basico` (suma el básico de Q1, Q2, etc.), o `Q_sum_horas_trabajadas`.
  - `Q_avg_<variable>`: Promedio de la variable entre quincenas.
  - `Q_max_<variable>` / `Q_min_<variable>`: Valor máximo y mínimo alcanzado.
- **Funciones de Fórmula**:
  - `sumar_q('variable')`, `promedio_q('variable')`, `max_q('variable')`, `min_q('variable')` (equivalentes a los prefijos anteriores).
  - `cant_q()`: Devuelve el número total de quincenas cargadas en el empleado.

---

## 3. Antigüedad Automática por Fecha de Ingreso

El sistema calcula de forma implícita y automática la antigüedad del empleado:
1. En la pestaña **Empleados**, se debe registrar la **Fecha de Ingreso**.
2. En la pestaña **Vista Previa**, se selecciona la **Fecha de Cálculo** de la liquidación.
3. El motor calcula la diferencia en años enteros y la inyecta al contexto de evaluación bajo las variables **`antiguedad_anios`** y **`antiguedad`**.
4. Podés usar esta variable de forma directa en las condiciones y fórmulas de tus conceptos (por ejemplo, una celda con condición `antiguedad_anios > 0` y monto `round(unidad * base * 0.01, 2)` para aplicar un 1% por año de antigüedad).

---

## 4. Visibilidad de Conceptos y Modo Debug

Para permitir realizar cálculos intermedios (como bases imponibles o cálculos acumulativos patronales) sin ensuciar el recibo oficial:
- En la pestaña **Estructura del Recibo** se dispone del checkbox **Mostrar en Recibo**.
- Si se desmarca, el concepto se calculará y estará disponible en el motor para otras fórmulas, pero no se mostrará en el árbol de resultados de la Vista Previa ni en los archivos PDF/Excel/ODS exportados.
- En la pestaña **Vista Previa**, podés marcar el checkbox **Modo Debug (mostrar ocultos)** para visualizar en color atenuado todos los conceptos calculados del esquema (incluyendo los marcados como no visibles) para propósitos de verificación.

---

## 5. Cierre y Operaciones de Fin de Mes (Nuevo Mes)

Cuando se finaliza el mes y se desea comenzar a liquidar el período siguiente, el Administrador puede pulsar el botón **⚠ Nuevo Mes**:
1. **Copia de Seguridad**: El sistema creará de manera automática un archivo de backup de la base de datos en el mismo directorio (ej. `liquidacion_sueldos_backup_2026-07-16_12-00-00.db`) para garantizar que nunca se pierda el historial.
2. **Reinicio de Variables**: En todos los empleados se reiniciarán a `0` las variables de entrada como `horas_trabajadas`, `horas_extras_50`, `horas_extras_100` y `dias_vacaciones`.
3. **Limpieza de Quincenas**: Las quincenas adicionales del mes anterior se removerán, dejando únicamente la quincena base `Q1` lista para la nueva carga.

---

## 6. Exportación Masiva a PDF

Para facilitar la generación masiva de recibos al final de la quincena o mes:
1. Dirigirse a la pestaña **Vista Previa**.
2. Hacer clic en el botón **Exportación Masiva a PDF...** (ubicado en el panel inferior derecho).
3. Seleccionar el **Período** a exportar:
   - *Todas las Quincenas y Mensuales (Todo)*: Genera todos los recibos de todas las quincenas de empleados jornaleros y los mensuales de empleados mensuales.
   - *Solo Primera Quincena (Q1)*: Filtra únicamente el recibo Q1 de jornaleros.
   - *Solo Segunda Quincena (Q2)*: Filtra únicamente el recibo Q2 de jornaleros.
   - *Solo Mensuales*: Genera únicamente los recibos de empleados de tipo mensual.
4. Definir la **Fecha de Cálculo** para calcular la antigüedad correcta de cada empleado.
5. Hacer clic en **Seleccionar Carpeta y Exportar** para elegir el directorio donde se guardarán los archivos.
6. El sistema procesará a todos los empleados secuencialmente y guardará los PDFs correspondientes utilizando una nomenclatura descriptiva: `recibo_<legajo>_<quincena>.pdf` o `recibo_<legajo>_Mensual.pdf`.

---

## 7. Persistencia de Datos y Compilación de Ejecutables

### Persistencia y Ubicación de la Base de Datos (`liquidacion_sueldos.db`)
El sistema gestiona la ubicación de la base de datos SQLite de forma inteligente según el entorno de ejecución:
- **Modo Desarrollo (`python main.py`)**: La base de datos `liquidacion_sueldos.db` se ubica en el directorio raíz del código fuente.
- **Modo Ejecutable Empaquetado (`PyInstaller`)**: Al compilar la aplicación como ejecutable portátil en Windows (`.exe`) o Linux, la base de datos se ubica dinámicamente en la **raíz de la carpeta donde se encuentra guardado el archivo ejecutable** (`sys.executable`).

De esta manera, la base de datos **no** se empaqueta de forma estática en la memoria temporal de PyInstaller (`_MEIPASS`), lo que garantiza la persistencia real de todos los datos introducidos (empleados, esquemas, liquidaciones y copias de seguridad de nuevo mes) sin riesgo de pérdida al cerrar el programa.

### Compilación con PyInstaller (`liquidacion.spec`)
Para empaquetar la aplicación en un único archivo ejecutable portátil:

1. **Instalar PyInstaller**:
   ```bash
   pip install pyinstaller
   ```
2. **Ejecutar la compilación**:
   ```bash
   pyinstaller liquidacion.spec
   ```
3. **Resultado**: El ejecutable generado estará disponible en la carpeta `dist/` (`dist/LiquidacionSueldos.exe` en Windows o `dist/LiquidacionSueldos` en Linux).
