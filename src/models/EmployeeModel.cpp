#include "EmployeeModel.h"
#include "database/DatabaseManager.h"
#include <QDebug>

EmployeeModel::EmployeeModel(DatabaseManager *db, QObject *parent)
    : QAbstractListModel(parent), m_db(db)
{
    qDebug() << "[EmployeeModel] Inicializado modelo de empleados.";
    refresh();
}

int EmployeeModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_filteredData.size();
}

QVariant EmployeeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_filteredData.size())
        return {};

    const QVariantMap &emp = m_filteredData[index.row()].toMap();

    switch (role) {
    case IdRole:               return emp["id"];
    case LegajoRole:           return emp["legajo"];
    case NombreRole:           return emp["nombre_completo"];
    case TipoLiquidacionRole:  return emp["tipo_liquidacion"];
    case EsquemaRole:          return emp["esquema_codigo"];
    case CategoriaIdRole:      return emp["categoria_jornal_id"];
    case CategoriaNombreRole:  return emp["categoria_nombre"];
    case FechaIngresoRole:     return emp["fecha_ingreso"];
    case CuilRole:             return emp["cuil"];
    default:                   return {};
    }
}

QHash<int, QByteArray> EmployeeModel::roleNames() const
{
    return {
        {IdRole, "employeeId"},
        {LegajoRole, "legajo"},
        {NombreRole, "nombre"},
        {TipoLiquidacionRole, "tipoLiquidacion"},
        {EsquemaRole, "esquema"},
        {CategoriaIdRole, "categoriaId"},
        {CategoriaNombreRole, "categoriaNombre"},
        {FechaIngresoRole, "fechaIngreso"},
        {CuilRole, "cuil"},
    };
}

int EmployeeModel::count() const
{
    return m_filteredData.size();
}

QString EmployeeModel::filterText() const
{
    return m_filterText;
}

void EmployeeModel::setFilterText(const QString &text)
{
    if (m_filterText == text) return;
    m_filterText = text;
    qDebug() << "[EmployeeModel] Aplicando filtro de búsqueda:" << m_filterText;
    applyFilter();
    emit filterTextChanged();
}

void EmployeeModel::applyFilter()
{
    beginResetModel();
    m_filteredData.clear();

    QString query = m_filterText.trimmed();
    if (query.isEmpty()) {
        m_filteredData = m_allData;
    } else {
        for (const QVariant &item : m_allData) {
            QVariantMap emp = item.toMap();
            QString legajo = emp["legajo"].toString();
            QString nombre = emp["nombre_completo"].toString();
            if (legajo.contains(query, Qt::CaseInsensitive) || nombre.contains(query, Qt::CaseInsensitive)) {
                m_filteredData.append(item);
            }
        }
    }
    endResetModel();
    emit countChanged();
    qDebug() << "[EmployeeModel] Filtro aplicado. Coincidencias encontradas:" << m_filteredData.size();
}

void EmployeeModel::refresh()
{
    qDebug() << "[EmployeeModel] Refrescando lista de empleados desde la BD...";
    m_allData = m_db->listEmployees();
    applyFilter();
    qInfo() << "[EmployeeModel] Lista de empleados actualizada. Total en BD:" << m_allData.size() << "Visibles:" << m_filteredData.size();
}

QVariantMap EmployeeModel::get(int row) const
{
    if (row < 0 || row >= m_filteredData.size()) {
        qWarning() << "[EmployeeModel] Intento de obtener fila fuera de rango:" << row;
        return {};
    }

    // --- Imprimir todo el contenedor como una lista de mapas ---
    QVariantList fullList;
    for (const auto &item : m_filteredData) {
        fullList.append(item.toMap());
    }
    qInfo() << "[EmployeeModel] Contenido completo de m_filteredData:" << fullList;
    // -----------------------------------------------------------

    return m_filteredData[row].toMap();
}

int EmployeeModel::idAtRow(int row) const
{
    if (row < 0 || row >= m_filteredData.size()) return -1;
    return m_filteredData[row].toMap()["id"].toInt();
}

int EmployeeModel::addEmployee(const QString &legajo, const QString &nombre,
                                const QString &tipoLiq, const QString &esquema,
                                int categoriaId, const QString &fechaIngreso,
                                const QString &cuil)
{
    qInfo() << "[EmployeeModel] Agregando nuevo empleado. Legajo:" << legajo << "Nombre:" << nombre << "Esquema:" << esquema;
    int id = m_db->saveEmployee(0, legajo, nombre, tipoLiq, esquema, categoriaId, fechaIngreso, cuil);
    if (id > 0) {
        qInfo() << "[EmployeeModel] Empleado agregado con ID generado:" << id;
        refresh();
    } else {
        qCritical() << "[EmployeeModel] Error al agregar empleado. Legajo:" << legajo;
    }
    return id;
}

bool EmployeeModel::saveEmployee(int id, const QString &legajo, const QString &nombre,
                                  const QString &tipoLiq, const QString &esquema,
                                  int categoriaId, const QString &fechaIngreso,
                                  const QString &cuil)
{
    qInfo() << "[EmployeeModel] Guardando cambios de empleado ID:" << id << "Legajo:" << legajo;
    int result = m_db->saveEmployee(id, legajo, nombre, tipoLiq, esquema, categoriaId, fechaIngreso, cuil);
    if (result > 0) {
        qInfo() << "[EmployeeModel] Cambios guardados exitosamente para empleado ID:" << id;
        refresh();
    } else {
        qCritical() << "[EmployeeModel] Error al guardar cambios de empleado ID:" << id;
    }
    return result > 0;
}

bool EmployeeModel::removeEmployee(int id)
{
    qInfo() << "[EmployeeModel] Solicitando eliminación de empleado ID:" << id;
    bool ok = m_db->deleteEmployee(id);
    if (ok) {
        qInfo() << "[EmployeeModel] Empleado ID:" << id << "eliminado exitosamente.";
        refresh();
    } else {
        qCritical() << "[EmployeeModel] Fallo al eliminar empleado ID:" << id;
    }
    return ok;
}

int EmployeeModel::duplicateEmployee(int id)
{
    qInfo() << "[EmployeeModel] Duplicando empleado origen ID:" << id;
    int newId = m_db->duplicateEmployee(id);
    if (newId > 0) {
        qInfo() << "[EmployeeModel] Empleado duplicado con éxito. Nuevo ID:" << newId;
        refresh();
    } else {
        qCritical() << "[EmployeeModel] Error al duplicar empleado origen ID:" << id;
    }
    return newId;
}
