#ifndef CUSTOMFUNCTIONMODEL_H
#define CUSTOMFUNCTIONMODEL_H

#include <QAbstractListModel>
#include <QVariantList>

class DatabaseManager;

class CustomFunctionModel : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
  enum Roles {
    IdRole = Qt::UserRole + 1,
    NameRole,
    ParamsRole,
    BodyRole,
    DescriptionRole,
    EsquemaRole
  };

  explicit CustomFunctionModel(DatabaseManager *db, QObject *parent = nullptr);

  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  int count() const;

  Q_INVOKABLE void refresh();
  Q_INVOKABLE QVariantMap get(int index) const;
  Q_INVOKABLE int saveFunction(int id, const QString &name,
                               const QString &params, const QString &body,
                               const QString &description,
                               const QString &esquemaCodigo = "");
  Q_INVOKABLE bool removeFunction(int id);

signals:
  void countChanged();
  void saveError(const QString &message);

private:
  DatabaseManager *m_db;
  QVariantList m_data;
};

#endif // CUSTOMFUNCTIONMODEL_H
