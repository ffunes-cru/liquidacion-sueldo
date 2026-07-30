#include "ChartCellModel.h"
#include "database/DatabaseManager.h"

ChartCellModel::ChartCellModel(DatabaseManager *db, QObject *parent)
    : QAbstractListModel(parent), m_db(db)
{
}

int ChartCellModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_data.size();
}

QVariant ChartCellModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_data.size()) return {};
    const QVariantMap &cg = m_data[index.row()].toMap();

    switch (role) {
    case IdRole:            return cg["id"];
    case EtiquetaRole:      return cg["etiqueta"];
    case FormulaRole:       return cg["formula"];
    case OrdenRole:         return cg["orden"];
    case EsquemaCodigoRole: return cg["esquema_codigo"];
    default:                return {};
    }
}

QHash<int, QByteArray> ChartCellModel::roleNames() const
{
    return {
        {IdRole, "chartId"},
        {EtiquetaRole, "etiqueta"},
        {FormulaRole, "formula"},
        {OrdenRole, "orden"},
        {EsquemaCodigoRole, "esquemaCodigo"}
    };
}

QString ChartCellModel::esquemaCodigo() const
{
    return m_esquemaCodigo;
}

void ChartCellModel::setEsquemaCodigo(const QString &esquema)
{
    if (m_esquemaCodigo == esquema) return;
    m_esquemaCodigo = esquema;
    emit esquemaCodigoChanged();
    refresh();
}

int ChartCellModel::count() const
{
    return m_data.size();
}

void ChartCellModel::refresh()
{
    beginResetModel();
    if (!m_esquemaCodigo.isEmpty()) {
        m_data = m_db->listChartCellsBySchema(m_esquemaCodigo);
    } else {
        m_data.clear();
    }
    endResetModel();
    emit countChanged();
}

int ChartCellModel::saveChartCell(int id, const QString &etiqueta, const QString &formula, int orden, const QString &esquemaCodigo)
{
    int cellId = m_db->saveChartCell(id, etiqueta, formula, orden, esquemaCodigo);
    if (cellId > 0) refresh();
    return cellId;
}

bool ChartCellModel::removeChartCell(int id)
{
    bool ok = m_db->deleteChartCell(id);
    if (ok) refresh();
    return ok;
}
