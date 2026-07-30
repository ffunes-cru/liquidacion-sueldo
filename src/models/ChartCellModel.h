#ifndef CHARTCELLMODEL_H
#define CHARTCELLMODEL_H

#include <QAbstractListModel>
#include <QVariantList>

class DatabaseManager;

class ChartCellModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString esquemaCodigo READ esquemaCodigo WRITE setEsquemaCodigo NOTIFY esquemaCodigoChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        EtiquetaRole,
        FormulaRole,
        OrdenRole,
        EsquemaCodigoRole
    };

    explicit ChartCellModel(DatabaseManager *db, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString esquemaCodigo() const;
    void setEsquemaCodigo(const QString &esquema);

    int count() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE int saveChartCell(int id, const QString &etiqueta, const QString &formula, int orden, const QString &esquemaCodigo);
    Q_INVOKABLE bool removeChartCell(int id);

signals:
    void esquemaCodigoChanged();
    void countChanged();

private:
    DatabaseManager *m_db;
    QString m_esquemaCodigo;
    QVariantList m_data;
};

#endif // CHARTCELLMODEL_H
