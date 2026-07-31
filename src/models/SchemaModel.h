#ifndef SCHEMAMODEL_H
#define SCHEMAMODEL_H

#include <QAbstractListModel>
#include <QVariantList>

class DatabaseManager;

class SchemaModel : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
  enum Roles { CodeRole = Qt::UserRole + 1, NameRole, TipoLiquidacionRole };

  explicit SchemaModel(DatabaseManager *db, QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  int count() const;

  Q_INVOKABLE void refresh();
  Q_INVOKABLE QVariantMap get(int row) const;
  Q_INVOKABLE bool saveSchema(const QString &originalCode,
                              const QString &newCode, const QString &name,
                              const QString &tipoLiq);
  Q_INVOKABLE bool removeSchema(const QString &code);

signals:
  void countChanged();

private:
  DatabaseManager *m_db;
  QVariantList m_data;
};

#endif // SCHEMAMODEL_H
