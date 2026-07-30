#include "AppController.h"
#include "database/DatabaseManager.h"
#include "engine/LiquidationEngine.h"
#include "models/EmployeeModel.h"
#include "models/EmployeeVarsModel.h"
#include "models/GlobalVarsModel.h"
#include "models/SchemaModel.h"
#include "models/CategoryModel.h"
#include "models/CellModel.h"
#include "models/ChartCellModel.h"
#include "models/ReceiptHistoryModel.h"
#include <QDebug>

AppController::AppController(DatabaseManager *db, QObject *parent)
    : QObject(parent), m_db(db)
{
    qDebug() << "[AppController] Inicializando controlador principal y subsistemas...";
    m_engine = new LiquidationEngine(m_db, this);

    m_employeeModel = new EmployeeModel(m_db, this);
    m_employeeVarsModel = new EmployeeVarsModel(m_db, this);
    m_globalVarsModel = new GlobalVarsModel(m_db, this);
    m_schemaModel = new SchemaModel(m_db, this);
    m_categoryModel = new CategoryModel(m_db, this);
    m_cellModel = new CellModel(m_db, this);
    m_chartCellModel = new ChartCellModel(m_db, this);
    m_receiptHistoryModel = new ReceiptHistoryModel(m_db, this);
    qInfo() << "[AppController] Controlador y modelos inicializados correctamente.";
}

AppController::~AppController()
{
}

QString AppController::currentRole() const { return m_currentRole; }

void AppController::setCurrentRole(const QString &role)
{
    if (m_currentRole == role) return;
    qInfo() << "[AppController] Cambio de rol:" << m_currentRole << "->" << role;
    m_currentRole = role;
    emit currentRoleChanged();
}

bool AppController::darkMode() const
{
    return m_db->getConfig("dark_mode", "true") == "true";
}

void AppController::setDarkMode(bool dark)
{
    qInfo() << "[AppController] Cambio de tema visual. Modo oscuro:" << dark;
    m_db->setConfig("dark_mode", dark ? "true" : "false");
    emit darkModeChanged();
}

EmployeeModel* AppController::employeeModel() const { return m_employeeModel; }
EmployeeVarsModel* AppController::employeeVarsModel() const { return m_employeeVarsModel; }
GlobalVarsModel* AppController::globalVarsModel() const { return m_globalVarsModel; }
SchemaModel* AppController::schemaModel() const { return m_schemaModel; }
CategoryModel* AppController::categoryModel() const { return m_categoryModel; }
CellModel* AppController::cellModel() const { return m_cellModel; }
ChartCellModel* AppController::chartCellModel() const { return m_chartCellModel; }
ReceiptHistoryModel* AppController::receiptHistoryModel() const { return m_receiptHistoryModel; }

QVariantMap AppController::processLiquidation(int employeeId, const QString &quincenaSel, const QString &fechaCalculo)
{
    qInfo() << "[AppController] Ejecutando procesamiento de liquidación para Empleado ID:" << employeeId << "Quincena:" << quincenaSel;
    return m_engine->processLiquidation(employeeId, quincenaSel, fechaCalculo);
}

int AppController::persistLiquidation(const QVariantMap &result, int mes, int anio, const QString &periodo)
{
    qInfo() << "[AppController] Persistiendo recibo histórico. Mes:" << mes << "Año:" << anio << "Período:" << periodo;
    return m_engine->persistLiquidation(result, mes, anio, periodo);
}

QString AppController::resetNewMonth()
{
    qInfo() << "[AppController] Iniciando proceso de Nuevo Mes (Reset + Backup)...";
    QString backup = m_db->resetNewMonth();
    m_employeeVarsModel->refresh();
    qInfo() << "[AppController] Nuevo Mes completado. Backup generado en:" << backup;
    return backup;
}

QString AppController::createBackup()
{
    qInfo() << "[AppController] Generando copia de seguridad de la base de datos...";
    QString backup = m_db->createBackup();
    qInfo() << "[AppController] Copia de seguridad guardada en:" << backup;
    return backup;
}

QVariantMap AppController::getCompany() const
{
    return m_db->getCompany();
}

bool AppController::saveCompany(const QString &razonSocial, const QString &direccion, const QString &cuit, const QString &lugarDePago)
{
    qInfo() << "[AppController] Guardando datos de la empresa:" << razonSocial;
    return m_db->saveCompany(razonSocial, direccion, cuit, lugarDePago);
}

QVariantList AppController::listSchemaFields(const QString &esquemaCodigo)
{
    return m_db->listSchemaFields(esquemaCodigo);
}

int AppController::addSchemaField(const QString &esquemaCodigo, const QString &fieldCode, const QString &fieldLabel, const QString &fieldType, const QString &defaultValue, int displayOrder)
{
    qInfo() << "[AppController] Agregando campo al esquema" << esquemaCodigo << ":" << fieldCode;
    int id = m_db->addSchemaField(esquemaCodigo, fieldCode, fieldLabel, fieldType, defaultValue, displayOrder);
    m_employeeVarsModel->refresh();
    return id;
}

bool AppController::removeSchemaField(int fieldId)
{
    qInfo() << "[AppController] Eliminando campo de esquema ID:" << fieldId;
    bool ok = m_db->removeSchemaField(fieldId);
    m_employeeVarsModel->refresh();
    return ok;
}

QStringList AppController::listEmployeeQuincenas(int employeeId)
{
    return m_db->listEmployeeQuincenas(employeeId);
}

bool AppController::addQuincena(int employeeId, const QString &quincenaCode)
{
    qInfo() << "[AppController] Agregando quincena" << quincenaCode << "a empleado ID:" << employeeId;
    bool ok = m_db->addQuincena(employeeId, quincenaCode);
    m_employeeVarsModel->refresh();
    return ok;
}

bool AppController::removeQuincena(int employeeId, const QString &quincenaCode)
{
    qInfo() << "[AppController] Eliminando quincena" << quincenaCode << "de empleado ID:" << employeeId;
    bool ok = m_db->removeQuincena(employeeId, quincenaCode);
    m_employeeVarsModel->refresh();
    return ok;
}
