#include "CustomFunctionModel.h"
#include "database/DatabaseManager.h"

CustomFunctionModel::CustomFunctionModel(DatabaseManager *db, QObject *parent)
    : QAbstractListModel(parent), m_db(db) {
  refresh();
}

int CustomFunctionModel::rowCount(const QModelIndex &parent) const {
  Q_UNUSED(parent);
  return m_data.size();
}

QVariant CustomFunctionModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() >= m_data.size())
    return {};
  const QVariantMap &fn = m_data[index.row()].toMap();

  switch (role) {
  case IdRole:
    return fn.value("id", 0);
  case NameRole:
    return fn.value("name", "");
  case ParamsRole:
    return fn.value("params", "");
  case BodyRole:
    return fn.value("body", "");
  case DescriptionRole:
    return fn.value("description", "");
  case EsquemaRole:
    return fn.value("esquema_codigo", "");
  default:
    return {};
  }
}

QHash<int, QByteArray> CustomFunctionModel::roleNames() const {
  return {{IdRole, "funcId"},
          {NameRole, "funcName"},
          {ParamsRole, "funcParams"},
          {BodyRole, "funcBody"},
          {DescriptionRole, "funcDescription"},
          {EsquemaRole, "funcEsquema"}};
}

int CustomFunctionModel::count() const { return m_data.size(); }

void CustomFunctionModel::refresh() {
  beginResetModel();
  m_data = m_db->listCustomFunctions();
  endResetModel();
  emit countChanged();
}

QVariantMap CustomFunctionModel::get(int index) const {
  if (index < 0 || index >= m_data.size()) return {};
  QVariantMap map = m_data[index].toMap();
  map["funcId"] = map.value("id");
  map["funcName"] = map.value("name");
  map["funcParams"] = map.value("params");
  map["funcBody"] = map.value("body");
  map["funcDescription"] = map.value("description");
  map["funcEsquema"] = map.value("esquema_codigo");
  return map;
}

int CustomFunctionModel::saveFunction(int id, const QString &name,
                                      const QString &params,
                                      const QString &body,
                                      const QString &description,
                                      const QString &esquemaCodigo) {
  int funcId = m_db->saveCustomFunction(id, name, params, body, description,
                                        esquemaCodigo);
  if (funcId > 0) {
    refresh();
  } else {
    emit saveError("Error al guardar la función. Verificá que el nombre sea un "
                   "identificador válido (sin espacios ni caracteres "
                   "especiales) y que no esté duplicado.");
  }
  return funcId;
}

bool CustomFunctionModel::removeFunction(int id) {
  bool ok = m_db->deleteCustomFunction(id);
  if (ok)
    refresh();
  return ok;
}
