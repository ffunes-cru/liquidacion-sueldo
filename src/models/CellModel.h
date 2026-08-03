#ifndef CELLMODEL_H
#define CELLMODEL_H

#include <QAbstractListModel>
#include <QVariantList>

class DatabaseManager;

class CellModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString esquemaCodigo READ esquemaCodigo WRITE setEsquemaCodigo NOTIFY esquemaCodigoChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        SeccionCodigoRole,
        CodigoVariableRole,
        DescripcionRole,
        CondicionRole,
        FormulaUnidadRole,
        FormulaBaseRole,
        FormulaMontoRole,
        OrdenRole,
        EsquemaCodigoRole,
        TipoCalculoRole,
        SimplePorcentajeRole,
        SimpleBaseVariableRole,
        SimpleMontoFijoRole,
        VisibleReciboRole,
        ColorHexRole,
        EnGraficoRole,
        EsGraficoTotalRole
    };

    explicit CellModel(DatabaseManager *db, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString esquemaCodigo() const;
    void setEsquemaCodigo(const QString &esquema);

    int count() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int saveCell(int id, const QString &seccionCodigo, const QString &codigoVariable,
                             const QString &descripcion, const QString &condicion,
                             const QString &formulaUnidad, const QString &formulaBase,
                             const QString &formulaMonto, int orden, const QString &esquemaCodigo,
                             const QString &tipoCalculo, double simplePorcentaje,
                             const QString &simpleBaseVariable, double simpleMontoFijo,
                             bool visibleRecibo, const QString &colorHex = "",
                             bool enGrafico = false, bool esGraficoTotal = false);
    Q_INVOKABLE bool updateCellColor(int id, const QString &colorHex);
    Q_INVOKABLE bool removeCell(int id);
    Q_INVOKABLE bool moveCellUp(int index);
    Q_INVOKABLE bool moveCellDown(int index);
    Q_INVOKABLE bool moveCell(int fromIndex, int toIndex);

signals:
    void esquemaCodigoChanged();
    void countChanged();

private:
    DatabaseManager *m_db;
    QString m_esquemaCodigo;
    QVariantList m_data;
};

#endif // CELLMODEL_H
