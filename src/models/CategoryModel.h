#ifndef CATEGORYMODEL_H
#define CATEGORYMODEL_H

#include <QAbstractListModel>
#include <QVariantList>

class DatabaseManager;

class CategoryModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        ValorHoraRole
    };

    explicit CategoryModel(DatabaseManager *db, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE int saveCategory(int id, const QString &name, double valorHora);
    Q_INVOKABLE bool removeCategory(int id);

signals:
    void countChanged();

private:
    DatabaseManager *m_db;
    QVariantList m_data;
};

#endif // CATEGORYMODEL_H
