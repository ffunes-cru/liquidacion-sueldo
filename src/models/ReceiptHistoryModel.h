#ifndef RECEIPTHISTORYMODEL_H
#define RECEIPTHISTORYMODEL_H

#include <QAbstractListModel>
#include <QVariantList>

class DatabaseManager;

class ReceiptHistoryModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int employeeId READ employeeId WRITE setEmployeeId NOTIFY employeeIdChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        EmpleadoIdRole,
        EsquemaCodigoRole,
        MesRole,
        AnioRole,
        PeriodoRole,
        DatosJsonRole,
        FechaEmisionRole,
        NombreCompletoRole,
        LegajoRole
    };

    explicit ReceiptHistoryModel(DatabaseManager *db, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int employeeId() const;
    void setEmployeeId(int empId);

    int count() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool removeReceipt(int id);
    Q_INVOKABLE QVariantMap getReceipt(int id) const;

signals:
    void employeeIdChanged();
    void countChanged();

private:
    DatabaseManager *m_db;
    int m_employeeId = -1;
    QVariantList m_data;
};

#endif // RECEIPTHISTORYMODEL_H
