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
#include "services/UpdateService.h"
#include <QDebug>
#include <QFileDialog>
#include <QJsonDocument>
#include <QTimer>

AppController::AppController(DatabaseManager *db, QObject *parent)
    : QObject(parent), m_db(db) {
  qDebug()
      << "[AppController] Inicializando controlador principal y subsistemas...";
  m_engine = new LiquidationEngine(m_db, this);
  m_exportService = new ExportService(m_db, this);
  m_updateService = new UpdateService(this);

  m_employeeModel = new EmployeeModel(m_db, this);
  m_employeeVarsModel = new EmployeeVarsModel(m_db, this);
  m_globalVarsModel = new GlobalVarsModel(m_db, this);
  m_schemaModel = new SchemaModel(m_db, this);
  m_categoryModel = new CategoryModel(m_db, this);
  m_cellModel = new CellModel(m_db, this);
  m_chartCellModel = new ChartCellModel(m_db, this);
  m_receiptHistoryModel = new ReceiptHistoryModel(m_db, this);
  m_customFunctionModel = new CustomFunctionModel(m_db, this);

  QDate today = QDate::currentDate();
  m_selectedYear = today.year();
  m_selectedMonth = today.month();
  refreshPeriodState();

  // Automatic background update check on startup
  if (m_updateService->autoCheckOnStartup()) {
    QTimer::singleShot(2500, this, [this]() {
      m_updateService->checkForUpdates(true);
    });
  }

  qInfo()
      << "[AppController] Controlador y modelos inicializados correctamente.";
}

AppController::~AppController() {}

void AppController::startWindowMove(QQuickWindow *window) {
  if (window) {
    window->startSystemMove();
  }
}

void AppController::minimizeWindow(QQuickWindow *window) {
  if (window) {
    window->showMinimized();
  }
}

void AppController::toggleMaximizeWindow(QQuickWindow *window) {
  if (window) {
    if (window->visibility() == QWindow::Maximized) {
      window->showNormal();
    } else {
      window->showMaximized();
    }
  }
}

void AppController::closeWindow(QQuickWindow *window) {
  if (window) {
    window->close();
  }
}

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
SchemaModel *AppController::schemaModel() const { return m_schemaModel; }
CategoryModel *AppController::categoryModel() const { return m_categoryModel; }
CellModel *AppController::cellModel() const { return m_cellModel; }
ChartCellModel *AppController::chartCellModel() const {
  return m_chartCellModel;
}
ReceiptHistoryModel *AppController::receiptHistoryModel() const {
  return m_receiptHistoryModel;
}
CustomFunctionModel *AppController::customFunctionModel() const {
  return m_customFunctionModel;
}
UpdateService *AppController::updateService() const {
  return m_updateService;
}

QVariantMap AppController::processLiquidation(int employeeId,
                                              const QString &quincenaSel,
                                              const QString &fechaCalculo,
                                              const QString &fechaCierre,
                                              const QString &fechaPago) {
  QString fc = fechaCierre;
  if (fc.isEmpty()) {
    if (quincenaSel == "Q1") fc = m_fechaCierreQ1;
    else if (quincenaSel == "Q2") fc = m_fechaCierreQ2;
    else fc = m_fechaCierreMes;
  }
  QString fp = fechaPago.isEmpty() ? m_fechaPago : fechaPago;

  qInfo() << "[AppController] Ejecutando procesamiento de liquidación para Empleado ID:"
          << employeeId << "Quincena:" << quincenaSel << "Fecha Cierre:" << fc << "Fecha Pago:" << fp;
  QVariantMap result =
      m_engine->processLiquidation(employeeId, quincenaSel, fechaCalculo, fc, fp);
  QVariantList errores = result.value("errores").toList();
  if (!errores.isEmpty()) {
    qWarning() << "[AppController] Se detectaron errores en la liquidación "
                  "para empleado ID:"
               << employeeId << ":" << errores;
    emit calculationErrorOccurred(errores);
  }
  return result;
}

int AppController::persistLiquidation(const QVariantMap &result, int mes,
                                      int anio, const QString &periodo,
                                      const QString &fechaCierre,
                                      const QString &fechaPago,
                                      int cierreId) {
  int m = mes > 0 ? mes : m_selectedMonth;
  int a = anio > 0 ? anio : m_selectedYear;
  QString fc = fechaCierre;
  if (fc.isEmpty()) {
    if (periodo.contains("Q1", Qt::CaseInsensitive)) fc = m_fechaCierreQ1;
    else if (periodo.contains("Q2", Qt::CaseInsensitive)) fc = m_fechaCierreQ2;
    else fc = m_fechaCierreMes;
  }
  QString fp = fechaPago.isEmpty() ? m_fechaPago : fechaPago;

  qInfo() << "[AppController] Persistiendo recibo histórico. Mes:" << m
          << "Año:" << a << "Período:" << periodo << "Fecha Cierre:" << fc << "Fecha Pago:" << fp << "CierreId:" << cierreId;
  return m_engine->persistLiquidation(result, m, a, periodo, fc, fp, cierreId);
}

int AppController::selectedYear() const { return m_selectedYear; }
void AppController::setSelectedYear(int year) {
  if (m_selectedYear == year) return;
  m_selectedYear = year;
  emit selectedYearChanged();
  refreshPeriodState();
}

int AppController::selectedMonth() const { return m_selectedMonth; }
void AppController::setSelectedMonth(int month) {
  if (m_selectedMonth == month) return;
  m_selectedMonth = month;
  emit selectedMonthChanged();
  refreshPeriodState();
}

bool AppController::isCurrentPeriodClosed() const { return m_isCurrentPeriodClosed; }
QStringList AppController::activeQuincenas() const { return m_db->listActiveJornalQuincenas(); }
QVariantList AppController::periodCierres() const { return m_db->listCierresForMonth(m_selectedYear, m_selectedMonth); }
QString AppController::fechaCierreMes() const { return m_fechaCierreMes; }
QString AppController::fechaCierreQ1() const { return m_fechaCierreQ1; }
QString AppController::fechaCierreQ2() const { return m_fechaCierreQ2; }
QString AppController::fechaPago() const { return m_fechaPago; }
bool AppController::isQ1Closed() const { return isCierreClosed("Q1", "jornal"); }
bool AppController::isQ2Closed() const { return isCierreClosed("Q2", "jornal"); }
bool AppController::isMClosed() const { return isCierreClosed("M", "mensual"); }

bool AppController::isCierreClosed(const QString &tipo, const QString &esquemaTipo) const {
  return m_db->isCierreClosed(m_selectedYear, m_selectedMonth, tipo, esquemaTipo);
}

bool AppController::canCloseTarget(const QString &tipo, const QString &esquemaTipo) const {
  if (esquemaTipo == "jornal") {
    return m_db->canCloseQuincena(m_selectedYear, m_selectedMonth, tipo);
  } else {
    return !m_db->isCierreClosed(m_selectedYear, m_selectedMonth, "M", "mensual");
  }
}

bool AppController::canReopenTarget(const QString &tipo, const QString &esquemaTipo) const {
  if (esquemaTipo == "jornal") {
    return m_db->canReopenQuincena(m_selectedYear, m_selectedMonth, tipo);
  } else {
    return m_db->isCierreClosed(m_selectedYear, m_selectedMonth, "M", "mensual");
  }
}

bool AppController::canEditQuincena(int employeeId, const QString &quincena) const {
  QVariantMap emp = m_db->getEmployee(employeeId);
  QString tipoLiq = emp.value("tipo_liquidacion").toString();
  QString tipoCierre = (tipoLiq == "jornal") ? quincena : "M";
  return !m_db->isCierreClosed(m_selectedYear, m_selectedMonth, tipoCierre, tipoLiq);
}

bool AppController::canPersistReceipt(int employeeId, const QString &quincena) const {
  return canEditQuincena(employeeId, quincena);
}

QVariantMap AppController::validateBatch(const QString &esquemaTipo,
                                        const QString &quincena,
                                        const QString &fechaCierre,
                                        const QString &fechaPago) {
  QString fc = fechaCierre.isEmpty() ? m_fechaCierreMes : fechaCierre;
  QString fp = fechaPago.isEmpty() ? m_fechaPago : fechaPago;
  return m_engine->validateBatch(m_selectedMonth, m_selectedYear, esquemaTipo, quincena, fc, fp);
}

QVariantMap AppController::executeBatchClose(const QString &esquemaTipo,
                                            const QString &quincena,
                                            const QString &fechaCierre,
                                            const QString &fechaPago,
                                            const QString &exportPath) {
  QString fc = fechaCierre.isEmpty() ? m_fechaCierreMes : fechaCierre;
  QString fp = fechaPago.isEmpty() ? m_fechaPago : fechaPago;
  QVariantMap res = m_engine->executeBatchClose(m_selectedMonth, m_selectedYear, esquemaTipo, quincena, fc, fp, exportPath);
  if (res.value("ok").toBool()) {
    refreshPeriodState();
    m_receiptHistoryModel->refresh();
    m_employeeVarsModel->refresh();
    emit batchCloseCompleted(true, res.value("mensaje").toString());
  } else {
    emit batchCloseCompleted(false, res.value("mensaje").toString());
  }
  return res;
}

bool AppController::reopenCierre(const QString &tipo, const QString &esquemaTipo) {
  bool ok = m_db->reopenCierre(m_selectedYear, m_selectedMonth, tipo, esquemaTipo);
  if (ok) {
    refreshPeriodState();
    m_receiptHistoryModel->refresh();
    m_employeeVarsModel->refresh();
  }
  return ok;
}

QVariantMap AppController::getCierre(const QString &tipo, const QString &esquemaTipo) const {
  return m_db->getCierre(m_selectedYear, m_selectedMonth, tipo, esquemaTipo);
}

QVariantMap AppController::getCierreSnapshot(const QString &tipo, const QString &esquemaTipo) const {
  return m_db->getCierreSnapshot(m_selectedYear, m_selectedMonth, tipo, esquemaTipo);
}

QVariantList AppController::listCierresForMonth(int anio, int mes) const {
  return m_db->listCierresForMonth(anio > 0 ? anio : m_selectedYear, mes > 0 ? mes : m_selectedMonth);
}

void AppController::refreshPeriodState() {
  bool fullyClosed = m_db->isMonthFullyClosed(m_selectedYear, m_selectedMonth);
  m_isCurrentPeriodClosed = fullyClosed;

  // Defaults
  QDate q1Date(m_selectedYear, m_selectedMonth, 15);
  QDate lastDayDate(m_selectedYear, m_selectedMonth, QDate(m_selectedYear, m_selectedMonth, 1).daysInMonth());
  QDate nextMonthDate = lastDayDate.addDays(5);

  m_fechaCierreQ1 = q1Date.toString("yyyy-MM-dd");
  m_fechaCierreQ2 = lastDayDate.toString("yyyy-MM-dd");
  m_fechaCierreMes = lastDayDate.toString("yyyy-MM-dd");
  m_fechaPago = nextMonthDate.toString("yyyy-MM-dd");

  QVariantList cierres = m_db->listCierresForMonth(m_selectedYear, m_selectedMonth);
  for (const QVariant &cv : cierres) {
    QVariantMap cm = cv.toMap();
    QString tipo = cm.value("tipo").toString();
    if (tipo == "Q1") {
      m_fechaCierreQ1 = cm.value("fecha_cierre").toString();
    } else if (tipo == "Q2") {
      m_fechaCierreQ2 = cm.value("fecha_cierre").toString();
    } else if (tipo == "M") {
      m_fechaCierreMes = cm.value("fecha_cierre").toString();
      m_fechaPago = cm.value("fecha_pago").toString();
    }
  }

  m_employeeVarsModel->setPeriod(m_selectedYear, m_selectedMonth);
  emit periodClosedChanged();
  emit activeQuincenasChanged();
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

bool AppController::renameSchemaField(int fieldId, const QString &newCode,
                                      const QString &newLabel) {
  qInfo() << "[AppController] Renombrando campo de esquema ID:" << fieldId
          << "->" << newCode;
  bool ok = m_db->renameSchemaField(fieldId, newCode, newLabel);
  m_employeeVarsModel->refresh();
  return ok;
}

bool AppController::updateSchemaField(int fieldId, const QString &fieldCode,
                                      const QString &fieldLabel,
                                      const QString &fieldType,
                                      const QString &defaultValue) {
  bool ok = m_db->updateSchemaField(fieldId, fieldCode, fieldLabel, fieldType,
                                    defaultValue);
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

QVariantList AppController::listCustomFunctions() {
  return m_db->listCustomFunctions();
}

QString AppController::validateVariableCode(const QString &code) {
  return DatabaseManager::validateVariableCode(code);
}

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

  // Custom User Functions from DB
  QVariantList customFuncs = m_db->listCustomFunctions();
  for (const QVariant &f : customFuncs) {
    QVariantMap fm = f.toMap();
    QString fnName = fm["name"].toString();
    QString params = fm["params"].toString();
    QString desc = fm["description"].toString();
    addVar(fnName + "(" + params + ")", desc, "Función Personalizada");
  }

  // Environment Object
  addVar("env.quincenas", "Arreglo de quincenas del mes [ { code: 'Q1', ... } ]", "Entorno JS");
  addVar("env.historial", "Arreglo de recibos históricos procesados", "Entorno JS");
  addVar("env.empleado", "Objeto empleado (legajo, nombre, antigüedad, etc.)", "Entorno JS");
  addVar("env.globals", "Diccionario de constantes globales de la empresa", "Entorno JS");

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

  // Calculation date variables
  addVar("FECHA_CALCULO", "Fecha de cálculo de la liquidación (YYYY-MM-DD)", "Fecha Cálculo");
  addVar("MES_CALCULO", "Número de mes de la fecha de cálculo (1-12)", "Fecha Cálculo");
  addVar("ANIO_CALCULO", "Año de la fecha de cálculo (ej. 2026)", "Fecha Cálculo");
  addVar("DIA_CALCULO", "Día del mes de la fecha de cálculo (1-31)", "Fecha Cálculo");

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
  QVariantMap empData = employeeId > 0 ? m_db->getEmployee(employeeId) : QVariantMap();
  if (empData.isEmpty() && liquidationResult.contains("empleado")) {
    empData = liquidationResult.value("empleado").toMap();
  }
  QVariantMap compData = m_db->getCompany();
  if (compData.isEmpty() && liquidationResult.contains("empresa")) {
    compData = liquidationResult.value("empresa").toMap();
  }
  return m_exportService->exportReceiptPdf(liquidationResult, compData, empData,
                                           path);
}

QString AppController::selectSaveFile(const QString &title, const QString &defaultName, const QString &filter) {
    return QFileDialog::getSaveFileName(nullptr, title, defaultName, filter);
}

QString AppController::selectOpenFile(const QString &title, const QString &defaultDir, const QString &filter) {
    return QFileDialog::getOpenFileName(nullptr, title, defaultDir, filter);
}

QString AppController::selectFolder(const QString &title, const QString &defaultDir) {
    return QFileDialog::getExistingDirectory(nullptr, title, defaultDir);
}

QString AppController::formatJson(const QString &rawJson) const {
    if (rawJson.trimmed().isEmpty())
        return QString();
    QJsonDocument doc = QJsonDocument::fromJson(rawJson.toUtf8());
    if (doc.isNull())
        return rawJson;
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}
