#include "CategoryModel.h"
#include "database/DatabaseManager.h"

CategoryModel::CategoryModel(DatabaseManager *db, QObject *parent)
    : QAbstractListModel(parent), m_db(db)
{
    refresh();
}

int CategoryModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_data.size();
}

QVariant CategoryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_data.size()) return {};
    const QVariantMap &cat = m_data[index.row()].toMap();

    switch (role) {
    case IdRole:        return cat["id"];
    case NameRole:      return cat["nombre"];
    case ValorHoraRole: return cat["valor_hora"];
    default:            return {};
    }
}

QHash<int, QByteArray> CategoryModel::roleNames() const
{
    return {
        {IdRole, "catId"},
        {NameRole, "name"},
        {ValorHoraRole, "valorHora"}
    };
}

int CategoryModel::count() const
{
    return m_data.size();
}

void CategoryModel::refresh()
{
    beginResetModel();
    m_data = m_db->listCategories();
    endResetModel();
    emit countChanged();
}

int CategoryModel::saveCategory(int id, const QString &name, double valorHora)
{
    int catId = m_db->saveCategory(id, name, valorHora);
    if (catId > 0) refresh();
    return catId;
}

bool CategoryModel::removeCategory(int id)
{
    bool ok = m_db->deleteCategory(id);
    if (ok) refresh();
    return ok;
}
