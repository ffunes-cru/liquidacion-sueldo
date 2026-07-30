#ifndef GLOBALVARSMODEL_H
#define GLOBALVARSMODEL_H

#include <QAbstractListModel>
#include <QVariantList>

class DatabaseManager;

class GlobalVarsModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        CodeRole,
        ValueRole,
        DescriptionRole
    };

    explicit GlobalVarsModel(DatabaseManager *db, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE int saveVariable(int id, const QString &code, const QString &value, const QString &description);
    Q_INVOKABLE bool removeVariable(int id);

signals:
    void countChanged();

private:
    DatabaseManager *m_db;
    QVariantList m_data;
};

#endif // GLOBALVARSMODEL_H
