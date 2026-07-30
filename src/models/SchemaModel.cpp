#include "SchemaModel.h"
#include "database/DatabaseManager.h"

SchemaModel::SchemaModel(DatabaseManager *db, QObject *parent)
    : QAbstractListModel(parent), m_db(db)
{
    refresh();
}

int SchemaModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_data.size();
}

QVariant SchemaModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_data.size()) return {};
    const QVariantMap &schema = m_data[index.row()].toMap();

    switch (role) {
    case CodeRole:            return schema["codigo"];
    case NameRole:            return schema["nombre"];
    case TipoLiquidacionRole: return schema["tipo_liquidacion"];
    default:                  return {};
    }
}

QHash<int, QByteArray> SchemaModel::roleNames() const
{
    return {
        {CodeRole, "code"},
        {NameRole, "name"},
        {TipoLiquidacionRole, "tipoLiquidacion"}
    };
}

int SchemaModel::count() const
{
    return m_data.size();
}

void SchemaModel::refresh()
{
    beginResetModel();
    m_data = m_db->listSchemas();
    endResetModel();
    emit countChanged();
}

bool SchemaModel::saveSchema(const QString &originalCode, const QString &newCode, const QString &name, const QString &tipoLiq)
{
    bool ok = m_db->saveSchema(originalCode, newCode, name, tipoLiq);
    if (ok) refresh();
    return ok;
}

bool SchemaModel::removeSchema(const QString &code)
{
    bool ok = m_db->deleteSchema(code);
    if (ok) refresh();
    return ok;
}
