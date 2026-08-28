/*
 * Sistema de Liquidación de Sueldos
 * Copyright (C) 2026
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef APPCONTROLLER_H
#define APPCONTROLLER_H

#include <QObject>
#include <QQuickWindow>
#include <QString>
#include <QStringList>
#include <QVariantMap>

#include "models/CategoryModel.h"
#include "models/CellModel.h"
#include "models/ChartCellModel.h"
#include "models/CustomFunctionModel.h"
#include "models/EmployeeModel.h"
#include "models/EmployeeVarsModel.h"
#include "models/GlobalVarsModel.h"
#include "models/ReceiptHistoryModel.h"
#include "models/SchemaModel.h"

class DatabaseManager;
class LiquidationEngine;
class ExportService;

class AppController : public QObject {
  Q_OBJECT

  Q_PROPERTY(QString currentRole READ currentRole WRITE setCurrentRole NOTIFY
                 currentRoleChanged)
  Q_PROPERTY(
      bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
  Q_PROPERTY(EmployeeModel *employeeModel READ employeeModel CONSTANT)
  Q_PROPERTY(
      EmployeeVarsModel *employeeVarsModel READ employeeVarsModel CONSTANT)
  Q_PROPERTY(GlobalVarsModel *globalVarsModel READ globalVarsModel CONSTANT)
  Q_PROPERTY(SchemaModel *schemaModel READ schemaModel CONSTANT)
  Q_PROPERTY(CategoryModel *categoryModel READ categoryModel CONSTANT)
  Q_PROPERTY(CellModel *cellModel READ cellModel CONSTANT)
  Q_PROPERTY(ChartCellModel *chartCellModel READ chartCellModel CONSTANT)
  Q_PROPERTY(ReceiptHistoryModel *receiptHistoryModel READ receiptHistoryModel
                 CONSTANT)
  Q_PROPERTY(CustomFunctionModel *customFunctionModel READ customFunctionModel
                 CONSTANT)

  // ── Global Period Selection ─────────────────────────────────
  Q_PROPERTY(int selectedYear READ selectedYear WRITE setSelectedYear NOTIFY
                 selectedYearChanged)
  Q_PROPERTY(int selectedMonth READ selectedMonth WRITE setSelectedMonth NOTIFY
                 selectedMonthChanged)
  Q_PROPERTY(bool isCurrentPeriodClosed READ isCurrentPeriodClosed NOTIFY
                 periodClosedChanged)
  Q_PROPERTY(QStringList activeQuincenas READ activeQuincenas NOTIFY
                 activeQuincenasChanged)
  Q_PROPERTY(QVariantList periodCierres READ periodCierres NOTIFY
                 periodClosedChanged)
  Q_PROPERTY(QString fechaCierreMes READ fechaCierreMes NOTIFY
                 periodClosedChanged)
  Q_PROPERTY(QString fechaCierreQ1 READ fechaCierreQ1 NOTIFY
                 periodClosedChanged)
  Q_PROPERTY(QString fechaCierreQ2 READ fechaCierreQ2 NOTIFY
                 periodClosedChanged)
  Q_PROPERTY(QString fechaPago READ fechaPago NOTIFY
                 periodClosedChanged)
  Q_PROPERTY(bool isQ1Closed READ isQ1Closed NOTIFY periodClosedChanged)
  Q_PROPERTY(bool isQ2Closed READ isQ2Closed NOTIFY periodClosedChanged)
  Q_PROPERTY(bool isMClosed READ isMClosed NOTIFY periodClosedChanged)

public:
  explicit AppController(DatabaseManager *db, QObject *parent = nullptr);
  ~AppController();

  Q_INVOKABLE void startWindowMove(QQuickWindow *window);
  Q_INVOKABLE void minimizeWindow(QQuickWindow *window);
  Q_INVOKABLE void toggleMaximizeWindow(QQuickWindow *window);
  Q_INVOKABLE void closeWindow(QQuickWindow *window);

  QString currentRole() const;
  void setCurrentRole(const QString &role);

  bool darkMode() const;
  void setDarkMode(bool dark);

  EmployeeModel *employeeModel() const;
  EmployeeVarsModel *employeeVarsModel() const;
  GlobalVarsModel *globalVarsModel() const;
  SchemaModel *schemaModel() const;
  CategoryModel *categoryModel() const;
  CellModel *cellModel() const;
  ChartCellModel *chartCellModel() const;
  ReceiptHistoryModel *receiptHistoryModel() const;
  CustomFunctionModel *customFunctionModel() const;

  Q_INVOKABLE QVariantMap processLiquidation(int employeeId,
                                             const QString &quincenaSel = "",
                                             const QString &fechaCalculo = "",
                                             const QString &fechaCierre = "",
                                             const QString &fechaPago = "");
  Q_INVOKABLE int persistLiquidation(const QVariantMap &result, int mes,
                                     int anio, const QString &periodo,
                                     const QString &fechaCierre = "",
                                     const QString &fechaPago = "",
                                     int cierreId = 0);
  Q_INVOKABLE QString resetNewMonth();
  Q_INVOKABLE QString createBackup();

  // ── Global Period & Granular Closings ────────────────────────
  int selectedYear() const;
  void setSelectedYear(int year);
  int selectedMonth() const;
  void setSelectedMonth(int month);
  bool isCurrentPeriodClosed() const;
  QStringList activeQuincenas() const;
  QVariantList periodCierres() const;
  QString fechaCierreMes() const;
  QString fechaCierreQ1() const;
  QString fechaCierreQ2() const;
  QString fechaPago() const;
  bool isQ1Closed() const;
  bool isQ2Closed() const;
  bool isMClosed() const;

  Q_INVOKABLE bool isCierreClosed(const QString &tipo, const QString &esquemaTipo) const;
  Q_INVOKABLE bool canCloseTarget(const QString &tipo, const QString &esquemaTipo) const;
  Q_INVOKABLE bool canReopenTarget(const QString &tipo, const QString &esquemaTipo) const;
  Q_INVOKABLE bool canEditQuincena(int employeeId, const QString &quincena) const;
  Q_INVOKABLE bool canPersistReceipt(int employeeId, const QString &quincena) const;

  Q_INVOKABLE QVariantMap validateBatch(const QString &esquemaTipo,
                                        const QString &quincena,
                                        const QString &fechaCierre,
                                        const QString &fechaPago);

  Q_INVOKABLE QVariantMap executeBatchClose(const QString &esquemaTipo,
                                            const QString &quincena,
                                            const QString &fechaCierre,
                                            const QString &fechaPago,
                                            const QString &exportPath);

  Q_INVOKABLE bool reopenCierre(const QString &tipo, const QString &esquemaTipo);
  Q_INVOKABLE QVariantMap getCierre(const QString &tipo, const QString &esquemaTipo) const;
  Q_INVOKABLE QVariantMap getCierreSnapshot(const QString &tipo, const QString &esquemaTipo) const;
  Q_INVOKABLE QVariantList listCierresForMonth(int anio, int mes) const;
  Q_INVOKABLE void refreshPeriodState();

  // Company CRUD shortcuts
  Q_INVOKABLE QVariantMap getCompany() const;
  Q_INVOKABLE bool saveCompany(const QString &razonSocial,
                               const QString &direccion, const QString &cuit,
                               const QString &lugarDePago);

  // Sections, Schemas, Categories list
  Q_INVOKABLE QVariantList listSections();
  Q_INVOKABLE QVariantList listSchemas();
  Q_INVOKABLE QVariantList listCategories();

  // Schema fields CRUD
  Q_INVOKABLE QVariantList listSchemaFields(const QString &esquemaCodigo);
  Q_INVOKABLE int addSchemaField(const QString &esquemaCodigo,
                                 const QString &fieldCode,
                                 const QString &fieldLabel,
                                 const QString &fieldType,
                                 const QString &defaultValue, int displayOrder);
  Q_INVOKABLE bool renameSchemaField(int fieldId, const QString &newCode,
                                     const QString &newLabel);
  Q_INVOKABLE bool updateSchemaField(int fieldId, const QString &fieldCode,
                                     const QString &fieldLabel,
                                     const QString &fieldType,
                                     const QString &defaultValue);
  Q_INVOKABLE bool removeSchemaField(int fieldId);

  // Quincenas CRUD
  Q_INVOKABLE QStringList listEmployeeQuincenas(int employeeId);
  Q_INVOKABLE bool addQuincena(int employeeId, const QString &quincenaCode);
  Q_INVOKABLE bool removeQuincena(int employeeId, const QString &quincenaCode);

  // IDE Autocomplete / Formula variables helper
  Q_INVOKABLE QVariantList
  getAvailableFormulaVariables(const QString &esquemaCodigo);

  // Custom Functions
  Q_INVOKABLE QVariantList listCustomFunctions();

  // Validation
  Q_INVOKABLE QString validateVariableCode(const QString &code);

  // Native File Dialog Helpers
  Q_INVOKABLE QString selectSaveFile(const QString &title, const QString &defaultName, const QString &filter);
  Q_INVOKABLE QString selectOpenFile(const QString &title, const QString &defaultDir, const QString &filter);
  Q_INVOKABLE QString selectFolder(const QString &title, const QString &defaultDir);

  // JSON Utilities
  Q_INVOKABLE QString formatJson(const QString &rawJson) const;

  // ── Export / Import ─────────────────────────────────────────
  Q_INVOKABLE QString exportDataXlsx(const QString &path);
  Q_INVOKABLE bool importDataXlsx(const QString &path);
  Q_INVOKABLE QString exportDataCsv(const QString &directoryPath);
  Q_INVOKABLE QString exportReceiptPdf(int employeeId,
                                       const QVariantMap &liquidationResult,
                                       const QString &path);

signals:
  void currentRoleChanged();
  void darkModeChanged();
  void calculationErrorOccurred(const QVariantList &errors);
  void selectedYearChanged();
  void selectedMonthChanged();
  void periodClosedChanged();
  void activeQuincenasChanged();
  void batchCloseCompleted(bool ok, const QString &message);

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
  CustomFunctionModel *m_customFunctionModel;

  // Global period state
  int m_selectedYear;
  int m_selectedMonth;
  bool m_isCurrentPeriodClosed = false;
  QString m_fechaCierreMes;
  QString m_fechaCierreQ1;
  QString m_fechaCierreQ2;
  QString m_fechaPago;
};

#endif // APPCONTROLLER_H
