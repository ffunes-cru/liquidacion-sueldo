#include "EmployeeVarsModel.h"
#include "database/DatabaseManager.h"
#include <QDebug>

EmployeeVarsModel::EmployeeVarsModel(DatabaseManager *db, QObject *parent)
    : QAbstractListModel(parent), m_db(db)
{
    qDebug() << "[EmployeeVarsModel] Inicializado modelo de variables de empleado.";
}

int EmployeeVarsModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_data.size();
}

QVariant EmployeeVarsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_data.size()) return {};
    const QVariantMap &f = m_data[index.row()].toMap();

    switch (role) {
    case FieldIdRole:      return f["field_id"];
    case FieldCodeRole:    return f["field_code"];
    case FieldLabelRole:   return f["field_label"];
    case FieldTypeRole:    return f["field_type"];
    case ValueRole:        return f["value"];
    case DefaultValueRole: return f["default_value"];
    default:               return {};
    }
}

bool EmployeeVarsModel::setData(const QModelIndex &index, const QVariant &value, int role)
{
    if (!index.isValid() || index.row() >= m_data.size() || role != ValueRole)
        return false;

    QVariantMap f = m_data[index.row()].toMap();
    int fieldId = f["field_id"].toInt();
    QString fieldCode = f["field_code"].toString();
    QString fieldType = f["field_type"].toString().toLower();
    QString rawValue = value.toString().trimmed();
    QString validatedValue = rawValue;

    // Strict backend type validation
    if (fieldType == "number") {
        rawValue.replace(',', '.'); // Allow comma as decimal separator
        bool ok;
        double num = rawValue.toDouble(&ok);
        if (!ok && !rawValue.isEmpty()) {
            qWarning() << "[EmployeeVarsModel] Validación rechazada: la variable '" << fieldCode 
                       << "' requiere un número válido, se ingresó:" << value.toString();
            return false;
        }
        validatedValue = ok ? QString::number(num, 'g', 10) : "0";
    } else if (fieldType == "bool") {
        QString s = rawValue.toLower();
        validatedValue = (s == "true" || s == "1" || s == "sí" || s == "si") ? "true" : "false";
    }

    qInfo() << "[EmployeeVarsModel] Asignando variable" << fieldCode << "=" << validatedValue
            << "(Tipo:" << fieldType << ") para Empleado ID:" << m_employeeId << "Quincena:" << m_quincena;

    if (m_db->setEmployeeFieldValue(m_employeeId, fieldId, m_quincena, validatedValue)) {
        f["value"] = validatedValue;
        m_data[index.row()] = f;
        emit dataChanged(index, index, {ValueRole});
        return true;
    }

    qCritical() << "[EmployeeVarsModel] Fallo en BD al guardar variable" << fieldCode;
    return false;
}

Qt::ItemFlags EmployeeVarsModel::flags(const QModelIndex &index) const
{
    if (!index.isValid()) return Qt::NoItemFlags;
    return Qt::ItemIsEditable | Qt::ItemIsEnabled | Qt::ItemIsSelectable;
}

QHash<int, QByteArray> EmployeeVarsModel::roleNames() const
{
    return {
        {FieldIdRole, "fieldId"},
        {FieldCodeRole, "fieldCode"},
        {FieldLabelRole, "fieldLabel"},
        {FieldTypeRole, "fieldType"},
        {ValueRole, "value"},
        {DefaultValueRole, "defaultValue"},
    };
}

int EmployeeVarsModel::employeeId() const { return m_employeeId; }

void EmployeeVarsModel::setEmployeeId(int id)
{
    qDebug() << "[EmployeeVarsModel] Seleccionado Empleado ID:" << id;
    m_employeeId = id;
    emit employeeIdChanged();
    refresh();
}

QString EmployeeVarsModel::quincena() const { return m_quincena; }

void EmployeeVarsModel::setQuincena(const QString &q)
{
    if (m_quincena == q) return;
    qDebug() << "[EmployeeVarsModel] Seleccionada Quincena:" << q;
    m_quincena = q;
    emit quincenaChanged();
    refresh();
}

void EmployeeVarsModel::refresh()
{
    beginResetModel();
    if (m_employeeId > 0) {
        m_data = m_db->getEmployeeFieldValues(m_employeeId, m_quincena);
        qDebug() << "[EmployeeVarsModel] Variables cargadas para Empleado ID:" << m_employeeId << "Quincena:" << m_quincena << "Total:" << m_data.size();
    } else {
        m_data.clear();
    }
    endResetModel();
}

bool EmployeeVarsModel::setValue(int row, const QString &value)
{
    return setData(index(row), value, ValueRole);
}
