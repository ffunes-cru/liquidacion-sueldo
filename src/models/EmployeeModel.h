#ifndef EMPLOYEEMODEL_H
#define EMPLOYEEMODEL_H

#include <QAbstractListModel>
#include <QVariantList>
#include <QString>

class DatabaseManager;

class EmployeeModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        LegajoRole,
        NombreRole,
        TipoLiquidacionRole,
        EsquemaRole,
        CategoriaIdRole,
        CategoriaNombreRole,
        FechaIngresoRole,
        CuilRole,
    };

    explicit EmployeeModel(DatabaseManager *db, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;

    QString filterText() const;
    void setFilterText(const QString &text);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int idAtRow(int row) const;

    Q_INVOKABLE int addEmployee(const QString &legajo, const QString &nombre,
                                 const QString &tipoLiq, const QString &esquema,
                                 int categoriaId, const QString &fechaIngreso,
                                 const QString &cuil);
    Q_INVOKABLE bool saveEmployee(int id, const QString &legajo, const QString &nombre,
                                   const QString &tipoLiq, const QString &esquema,
                                   int categoriaId, const QString &fechaIngreso,
                                   const QString &cuil);
    Q_INVOKABLE bool removeEmployee(int id);
    Q_INVOKABLE int duplicateEmployee(int id);

signals:
    void countChanged();
    void filterTextChanged();

private:
    void applyFilter();

    DatabaseManager *m_db;
    QString m_filterText;
    QVariantList m_allData;
    QVariantList m_filteredData;
};

#endif // EMPLOYEEMODEL_H
