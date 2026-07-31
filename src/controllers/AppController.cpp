#include "AppController.h"
#include "database/DatabaseManager.h"
#include "engine/LiquidationEngine.h"
#include "models/CategoryModel.h"
#include "models/CellModel.h"
#include "models/ChartCellModel.h"
#include "models/EmployeeModel.h"
#include "models/EmployeeVarsModel.h"
#include "models/GlobalVarsModel.h"
#include "models/ReceiptHistoryModel.h"
#include "models/SchemaModel.h"
#include "services/ExportService.h"
#include <QDebug>

AppController::AppController(DatabaseManager *db, QObject *parent)
    : QObject(parent), m_db(db) {
  qDebug()
      << "[AppController] Inicializando controlador principal y subsistemas...";
  m_engine = new LiquidationEngine(m_db, this);
  m_exportService = new ExportService(m_db, this);

  m_employeeModel = new EmployeeModel(m_db, this);
  m_employeeVarsModel = new EmployeeVarsModel(m_db, this);
  m_globalVarsModel = new GlobalVarsModel(m_db, this);
  m_schemaModel = new SchemaModel(m_db, this);
  m_categoryModel = new CategoryModel(m_db, this);
  m_cellModel = new CellModel(m_db, this);
  m_chartCellModel = new ChartCellModel(m_db, this);
  m_receiptHistoryModel = new ReceiptHistoryModel(m_db, this);
  qInfo()
      << "[AppController] Controlador y modelos inicializados correctamente.";
}

AppController::~AppController() {}

QString AppController::currentRole() const { return m_currentRole; }

void AppController::setCurrentRole(const QString &role) {
  if (m_currentRole == role)
    return;
  qInfo() << "[AppController] Cambio de rol:" << m_currentRole << "->" << role;
  m_currentRole = role;
  emit currentRoleChanged();
}

bool AppController::darkMode() const {
  return m_db->getConfig("dark_mode", "true") == "true";
}

void AppController::setDarkMode(bool dark) {
  qInfo() << "[AppController] Cambio de tema visual. Modo oscuro:" << dark;
  m_db->setConfig("dark_mode", dark ? "true" : "false");
  emit darkModeChanged();
}

EmployeeModel *AppController::employeeModel() const { return m_employeeModel; }
EmployeeVarsModel *AppController::employeeVarsModel() const {
  return m_employeeVarsModel;
}
GlobalVarsModel *AppController::globalVarsModel() const {
  return m_globalVarsModel;
}
SchemaModel *AppController::schemaModel() const {
  return m_schemaModel;
}
CategoryModel *AppController::categoryModel() const { return m_categoryModel; }
CellModel *AppController::cellModel() const { return m_cellModel; }
ChartCellModel *AppController::chartCellModel() const {
  return m_chartCellModel;
}
ReceiptHistoryModel *AppController::receiptHistoryModel() const {
  return m_receiptHistoryModel;
}

QVariantMap AppController::processLiquidation(int employeeId,
                                              const QString &quincenaSel,
                                              const QString &fechaCalculo) {
  qInfo() << "[AppController] Ejecutando procesamiento de liquidación para Empleado ID:"
          << employeeId << "Quincena:" << quincenaSel;
  QVariantMap result = m_engine->processLiquidation(employeeId, quincenaSel, fechaCalculo);
  QVariantList errores = result.value("errores").toList();
  if (!errores.isEmpty()) {
      qWarning() << "[AppController] Se detectaron errores en la liquidación para empleado ID:" << employeeId << ":" << errores;
      emit calculationErrorOccurred(errores);
  }
  return result;
}

int AppController::persistLiquidation(const QVariantMap &result, int mes,
                                      int anio, const QString &periodo) {
  qInfo() << "[AppController] Persistiendo recibo histórico. Mes:" << mes
          << "Año:" << anio << "Período:" << periodo;
  return m_engine->persistLiquidation(result, mes, anio, periodo);
}

QString AppController::resetNewMonth() {
  qInfo()
      << "[AppController] Iniciando proceso de Nuevo Mes (Reset + Backup)...";
  QString backup = m_db->resetNewMonth();
  m_employeeVarsModel->refresh();
  qInfo() << "[AppController] Nuevo Mes completado. Backup generado en:"
          << backup;
  return backup;
}

QString AppController::createBackup() {
  qInfo()
      << "[AppController] Generando copia de seguridad de la base de datos...";
  QString backup = m_db->createBackup();
  qInfo() << "[AppController] Copia de seguridad guardada en:" << backup;
  return backup;
}

QVariantMap AppController::getCompany() const { return m_db->getCompany(); }

bool AppController::saveCompany(const QString &razonSocial,
                                const QString &direccion, const QString &cuit,
                                const QString &lugarDePago) {
  qInfo() << "[AppController] Guardando datos de la empresa:" << razonSocial;
  return m_db->saveCompany(razonSocial, direccion, cuit, lugarDePago);
}

QVariantList AppController::listSections() { return m_db->listSections(); }

QVariantList AppController::listSchemaFields(const QString &esquemaCodigo) {
  return m_db->listSchemaFields(esquemaCodigo);
}

int AppController::addSchemaField(const QString &esquemaCodigo,
                                  const QString &fieldCode,
                                  const QString &fieldLabel,
                                  const QString &fieldType,
                                  const QString &defaultValue,
                                  int displayOrder) {
  qInfo() << "[AppController] Agregando campo al esquema" << esquemaCodigo
          << ":" << fieldCode;
  int id = m_db->addSchemaField(esquemaCodigo, fieldCode, fieldLabel, fieldType,
                                defaultValue, displayOrder);
  m_employeeVarsModel->refresh();
  return id;
}

bool AppController::renameSchemaField(int fieldId, const QString &newCode, const QString &newLabel) {
  qInfo() << "[AppController] Renombrando campo de esquema ID:" << fieldId << "->" << newCode;
  bool ok = m_db->renameSchemaField(fieldId, newCode, newLabel);
  m_employeeVarsModel->refresh();
  return ok;
}

bool AppController::updateSchemaField(int fieldId, const QString &fieldCode, const QString &fieldLabel, const QString &fieldType, const QString &defaultValue)
{
    bool ok = m_db->updateSchemaField(fieldId, fieldCode, fieldLabel, fieldType, defaultValue);
    m_employeeVarsModel->refresh();
    return ok;
}

bool AppController::removeSchemaField(int fieldId) {
  qInfo() << "[AppController] Eliminando campo de esquema ID:" << fieldId;
  bool ok = m_db->removeSchemaField(fieldId);
  m_employeeVarsModel->refresh();
  return ok;
}

QStringList AppController::listEmployeeQuincenas(int employeeId) {
  return m_db->listEmployeeQuincenas(employeeId);
}

bool AppController::addQuincena(int employeeId, const QString &quincenaCode) {
  qInfo() << "[AppController] Agregando quincena" << quincenaCode
          << "a empleado ID:" << employeeId;
  bool ok = m_db->addQuincena(employeeId, quincenaCode);
  m_employeeVarsModel->refresh();
  return ok;
}

bool AppController::removeQuincena(int employeeId,
                                   const QString &quincenaCode) {
  qInfo() << "[AppController] Eliminando quincena" << quincenaCode
          << "de empleado ID:" << employeeId;
  bool ok = m_db->removeQuincena(employeeId, quincenaCode);
  m_employeeVarsModel->refresh();
  return ok;
}

QVariantList AppController::listSchemas() { return m_db->listSchemas(); }

QVariantList AppController::listCategories() { return m_db->listCategories(); }

QVariantList
AppController::getAvailableFormulaVariables(const QString &esquemaCodigo) {
  QVariantList list;

  auto addVar = [&](const QString &code, const QString &desc,
                    const QString &category) {
    QVariantMap map;
    map["code"] = code;
    map["description"] = desc;
    map["category"] = category;
    list.append(map);
  };

  // Built-in functions
  addVar("round(val, n)", "Redondea un valor a N decimales", "Función Motor");
  addVar("min(a, b)", "Retorna el mínimo entre expresiones", "Función Motor");
  addVar("max(a, b)", "Retorna el máximo entre expresiones", "Función Motor");
  addVar("abs(val)", "Retorna el valor absoluto", "Función Motor");

  // Quincena functions
  addVar("Q1(\"var\")", "Valor de una variable en la Quincena 1", "Agregación Quincenal");
  addVar("Q2(\"var\")", "Valor de una variable en la Quincena 2", "Agregación Quincenal");
  addVar("Q_sum(\"var\")", "Suma de una variable en las quincenas del mes", "Agregación Quincenal");
  addVar("Q_avg(\"var\")", "Promedio de una variable en las quincenas del mes", "Agregación Quincenal");
  addVar("Q_max(\"var\")", "Valor máximo de una variable en las quincenas del mes", "Agregación Quincenal");

  // Historical functions
  addVar("H_sum(\"var\", meses)", "Sumatoria de los últimos N meses recibidos", "Histórico Mensual");
  addVar("H_max(\"var\", meses)", "Valor máximo de los últimos N meses (para SAC)", "Histórico Mensual");
  addVar("H_avg(\"var\", meses)", "Promedio de los últimos N meses", "Histórico Mensual");
  addVar("H_val(\"var\", offset)", "Valor de una variable N meses atrás (offset)", "Histórico Mensual");

  // Local concept execution variables
  addVar("unidad", "Valor de la columna Unidad/Cantidad del concepto actual",
         "Variable Local");
  addVar("base", "Valor de la columna Base Imponible del concepto actual",
         "Variable Local");
  addVar("monto", "Monto calculado del concepto actual", "Variable Local");
  addVar("porcentaje", "Porcentaje simple configurado en el concepto",
         "Variable Local");
  addVar("jornal", "Valor hora o jornada según la categoría", "Variable Local");
  addVar("antiguedad_anios", "Años de antigüedad del empleado",
         "Variable Local");

  // Totales y acumuladores
  addVar("total_remunerativo",
         "Suma acumulada de conceptos remunerativos previos", "Acumulador");
  addVar("total_descuentos", "Suma acumulada de descuentos previos",
         "Acumulador");
  addVar("total_no_remunerativo",
         "Suma acumulada de conceptos no remunerativos previos", "Acumulador");
  addVar("neto_a_cobrar", "Monto neto a cobrar acumulado", "Acumulador");

  // Global variables
  QVariantList globals = m_db->listGlobalVariables();
  for (const QVariant &v : globals) {
    QVariantMap m = v.toMap();
    addVar(m["codigo"].toString(), m["descripcion"].toString() + " (Global)",
           "Variable Global");
  }

  // Schema fields
  QVariantList fields = m_db->listSchemaFields(esquemaCodigo);
  for (const QVariant &v : fields) {
    QVariantMap m = v.toMap();
    addVar(m["field_code"].toString(),
           m["field_label"].toString() + " (Empleado)", "Campo Empleado");
  }

  // Previous concepts in cell list
  QVariantList cells = m_db->listCellsBySchema(esquemaCodigo);
  for (const QVariant &v : cells) {
    QVariantMap m = v.toMap();
    addVar(m["codigo_variable"].toString(), m["descripcion"].toString(),
           "Concepto Recibo");
  }

  return list;
}

QString AppController::exportDataXlsx(const QString &path) {
  return m_exportService->exportDataXlsx(path);
}

bool AppController::importDataXlsx(const QString &path) {
  bool ok = m_exportService->importDataXlsx(path);
  if (ok) {
    m_employeeModel->refresh();
    m_globalVarsModel->refresh();
    m_schemaModel->refresh();
    m_categoryModel->refresh();
    m_cellModel->refresh();
  }
  return ok;
}

QString AppController::exportDataCsv(const QString &directoryPath) {
  return m_exportService->exportDataCsv(directoryPath);
}

QString AppController::exportReceiptPdf(int employeeId,
                                        const QVariantMap &liquidationResult,
                                        const QString &path) {
  QVariantMap empData = m_db->getEmployee(employeeId);
  QVariantMap compData = m_db->getCompany();
  return m_exportService->exportReceiptPdf(liquidationResult, compData, empData,
                                           path);
}
