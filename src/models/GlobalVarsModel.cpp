#include "GlobalVarsModel.h"
#include "database/DatabaseManager.h"

GlobalVarsModel::GlobalVarsModel(DatabaseManager *db, QObject *parent)
    : QAbstractListModel(parent), m_db(db)
{
    refresh();
}

int GlobalVarsModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_data.size();
}

QVariant GlobalVarsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_data.size()) return {};
    const QVariantMap &varMap = m_data[index.row()].toMap();

    switch (role) {
    case IdRole:          return varMap["id"];
    case CodeRole:        return varMap["codigo"];
    case ValueRole:       return varMap["valor"];
    case DescriptionRole: return varMap["descripcion"];
    default:              return {};
    }
}

QHash<int, QByteArray> GlobalVarsModel::roleNames() const
{
    return {
        {IdRole, "varId"},
        {CodeRole, "code"},
        {ValueRole, "value"},
        {DescriptionRole, "description"}
    };
}

int GlobalVarsModel::count() const
{
    return m_data.size();
}

void GlobalVarsModel::refresh()
{
    beginResetModel();
    m_data = m_db->listGlobalVariables();
    endResetModel();
    emit countChanged();
}

int GlobalVarsModel::saveVariable(int id, const QString &code, const QString &value, const QString &description)
{
    int varId = m_db->saveGlobalVariable(id, code, value, description);
    if (varId > 0) refresh();
    return varId;
}

bool GlobalVarsModel::removeVariable(int id)
{
    bool ok = m_db->deleteGlobalVariable(id);
    if (ok) refresh();
    return ok;
}
