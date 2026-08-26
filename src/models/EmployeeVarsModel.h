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
    Q_PROPERTY(int anio READ anio WRITE setAnio NOTIFY periodChanged)
    Q_PROPERTY(int mes READ mes WRITE setMes NOTIFY periodChanged)
    Q_PROPERTY(bool isReadOnly READ isReadOnly WRITE setIsReadOnly NOTIFY isReadOnlyChanged)

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

    int anio() const;
    void setAnio(int y);
    int mes() const;
    void setMes(int m);
    void setPeriod(int y, int m);

    bool isReadOnly() const;
    void setIsReadOnly(bool ro);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool setValue(int row, const QString &value);

signals:
    void employeeIdChanged();
    void quincenaChanged();
    void periodChanged();
    void isReadOnlyChanged();

private:
    DatabaseManager *m_db;
    int m_employeeId = -1;
    QString m_quincena = "Q1";
    int m_anio = 0;
    int m_mes = 0;
    bool m_isReadOnly = false;
    QVariantList m_data;
};

#endif // EMPLOYEEVARSMODEL_H
