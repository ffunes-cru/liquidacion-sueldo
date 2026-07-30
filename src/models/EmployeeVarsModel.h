#ifndef EMPLOYEEVARSMODEL_H
#define EMPLOYEEVARSMODEL_H

#include <QAbstractListModel>
#include <QVariantList>

class DatabaseManager;

/**
 * @brief Model for displaying/editing an employee's field values for a specific quincena.
 * Reads from schema_fields + employee_field_values tables.
 */
class EmployeeVarsModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int employeeId READ employeeId WRITE setEmployeeId NOTIFY employeeIdChanged)
    Q_PROPERTY(QString quincena READ quincena WRITE setQuincena NOTIFY quincenaChanged)

public:
    enum Roles {
        FieldIdRole = Qt::UserRole + 1,
        FieldCodeRole,
        FieldLabelRole,
        FieldTypeRole,
        ValueRole,
        DefaultValueRole,
    };

    explicit EmployeeVarsModel(DatabaseManager *db, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    bool setData(const QModelIndex &index, const QVariant &value, int role = Qt::EditRole) override;
    Qt::ItemFlags flags(const QModelIndex &index) const override;
    QHash<int, QByteArray> roleNames() const override;

    int employeeId() const;
    void setEmployeeId(int id);
    QString quincena() const;
    void setQuincena(const QString &q);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool setValue(int row, const QString &value);

signals:
    void employeeIdChanged();
    void quincenaChanged();

private:
    DatabaseManager *m_db;
    int m_employeeId = -1;
    QString m_quincena = "Q1";
    QVariantList m_data;
};

#endif // EMPLOYEEVARSMODEL_H
