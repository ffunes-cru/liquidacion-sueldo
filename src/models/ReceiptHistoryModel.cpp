#include "ReceiptHistoryModel.h"
#include "database/DatabaseManager.h"

ReceiptHistoryModel::ReceiptHistoryModel(DatabaseManager *db, QObject *parent)
    : QAbstractListModel(parent), m_db(db)
{
}

int ReceiptHistoryModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_data.size();
}

QVariant ReceiptHistoryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_data.size()) return {};
    const QVariantMap &r = m_data[index.row()].toMap();

    switch (role) {
    case IdRole:             return r["id"];
    case EmpleadoIdRole:     return r["empleado_id"];
    case EsquemaCodigoRole:  return r["esquema_codigo"];
    case MesRole:            return r["mes"];
    case AnioRole:           return r["anio"];
    case PeriodoRole:        return r["periodo"];
    case DatosJsonRole:      return r["datos_json"];
    case FechaEmisionRole:   return r["fecha_emision"];
    case NombreCompletoRole: return r["nombre_completo"];
    case LegajoRole:         return r["legajo"];
    default:                 return {};
    }
}

QHash<int, QByteArray> ReceiptHistoryModel::roleNames() const
{
    return {
        {IdRole, "receiptId"},
        {EmpleadoIdRole, "empleadoId"},
        {EsquemaCodigoRole, "esquemaCodigo"},
        {MesRole, "mes"},
        {AnioRole, "anio"},
        {PeriodoRole, "periodo"},
        {DatosJsonRole, "datosJson"},
        {FechaEmisionRole, "fechaEmision"},
        {NombreCompletoRole, "nombreCompleto"},
        {LegajoRole, "legajo"}
    };
}

int ReceiptHistoryModel::employeeId() const
{
    return m_employeeId;
}

void ReceiptHistoryModel::setEmployeeId(int empId)
{
    if (m_employeeId == empId) return;
    m_employeeId = empId;
    emit employeeIdChanged();
    refresh();
}

int ReceiptHistoryModel::count() const
{
    return m_data.size();
}

void ReceiptHistoryModel::refresh()
{
    beginResetModel();
    if (m_employeeId > 0) {
        m_data = m_db->listReceiptsByEmployee(m_employeeId);
    } else {
        m_data.clear();
    }
    endResetModel();
    emit countChanged();
}

bool ReceiptHistoryModel::removeReceipt(int id)
{
    bool ok = m_db->deleteReceipt(id);
    if (ok) refresh();
    return ok;
}

QVariantMap ReceiptHistoryModel::getReceipt(int id) const
{
    return m_db->getReceipt(id);
}
