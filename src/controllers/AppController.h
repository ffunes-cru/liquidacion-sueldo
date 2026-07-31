#ifndef APPCONTROLLER_H
#define APPCONTROLLER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

#include "models/EmployeeModel.h"
#include "models/EmployeeVarsModel.h"
#include "models/GlobalVarsModel.h"
#include "models/SchemaModel.h"
#include "models/CategoryModel.h"
#include "models/CellModel.h"
#include "models/ChartCellModel.h"
#include "models/ReceiptHistoryModel.h"

class DatabaseManager;
class LiquidationEngine;
class ExportService;

class AppController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString currentRole READ currentRole WRITE setCurrentRole NOTIFY currentRoleChanged)
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(EmployeeModel* employeeModel READ employeeModel CONSTANT)
    Q_PROPERTY(EmployeeVarsModel* employeeVarsModel READ employeeVarsModel CONSTANT)
    Q_PROPERTY(GlobalVarsModel* globalVarsModel READ globalVarsModel CONSTANT)
    Q_PROPERTY(SchemaModel* schemaModel READ schemaModel CONSTANT)
    Q_PROPERTY(CategoryModel* categoryModel READ categoryModel CONSTANT)
    Q_PROPERTY(CellModel* cellModel READ cellModel CONSTANT)
    Q_PROPERTY(ChartCellModel* chartCellModel READ chartCellModel CONSTANT)
    Q_PROPERTY(ReceiptHistoryModel* receiptHistoryModel READ receiptHistoryModel CONSTANT)

public:
    explicit AppController(DatabaseManager *db, QObject *parent = nullptr);
    ~AppController();

    QString currentRole() const;
    void setCurrentRole(const QString &role);

    bool darkMode() const;
    void setDarkMode(bool dark);

    EmployeeModel* employeeModel() const;
    EmployeeVarsModel* employeeVarsModel() const;
    GlobalVarsModel* globalVarsModel() const;
    SchemaModel* schemaModel() const;
    CategoryModel* categoryModel() const;
    CellModel* cellModel() const;
    ChartCellModel* chartCellModel() const;
    ReceiptHistoryModel* receiptHistoryModel() const;

    Q_INVOKABLE QVariantMap processLiquidation(int employeeId, const QString &quincenaSel = "", const QString &fechaCalculo = "");
    Q_INVOKABLE int persistLiquidation(const QVariantMap &result, int mes, int anio, const QString &periodo);
    Q_INVOKABLE QString resetNewMonth();
    Q_INVOKABLE QString createBackup();

    // Company CRUD shortcuts
    Q_INVOKABLE QVariantMap getCompany() const;
    Q_INVOKABLE bool saveCompany(const QString &razonSocial, const QString &direccion, const QString &cuit, const QString &lugarDePago);

    // Sections list
    Q_INVOKABLE QVariantList listSections();

    // Schema fields CRUD
    Q_INVOKABLE QVariantList listSchemaFields(const QString &esquemaCodigo);
    Q_INVOKABLE int addSchemaField(const QString &esquemaCodigo, const QString &fieldCode, const QString &fieldLabel, const QString &fieldType, const QString &defaultValue, int displayOrder);
    Q_INVOKABLE bool removeSchemaField(int fieldId);

    // Quincenas CRUD
    Q_INVOKABLE QStringList listEmployeeQuincenas(int employeeId);
    Q_INVOKABLE bool addQuincena(int employeeId, const QString &quincenaCode);
    Q_INVOKABLE bool removeQuincena(int employeeId, const QString &quincenaCode);

    // IDE Autocomplete / Formula variables helper
    Q_INVOKABLE QVariantList getAvailableFormulaVariables(const QString &esquemaCodigo);

    // ── Export / Import ─────────────────────────────────────────
    Q_INVOKABLE QString exportDataXlsx(const QString &path);
    Q_INVOKABLE bool importDataXlsx(const QString &path);
    Q_INVOKABLE QString exportDataCsv(const QString &directoryPath);
    Q_INVOKABLE QString exportReceiptPdf(int employeeId, const QVariantMap &liquidationResult, const QString &path);

signals:
    void currentRoleChanged();
    void darkModeChanged();

private:
    DatabaseManager *m_db;
    LiquidationEngine *m_engine;
    ExportService *m_exportService;

    QString m_currentRole = "admin";

    EmployeeModel *m_employeeModel;
    EmployeeVarsModel *m_employeeVarsModel;
    GlobalVarsModel *m_globalVarsModel;
    SchemaModel *m_schemaModel;
    CategoryModel *m_categoryModel;
    CellModel *m_cellModel;
    ChartCellModel *m_chartCellModel;
    ReceiptHistoryModel *m_receiptHistoryModel;
};

#endif // APPCONTROLLER_H
