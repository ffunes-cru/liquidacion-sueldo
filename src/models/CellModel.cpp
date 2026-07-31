#include "CellModel.h"
#include "database/DatabaseManager.h"

CellModel::CellModel(DatabaseManager *db, QObject *parent)
    : QAbstractListModel(parent), m_db(db)
{
}

int CellModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_data.size();
}

QVariant CellModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_data.size()) return {};
    const QVariantMap &c = m_data[index.row()].toMap();

    switch (role) {
    case IdRole:                 return c["id"];
    case SeccionCodigoRole:      return c["seccion_codigo"];
    case CodigoVariableRole:     return c["codigo_variable"];
    case DescripcionRole:        return c["descripcion"];
    case CondicionRole:          return c["condicion"];
    case FormulaUnidadRole:      return c["formula_unidad"];
    case FormulaBaseRole:        return c["formula_base"];
    case FormulaMontoRole:       return c["formula_monto"];
    case OrdenRole:              return c["orden"];
    case EsquemaCodigoRole:      return c["esquema_codigo"];
    case TipoCalculoRole:        return c["tipo_calculo"];
    case SimplePorcentajeRole:   return c["simple_porcentaje"];
    case SimpleBaseVariableRole: return c["simple_base_variable"];
    case SimpleMontoFijoRole:    return c["simple_monto_fijo"];
    case VisibleReciboRole:      return c["visible_recibo"];
    default:                     return {};
    }
}

QHash<int, QByteArray> CellModel::roleNames() const
{
    return {
        {IdRole, "cellId"},
        {SeccionCodigoRole, "seccionCodigo"},
        {CodigoVariableRole, "codigoVariable"},
        {DescripcionRole, "descripcion"},
        {CondicionRole, "condicion"},
        {FormulaUnidadRole, "formulaUnidad"},
        {FormulaBaseRole, "formulaBase"},
        {FormulaMontoRole, "formulaMonto"},
        {OrdenRole, "orden"},
        {EsquemaCodigoRole, "esquemaCodigo"},
        {TipoCalculoRole, "tipoCalculo"},
        {SimplePorcentajeRole, "simplePorcentaje"},
        {SimpleBaseVariableRole, "simpleBaseVariable"},
        {SimpleMontoFijoRole, "simpleMontoFijo"},
        {VisibleReciboRole, "visibleRecibo"}
    };
}

QString CellModel::esquemaCodigo() const
{
    return m_esquemaCodigo;
}

void CellModel::setEsquemaCodigo(const QString &esquema)
{
    if (m_esquemaCodigo == esquema) return;
    m_esquemaCodigo = esquema;
    emit esquemaCodigoChanged();
    refresh();
}

int CellModel::count() const
{
    return m_data.size();
}

void CellModel::refresh()
{
    beginResetModel();
    if (m_esquemaCodigo.isEmpty()) {
        m_data = m_db->listAllCells();
    } else {
        m_data = m_db->listCellsBySchema(m_esquemaCodigo);
    }
    endResetModel();
    emit countChanged();
}

QVariantMap CellModel::get(int row) const
{
    if (row < 0 || row >= m_data.size()) return {};
    return m_data[row].toMap();
}

int CellModel::saveCell(int id, const QString &seccionCodigo, const QString &codigoVariable,
                        const QString &descripcion, const QString &condicion,
                        const QString &formulaUnidad, const QString &formulaBase,
                        const QString &formulaMonto, int orden, const QString &esquemaCodigo,
                        const QString &tipoCalculo, double simplePorcentaje,
                        const QString &simpleBaseVariable, double simpleMontoFijo,
                        bool visibleRecibo)
{
    int cellId = m_db->saveCell(id, seccionCodigo, codigoVariable, descripcion, condicion,
                                formulaUnidad, formulaBase, formulaMonto, orden,
                                esquemaCodigo, tipoCalculo, simplePorcentaje,
                                simpleBaseVariable, simpleMontoFijo, visibleRecibo);
    if (cellId > 0) refresh();
    return cellId;
}

bool CellModel::removeCell(int id)
{
    bool ok = m_db->deleteCell(id);
    if (ok) refresh();
    return ok;
}

bool CellModel::moveCellUp(int index)
{
    if (index <= 0 || index >= m_data.size()) return false;

    QVariantMap item1 = m_data[index].toMap();
    QVariantMap item2 = m_data[index - 1].toMap();

    int id1 = item1["id"].toInt();
    int id2 = item2["id"].toInt();
    int order1 = item1["orden"].toInt();
    int order2 = item2["orden"].toInt();

    if (order1 == order2) {
        order1 = index * 10 + 10;
        order2 = (index - 1) * 10 + 10;
    }

    // Swap orders
    m_db->saveCell(id1, item1["seccion_codigo"].toString(), item1["codigo_variable"].toString(),
                   item1["descripcion"].toString(), item1["condicion"].toString(),
                   item1["formula_unidad"].toString(), item1["formula_base"].toString(),
                   item1["formula_monto"].toString(), order2, item1["esquema_codigo"].toString(),
                   item1["tipo_calculo"].toString(), item1["simple_porcentaje"].toDouble(),
                   item1["simple_base_variable"].toString(), item1["simple_monto_fijo"].toDouble(),
                   item1["visible_recibo"].toBool());

    m_db->saveCell(id2, item2["seccion_codigo"].toString(), item2["codigo_variable"].toString(),
                   item2["descripcion"].toString(), item2["condicion"].toString(),
                   item2["formula_unidad"].toString(), item2["formula_base"].toString(),
                   item2["formula_monto"].toString(), order1, item2["esquema_codigo"].toString(),
                   item2["tipo_calculo"].toString(), item2["simple_porcentaje"].toDouble(),
                   item2["simple_base_variable"].toString(), item2["simple_monto_fijo"].toDouble(),
                   item2["visible_recibo"].toBool());

    refresh();
    return true;
}

bool CellModel::moveCellDown(int index)
{
    if (index < 0 || index >= m_data.size() - 1) return false;
    return moveCellUp(index + 1);
}

bool CellModel::moveCell(int fromIndex, int toIndex)
{
    if (fromIndex < 0 || fromIndex >= m_data.size()) return false;
    if (toIndex < 0 || toIndex >= m_data.size()) return false;
    if (fromIndex == toIndex) return true;

    beginResetModel();
    QVariant item = m_data.takeAt(fromIndex);
    m_data.insert(toIndex, item);

    for (int i = 0; i < m_data.size(); ++i) {
        QVariantMap m = m_data[i].toMap();
        int cellId = m["id"].toInt();
        int newOrder = (i + 1) * 10;
        m["orden"] = newOrder;
        m_data[i] = m;
        m_db->saveCell(cellId, m["seccion_codigo"].toString(), m["codigo_variable"].toString(),
                       m["descripcion"].toString(), m["condicion"].toString(),
                       m["formula_unidad"].toString(), m["formula_base"].toString(),
                       m["formula_monto"].toString(), newOrder, m["esquema_codigo"].toString(),
                       m["tipo_calculo"].toString(), m["simple_porcentaje"].toDouble(),
                       m["simple_base_variable"].toString(), m["simple_monto_fijo"].toDouble(),
                       m["visible_recibo"].toBool());
    }
    endResetModel();
    return true;
}


