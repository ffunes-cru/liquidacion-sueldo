#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QObject>
#include <QSqlDatabase>
#include <QVariantMap>
#include <QVariantList>
#include <QString>

#include <QLockFile>

/**
 * @brief Manages the SQLite database for the payroll system.
 *
 * New relational design for employee variables:
 * - schema_fields: defines what input fields exist per schema (immutable model)
 * - employee_field_values: stores actual values per employee per quincena
 *
 * All employees of the same schema share the exact same field structure.
 * Adding/removing fields is done at the schema level and cascades to all employees.
 */
class DatabaseManager : public QObject
{
    Q_OBJECT

public:
    explicit DatabaseManager(const QString &dbPath = QString(), QObject *parent = nullptr);
    ~DatabaseManager();

    bool isOpen() const;
    bool isLockedByOtherInstance() const;
    QString lockError() const;
    qint64 lockingPid() const;
    QString databasePath() const;

    // ── Schemas (esquemas_calculo) ──────────────────────────────────
    QVariantList listSchemas() const;
    QVariantMap  getSchema(const QString &code) const;
    bool         saveSchema(const QString &originalCode, const QString &newCode,
                            const QString &name, const QString &tipoLiquidacion);
    bool         deleteSchema(const QString &code);

    // ── Categories (categorias_jornal) ──────────────────────────────
    QVariantList listCategories() const;
    QVariantMap  getCategory(int id) const;
    int          saveCategory(int id, const QString &name, double valorHora);
    bool         deleteCategory(int id);

    // ── Sections (secciones) ────────────────────────────────────────
    QVariantList listSections() const;

    // ── Employees (empleados) ───────────────────────────────────────
    QVariantList listEmployees() const;
    QVariantMap  getEmployee(int id) const;
    int          saveEmployee(int id, const QString &legajo, const QString &nombre,
                              const QString &tipoLiq, const QString &esquemaCodigo,
                              int categoriaJornalId, const QString &fechaIngreso,
                              const QString &cuil);
    bool         deleteEmployee(int id);
    int          duplicateEmployee(int sourceId);

    // ── Schema Fields (schema_fields) ───────────────────────────────
    // Defines the "model" of input variables for a schema
    QVariantList listSchemaFields(const QString &esquemaCodigo) const;
    QVariantList listAllSchemaFields() const;
    int          addSchemaField(const QString &esquemaCodigo, const QString &fieldCode,
                                const QString &fieldLabel, const QString &fieldType,
                                const QString &defaultValue, int displayOrder);
    bool         removeSchemaField(int fieldId);
    bool         renameSchemaField(int fieldId, const QString &newCode, const QString &newLabel);
    bool         updateSchemaField(int fieldId, const QString &fieldCode, const QString &fieldLabel,
                                   const QString &fieldType, const QString &defaultValue);

    // ── Employee Field Values (employee_field_values) ───────────────
    // Actual values per employee, conforming to the schema's field model
    QVariantList getEmployeeFieldValues(int employeeId, const QString &quincena = "Q1") const;
    QVariantList listAllEmployeeFieldValues() const;
    bool         setEmployeeFieldValue(int employeeId, int fieldId,
                                       const QString &quincena, const QString &value);
    bool         setEmployeeFieldValues(int employeeId, const QString &quincena,
                                         const QVariantMap &values);
    // Ensures all employees of a schema have values for all fields (fills defaults)
    void         syncEmployeeFieldsForSchema(const QString &esquemaCodigo);

    // ── Quincenas ───────────────────────────────────────────────────
    QStringList  listEmployeeQuincenas(int employeeId) const;
    QVariantList listAllEmployeeQuincenas() const;
    bool         addQuincena(int employeeId, const QString &quincenaCode);
    bool         removeQuincena(int employeeId, const QString &quincenaCode);

    // ── Calculation Cells (celdas_calculo) ──────────────────────────
    QVariantList listCellsBySchema(const QString &esquemaCodigo) const;
    QVariantList listAllCells() const;
    int          saveCell(int id, const QString &seccionCodigo, const QString &codigoVariable,
                          const QString &descripcion, const QString &condicion,
                          const QString &formulaUnidad, const QString &formulaBase,
                          const QString &formulaMonto, int orden, const QString &esquemaCodigo,
                          const QString &tipoCalculo, double simplePorcentaje,
                          const QString &simpleBaseVariable, double simpleMontoFijo,
                          bool visibleRecibo, const QString &colorHex = "",
                          bool enGrafico = false, bool esGraficoTotal = false);
    bool         updateCellColor(int id, const QString &colorHex);
    bool         deleteCell(int id);

    // ── Chart Cells (celdas_grafico) ────────────────────────────────
    QVariantList listChartCellsBySchema(const QString &esquemaCodigo) const;
    int          saveChartCell(int id, const QString &etiqueta, const QString &formula,
                               int orden, const QString &esquemaCodigo);
    bool         deleteChartCell(int id);

    // ── Global Variables (variables_globales) ───────────────────────
    QVariantList listGlobalVariables() const;
    int          saveGlobalVariable(int id, const QString &code, const QString &value,
                                     const QString &description);
    bool         deleteGlobalVariable(int id);

    // ── Custom Functions (custom_functions) ───────────────────────
    QVariantList listCustomFunctions(const QString &esquemaCodigo = "") const;
    int          saveCustomFunction(int id, const QString &name, const QString &params,
                                     const QString &body, const QString &description,
                                     const QString &esquemaCodigo = "");
    bool         deleteCustomFunction(int id);

    // ── Validation ────────────────────────────────────────────────
    static QString validateVariableCode(const QString &code);

    // ── Company (empresa) ───────────────────────────────────────────
    QVariantMap  getCompany() const;
    bool         saveCompany(const QString &razonSocial, const QString &direccion,
                             const QString &cuit, const QString &lugarDePago);

    // ── Receipts (recibos) ──────────────────────────────────────────
    QVariantList listReceiptsByEmployee(int employeeId) const;
    QVariantMap  getReceipt(int id) const;
    int          saveReceipt(int employeeId, const QString &esquemaCodigo,
                             int mes, int anio, const QString &periodo,
                             const QString &datosJson, int cierreId = 0);
    bool         deleteReceipt(int id);
    QVariantList searchReceipts(int employeeId, int mes, int anio) const;

    // ── Config ──────────────────────────────────────────────────────
    QString getConfig(const QString &key, const QString &defaultValue = "") const;
    void    setConfig(const QString &key, const QString &value);

    // ── Backup & New Month ──────────────────────────────────────────
    QString createBackup();
    QString resetNewMonth();

    // ── Granular Closings (cierres) ─────────────────────────────────
    QStringList  listActiveJornalQuincenas() const;
    bool         isCierreClosed(int anio, int mes, const QString &tipo, const QString &esquemaTipo) const;
    bool         canCloseQuincena(int anio, int mes, const QString &quincena) const;
    bool         canReopenQuincena(int anio, int mes, const QString &quincena) const;
    bool         isMonthFullyClosed(int anio, int mes) const;
    QVariantList listCierresForMonth(int anio, int mes) const;
    QVariantMap  getCierre(int anio, int mes, const QString &tipo, const QString &esquemaTipo) const;
    QVariantMap  getCierreSnapshot(int anio, int mes, const QString &tipo, const QString &esquemaTipo) const;
    int          insertCierre(int anio, int mes, const QString &tipo,
                              const QString &esquemaTipo, const QString &fechaCierre,
                              const QString &fechaPago, const QString &snapshotJson,
                              const QString &backupPath);
    bool         reopenCierre(int anio, int mes, const QString &tipo, const QString &esquemaTipo);
    QVariantList getEmployeeFieldValuesForPeriod(int employeeId, const QString &quincena, int anio, int mes) const;
    QVariantList listActiveEmployeesByTipo(const QString &tipoLiquidacion) const;

    // ── Transaction Helpers ─────────────────────────────────────────
    bool transaction() { return m_db.transaction(); }
    bool commit() { return m_db.commit(); }
    bool rollback() { return m_db.rollback(); }

private:
    void createTables();
    void runMigrations();

    QSqlDatabase m_db;
    QString m_dbPath;

    QLockFile *m_lockFile = nullptr;
    bool m_isLockedByOtherInstance = false;
    QString m_lockError;
    qint64 m_lockingPid = 0;
};

#endif // DATABASEMANAGER_H
