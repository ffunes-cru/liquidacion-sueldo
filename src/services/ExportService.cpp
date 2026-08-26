#include "ExportService.h"
#include "database/DatabaseManager.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QPainter>
#include <QPdfWriter>
#include <QSqlQuery>
#include <QTextStream>

#include "xlsxdocument.h"

static QString fmtNum(double val, int decimals = 2)
{
    if (val == 0.0) return "-";
    QLocale loc(QLocale::Spanish, QLocale::Argentina);
    return loc.toString(val, 'f', decimals);
}

static QString fmtMoney(double val)
{
    if (val == 0.0) return "-";
    QLocale loc(QLocale::Spanish, QLocale::Argentina);
    return "$ " + loc.toString(val, 'f', 2);
}

ExportService::ExportService(DatabaseManager *db, QObject *parent)
    : QObject(parent), m_db(db)
{
}

// ═══════════════════════════════════════════════════════════════════
// Path Helpers
// ═══════════════════════════════════════════════════════════════════

QString ExportService::ensureXlsxPath(const QString &path) const
{
    if (!path.isEmpty()) return path;
    QString dir = QCoreApplication::applicationDirPath();
    return dir + "/datos_liquidacion_sueldos.xlsx";
}

QString ExportService::ensureCsvDir(const QString &path) const
{
    if (!path.isEmpty()) return path;
    QString dir = QCoreApplication::applicationDirPath() + "/csv_export";
    QDir().mkpath(dir);
    return dir;
}

QString ExportService::ensurePdfPath(const QString &path) const
{
    if (!path.isEmpty()) return path;
    QString dir = QCoreApplication::applicationDirPath();
    return dir + "/recibo_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss") + ".pdf";
}

// ═══════════════════════════════════════════════════════════════════
// Excel Export
// ═══════════════════════════════════════════════════════════════════

QString ExportService::exportDataXlsx(const QString &path)
{
    QString filePath = ensureXlsxPath(path);
    qInfo() << "[ExportService] Exportando datos a Excel:" << filePath;

    QXlsx::Document xlsx;

    // 1. Esquemas de Cálculo
    xlsx.addSheet("Esquemas de Cálculo");
    xlsx.selectSheet("Esquemas de Cálculo");
    xlsx.write(1, 1, "codigo");
    xlsx.write(1, 2, "nombre");
    auto schemas = m_db->listSchemas();
    int row = 2;
    for (const auto &s : schemas) {
        auto m = s.toMap();
        xlsx.write(row, 1, m["codigo"].toString());
        xlsx.write(row, 2, m["nombre"].toString());
        row++;
    }

    // 2. Categorías Jornaleras
    xlsx.addSheet("Categorías Jornaleras");
    xlsx.selectSheet("Categorías Jornaleras");
    xlsx.write(1, 1, "id");
    xlsx.write(1, 2, "nombre");
    xlsx.write(1, 3, "valor_hora");
    auto cats = m_db->listCategories();
    row = 2;
    for (const auto &c : cats) {
        auto m = c.toMap();
        xlsx.write(row, 1, m["id"].toInt());
        xlsx.write(row, 2, m["nombre"].toString());
        xlsx.write(row, 3, m["valor_hora"].toDouble());
        row++;
    }

    // 3. Secciones
    xlsx.addSheet("Secciones");
    xlsx.selectSheet("Secciones");
    xlsx.write(1, 1, "id");
    xlsx.write(1, 2, "codigo");
    xlsx.write(1, 3, "titulo");
    auto sections = m_db->listSections();
    row = 2;
    for (const auto &s : sections) {
        auto m = s.toMap();
        xlsx.write(row, 1, m["id"].toInt());
        xlsx.write(row, 2, m["codigo"].toString());
        xlsx.write(row, 3, m["titulo"].toString());
        row++;
    }

    // 4. Empleados (basic columns, no j_ dynamic vars for now since we use relational schema_fields)
    xlsx.addSheet("Empleados");
    xlsx.selectSheet("Empleados");
    xlsx.write(1, 1, "id");
    xlsx.write(1, 2, "legajo");
    xlsx.write(1, 3, "nombre_completo");
    xlsx.write(1, 4, "tipo_liquidacion");
    xlsx.write(1, 5, "esquema_codigo");
    xlsx.write(1, 6, "categoria_jornal_id");
    xlsx.write(1, 7, "fecha_ingreso");
    xlsx.write(1, 8, "cuil");
    auto emps = m_db->listEmployees();
    row = 2;
    for (const auto &e : emps) {
        auto m = e.toMap();
        xlsx.write(row, 1, m["id"].toInt());
        xlsx.write(row, 2, m["legajo"].toString());
        xlsx.write(row, 3, m["nombre_completo"].toString());
        xlsx.write(row, 4, m["tipo_liquidacion"].toString());
        xlsx.write(row, 5, m["esquema_codigo"].toString());
        xlsx.write(row, 6, m["categoria_jornal_id"].toInt());
        xlsx.write(row, 7, m["fecha_ingreso"].toString());
        xlsx.write(row, 8, m["cuil"].toString());
        row++;
    }

    // 5. Celdas de Cálculo
    xlsx.addSheet("Celdas de Cálculo");
    xlsx.selectSheet("Celdas de Cálculo");
    QStringList cellHeaders = {"id", "seccion_codigo", "codigo_variable", "descripcion", "condicion",
                               "formula_unidad", "formula_base", "formula_monto", "orden", "esquema_codigo",
                               "tipo_calculo", "simple_porcentaje", "simple_base_variable", "simple_monto_fijo"};
    for (int i = 0; i < cellHeaders.size(); i++)
        xlsx.write(1, i + 1, cellHeaders[i]);
    auto cells = m_db->listAllCells();
    row = 2;
    for (const auto &c : cells) {
        auto m = c.toMap();
        xlsx.write(row, 1, m["id"].toInt());
        xlsx.write(row, 2, m["seccion_codigo"].toString());
        xlsx.write(row, 3, m["codigo_variable"].toString());
        xlsx.write(row, 4, m["descripcion"].toString());
        xlsx.write(row, 5, m["condicion"].toString());
        xlsx.write(row, 6, m["formula_unidad"].toString());
        xlsx.write(row, 7, m["formula_base"].toString());
        xlsx.write(row, 8, m["formula_monto"].toString());
        xlsx.write(row, 9, m["orden"].toInt());
        xlsx.write(row, 10, m["esquema_codigo"].toString());
        xlsx.write(row, 11, m["tipo_calculo"].toString());
        xlsx.write(row, 12, m["simple_porcentaje"].toDouble());
        xlsx.write(row, 13, m["simple_base_variable"].toString());
        xlsx.write(row, 14, m["simple_monto_fijo"].toDouble());
        row++;
    }

    // 6. Variables Globales
    xlsx.addSheet("Variables Globales");
    xlsx.selectSheet("Variables Globales");
    xlsx.write(1, 1, "id");
    xlsx.write(1, 2, "codigo");
    xlsx.write(1, 3, "valor");
    xlsx.write(1, 4, "descripcion");
    auto globals = m_db->listGlobalVariables();
    row = 2;
    for (const auto &g : globals) {
        auto m = g.toMap();
        xlsx.write(row, 1, m["id"].toInt());
        xlsx.write(row, 2, m["codigo"].toString());
        xlsx.write(row, 3, m["valor"].toString());
        xlsx.write(row, 4, m["descripcion"].toString());
        row++;
    }

    // 7. Empresa
    xlsx.addSheet("Empresa");
    xlsx.selectSheet("Empresa");
    xlsx.write(1, 1, "id");
    xlsx.write(1, 2, "razon_social");
    xlsx.write(1, 3, "direccion");
    xlsx.write(1, 4, "cuit");
    xlsx.write(1, 5, "lugar_de_pago");
    auto comp = m_db->getCompany();
    if (!comp.isEmpty()) {
        xlsx.write(2, 1, comp["id"].toInt());
        xlsx.write(2, 2, comp["razon_social"].toString());
        xlsx.write(2, 3, comp["direccion"].toString());
        xlsx.write(2, 4, comp["cuit"].toString());
        xlsx.write(2, 5, comp["lugar_pago"].toString());
    }

    // 8. Variables de Esquema (schema_fields)
    xlsx.addSheet("Variables de Esquema");
    xlsx.selectSheet("Variables de Esquema");
    xlsx.write(1, 1, "id");
    xlsx.write(1, 2, "esquema_codigo");
    xlsx.write(1, 3, "field_code");
    xlsx.write(1, 4, "field_label");
    xlsx.write(1, 5, "field_type");
    xlsx.write(1, 6, "default_value");
    xlsx.write(1, 7, "display_order");
    auto sFields = m_db->listAllSchemaFields();
    row = 2;
    for (const auto &sf : sFields) {
        auto m = sf.toMap();
        xlsx.write(row, 1, m["id"].toInt());
        xlsx.write(row, 2, m["esquema_codigo"].toString());
        xlsx.write(row, 3, m["field_code"].toString());
        xlsx.write(row, 4, m["field_label"].toString());
        xlsx.write(row, 5, m["field_type"].toString());
        xlsx.write(row, 6, m["default_value"].toString());
        xlsx.write(row, 7, m["display_order"].toInt());
        row++;
    }

    // 9. Quincenas Empleado
    xlsx.addSheet("Quincenas Empleado");
    xlsx.selectSheet("Quincenas Empleado");
    xlsx.write(1, 1, "empleado_id");
    xlsx.write(1, 2, "quincena");
    auto qEmps = m_db->listAllEmployeeQuincenas();
    row = 2;
    for (const auto &qe : qEmps) {
        auto m = qe.toMap();
        xlsx.write(row, 1, m["empleado_id"].toInt());
        xlsx.write(row, 2, m["quincena"].toString());
        row++;
    }

    // 10. Valores por Quincena (Valores Dinámicos Empleados: M para mensuales, Q1/Q2 para jornaleros)
    xlsx.addSheet("Valores por Quincena");
    xlsx.selectSheet("Valores por Quincena");

    // Collect all unique field_codes from schema_fields to build dynamic column headers
    auto sFieldsList = m_db->listAllSchemaFields();
    QStringList dynamicHeaders;
    for (const auto &sf : sFieldsList) {
        QString fCode = sf.toMap()["field_code"].toString().trimmed();
        if (!fCode.isEmpty() && !dynamicHeaders.contains(fCode)) {
            dynamicHeaders.append(fCode);
        }
    }

    xlsx.write(1, 1, "empleado_id");
    xlsx.write(1, 2, "legajo");
    xlsx.write(1, 3, "nombre_completo");
    xlsx.write(1, 4, "esquema_codigo");
    xlsx.write(1, 5, "quincena");
    for (int i = 0; i < dynamicHeaders.size(); i++) {
        xlsx.write(1, 6 + i, dynamicHeaders[i]);
    }

    row = 2;
    for (const auto &e : emps) {
        auto mEmp = e.toMap();
        int empId = mEmp["id"].toInt();
        QString legajo = mEmp["legajo"].toString();
        QString nombre = mEmp["nombre_completo"].toString();
        QString esquema = mEmp["esquema_codigo"].toString();
        QString tipoLiq = mEmp["tipo_liquidacion"].toString();

        QStringList periods;
        if (tipoLiq == "jornal") {
            periods = m_db->listEmployeeQuincenas(empId);
            if (periods.isEmpty()) periods = {"Q1", "Q2"};
        } else {
            periods = {"M"};
        }

        for (const QString &periodCode : periods) {
            QString dbQn = (periodCode == "M") ? "Q1" : periodCode;
            auto fValues = m_db->getEmployeeFieldValues(empId, dbQn);
            QMap<QString, QString> valMap;
            for (const auto &fv : fValues) {
                auto mVal = fv.toMap();
                valMap[mVal["field_code"].toString()] = mVal["value"].toString();
            }

            xlsx.write(row, 1, empId);
            xlsx.write(row, 2, legajo);
            xlsx.write(row, 3, nombre);
            xlsx.write(row, 4, esquema);
            xlsx.write(row, 5, periodCode);

            for (int i = 0; i < dynamicHeaders.size(); i++) {
                QString fCode = dynamicHeaders[i];
                xlsx.write(row, 6 + i, valMap.value(fCode, ""));
            }
            row++;
        }
    }

    // 11. Funciones Personalizadas
    xlsx.addSheet("Funciones Personalizadas");
    xlsx.selectSheet("Funciones Personalizadas");
    xlsx.write(1, 1, "id");
    xlsx.write(1, 2, "name");
    xlsx.write(1, 3, "params");
    xlsx.write(1, 4, "description");
    xlsx.write(1, 5, "body");
    auto cFuncs = m_db->listCustomFunctions();
    row = 2;
    for (const auto &fn : cFuncs) {
        auto m = fn.toMap();
        xlsx.write(row, 1, m["id"].toInt());
        xlsx.write(row, 2, m["name"].toString());
        xlsx.write(row, 3, m["params"].toString());
        xlsx.write(row, 4, m["description"].toString());
        xlsx.write(row, 5, m["body"].toString());
        row++;
    }

    if (xlsx.saveAs(filePath)) {
        qInfo() << "[ExportService] Exportación Excel exitosa:" << filePath;
        return filePath;
    }
    qWarning() << "[ExportService] Error al guardar archivo Excel.";
    return QString();
}

// ═══════════════════════════════════════════════════════════════════
// Excel Import
// ═══════════════════════════════════════════════════════════════════

bool ExportService::importDataXlsx(const QString &path)
{
    QString filePath = ensureXlsxPath(path);
    qInfo() << "[ExportService] Importando datos desde Excel:" << filePath;

    QXlsx::Document xlsx(filePath);
    if (!xlsx.load()) {
        qWarning() << "[ExportService] No se pudo abrir el archivo Excel:" << filePath;
        return false;
    }

    m_db->transaction();

    // Import Schemas
    if (xlsx.selectSheet("Esquemas de Cálculo")) {
        for (int r = 2; r <= xlsx.dimension().lastRow(); r++) {
            QString code = xlsx.read(r, 1).toString();
            QString name = xlsx.read(r, 2).toString();
            if (!code.isEmpty()) {
                m_db->saveSchema("", code, name, "mensual");
            }
        }
    }

    // Import Categories
    if (xlsx.selectSheet("Categorías Jornaleras")) {
        for (int r = 2; r <= xlsx.dimension().lastRow(); r++) {
            QString name = xlsx.read(r, 2).toString();
            double valor = xlsx.read(r, 3).toDouble();
            if (!name.isEmpty()) {
                m_db->saveCategory(0, name, valor);
            }
        }
    }

    // Import Employees
    if (xlsx.selectSheet("Empleados")) {
        for (int r = 2; r <= xlsx.dimension().lastRow(); r++) {
            int empId = xlsx.read(r, 1).toInt();
            QString legajo = xlsx.read(r, 2).toString();
            QString nombre = xlsx.read(r, 3).toString();
            QString tipoLiq = xlsx.read(r, 4).toString();
            QString esquema = xlsx.read(r, 5).toString();
            int catId = xlsx.read(r, 6).toInt();
            QString fechaIng = xlsx.read(r, 7).toString();
            QString cuil = xlsx.read(r, 8).toString();

            if (!nombre.isEmpty()) {
                m_db->saveEmployee(empId, legajo, nombre, tipoLiq, esquema, catId, fechaIng, cuil);
            }
        }
    }

    // Import Variables de Esquema
    if (xlsx.selectSheet("Variables de Esquema")) {
        for (int r = 2; r <= xlsx.dimension().lastRow(); r++) {
            QString esq = xlsx.read(r, 2).toString();
            QString code = xlsx.read(r, 3).toString();
            QString label = xlsx.read(r, 4).toString();
            QString type = xlsx.read(r, 5).toString();
            QString defVal = xlsx.read(r, 6).toString();
            int order = xlsx.read(r, 7).toInt();
            if (!esq.isEmpty() && !code.isEmpty()) {
                m_db->addSchemaField(esq, code, label, type.isEmpty() ? "number" : type, defVal, order);
            }
        }
    }

    // Import Celdas de Cálculo
    if (xlsx.selectSheet("Celdas de Cálculo")) {
        for (int r = 2; r <= xlsx.dimension().lastRow(); r++) {
            QString secCodigo = xlsx.read(r, 2).toString();
            QString codigoVar = xlsx.read(r, 3).toString();
            QString desc = xlsx.read(r, 4).toString();
            if (secCodigo.isEmpty() && desc.isEmpty() && codigoVar.isEmpty()) continue;

            m_db->saveCell(
                0,  // new
                secCodigo,
                codigoVar,
                desc,
                xlsx.read(r, 5).toString(),  // condicion
                xlsx.read(r, 6).toString(),  // formula_unidad
                xlsx.read(r, 7).toString(),  // formula_base
                xlsx.read(r, 8).toString(),  // formula_monto
                xlsx.read(r, 9).toInt(),     // orden
                xlsx.read(r, 10).toString(), // esquema_codigo
                xlsx.read(r, 11).toString(), // tipo_calculo
                xlsx.read(r, 12).toDouble(), // simple_porcentaje
                xlsx.read(r, 13).toString(), // simple_base_variable
                xlsx.read(r, 14).toDouble(), // simple_monto_fijo
                true                         // visible_recibo
            );
        }
    }

    // Import Variables Globales
    if (xlsx.selectSheet("Variables Globales")) {
        for (int r = 2; r <= xlsx.dimension().lastRow(); r++) {
            QString code = xlsx.read(r, 2).toString();
            if (!code.isEmpty()) {
                m_db->saveGlobalVariable(0, code, xlsx.read(r, 3).toString(), xlsx.read(r, 4).toString());
            }
        }
    }

    // Import Empresa
    if (xlsx.selectSheet("Empresa")) {
        int lastRow = xlsx.dimension().lastRow();
        if (lastRow >= 2) {
            m_db->saveCompany(
                xlsx.read(2, 2).toString(),
                xlsx.read(2, 3).toString(),
                xlsx.read(2, 4).toString(),
                xlsx.read(2, 5).toString()
            );
        }
    }

    // Import Quincenas Empleado
    if (xlsx.selectSheet("Quincenas Empleado")) {
        for (int r = 2; r <= xlsx.dimension().lastRow(); r++) {
            int empId = xlsx.read(r, 1).toInt();
            QString qn = xlsx.read(r, 2).toString();
            if (empId > 0 && !qn.isEmpty()) {
                m_db->addQuincena(empId, qn);
            }
        }
    }

    // Import Valores por Quincena (dynamic pivot sheet with M, Q1, Q2)
    if (xlsx.selectSheet("Valores por Quincena")) {
        int lastCol = xlsx.dimension().lastColumn();
        int lastRow = xlsx.dimension().lastRow();

        QMap<int, QString> colToFieldCode;
        for (int c = 6; c <= lastCol; c++) {
            QString hName = xlsx.read(1, c).toString().trimmed();
            if (!hName.isEmpty()) {
                colToFieldCode[c] = hName;
            }
        }

        for (int r = 2; r <= lastRow; r++) {
            int empId = xlsx.read(r, 1).toInt();
            QString legajo = xlsx.read(r, 2).toString().trimmed();
            QString nombre = xlsx.read(r, 3).toString().trimmed();
            QString qn = xlsx.read(r, 5).toString().trimmed();

            QString dbQn = (qn.isEmpty() || qn == "M") ? "Q1" : qn;

            // If empId is not found, try matching by legajo or nombre
            if (empId <= 0 || m_db->getEmployee(empId).isEmpty()) {
                for (const auto &eItem : m_db->listEmployees()) {
                    auto mE = eItem.toMap();
                    if ((!legajo.isEmpty() && mE["legajo"].toString().trimmed() == legajo) ||
                        (!nombre.isEmpty() && mE["nombre_completo"].toString().trimmed() == nombre)) {
                        empId = mE["id"].toInt();
                        break;
                    }
                }
            }

            if (empId > 0) {
                if (dbQn != "Q1") {
                    m_db->addQuincena(empId, dbQn);
                }
                QVariantMap fieldVals;
                for (auto it = colToFieldCode.begin(); it != colToFieldCode.end(); ++it) {
                    QString val = xlsx.read(r, it.key()).toString();
                    fieldVals[it.value()] = val;
                }
                m_db->setEmployeeFieldValues(empId, dbQn, fieldVals);
            }
        }
    }

    // Import Valores de Empleados (legacy ID-based format fallback)
    if (xlsx.selectSheet("Valores de Empleados")) {
        for (int r = 2; r <= xlsx.dimension().lastRow(); r++) {
            int empId = xlsx.read(r, 2).toInt();
            int fieldId = xlsx.read(r, 3).toInt();
            QString qn = xlsx.read(r, 4).toString();
            QString val = xlsx.read(r, 5).toString();
            if (empId > 0 && fieldId > 0) {
                m_db->setEmployeeFieldValue(empId, fieldId, qn, val);
            }
        }
    }

    // Import Funciones Personalizadas
    if (xlsx.selectSheet("Funciones Personalizadas")) {
        for (int r = 2; r <= xlsx.dimension().lastRow(); r++) {
            int funcId = xlsx.read(r, 1).toInt();
            QString name = xlsx.read(r, 2).toString();
            QString params = xlsx.read(r, 3).toString();
            QString desc = xlsx.read(r, 4).toString();
            QString body = xlsx.read(r, 5).toString();
            if (!name.isEmpty()) {
                m_db->saveCustomFunction(funcId, name, params, body, desc);
            }
        }
    }

    m_db->commit();
    qInfo() << "[ExportService] Importación Excel completada con éxito.";
    return true;
}

// ═══════════════════════════════════════════════════════════════════
// CSV Export
// ═══════════════════════════════════════════════════════════════════

static void writeCsvLine(QTextStream &ts, const QStringList &fields)
{
    for (int i = 0; i < fields.size(); i++) {
        if (i > 0) ts << ",";
        QString f = fields[i];
        if (f.contains(',') || f.contains('"') || f.contains('\n')) {
            f.replace("\"", "\"\"");
            ts << "\"" << f << "\"";
        } else {
            ts << f;
        }
    }
    ts << "\n";
}

QString ExportService::exportDataCsv(const QString &directoryPath)
{
    QString dir = ensureCsvDir(directoryPath);
    qInfo() << "[ExportService] Exportando datos a CSV en:" << dir;

    // Schemas
    {
        QFile f(dir + "/esquemas_calculo.csv");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            writeCsvLine(ts, {"codigo", "nombre"});
            for (const auto &s : m_db->listSchemas()) {
                auto m = s.toMap();
                writeCsvLine(ts, {m["codigo"].toString(), m["nombre"].toString()});
            }
        }
    }

    // Categories
    {
        QFile f(dir + "/categorias_jornal.csv");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            writeCsvLine(ts, {"id", "nombre", "valor_hora"});
            for (const auto &c : m_db->listCategories()) {
                auto m = c.toMap();
                writeCsvLine(ts, {m["id"].toString(), m["nombre"].toString(), m["valor_hora"].toString()});
            }
        }
    }

    // Celdas
    {
        QFile f(dir + "/celdas_calculo.csv");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            writeCsvLine(ts, {"id", "seccion_codigo", "codigo_variable", "descripcion", "condicion",
                              "formula_unidad", "formula_base", "formula_monto", "orden", "esquema_codigo",
                              "tipo_calculo", "simple_porcentaje", "simple_base_variable", "simple_monto_fijo"});
            for (const auto &c : m_db->listAllCells()) {
                auto m = c.toMap();
                writeCsvLine(ts, {
                    m["id"].toString(), m["seccion_codigo"].toString(), m["codigo_variable"].toString(),
                    m["descripcion"].toString(), m["condicion"].toString(), m["formula_unidad"].toString(),
                    m["formula_base"].toString(), m["formula_monto"].toString(), m["orden"].toString(),
                    m["esquema_codigo"].toString(), m["tipo_calculo"].toString(), m["simple_porcentaje"].toString(),
                    m["simple_base_variable"].toString(), m["simple_monto_fijo"].toString()
                });
            }
        }
    }

    // Global Variables
    {
        QFile f(dir + "/variables_globales.csv");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            writeCsvLine(ts, {"id", "codigo", "valor", "descripcion"});
            for (const auto &g : m_db->listGlobalVariables()) {
                auto m = g.toMap();
                writeCsvLine(ts, {m["id"].toString(), m["codigo"].toString(), m["valor"].toString(), m["descripcion"].toString()});
            }
        }
    }

    // Schema Fields
    {
        QFile f(dir + "/schema_fields.csv");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            writeCsvLine(ts, {"id", "esquema_codigo", "field_code", "field_label", "field_type", "default_value", "display_order"});
            for (const auto &sf : m_db->listAllSchemaFields()) {
                auto m = sf.toMap();
                writeCsvLine(ts, {m["id"].toString(), m["esquema_codigo"].toString(), m["field_code"].toString(),
                                  m["field_label"].toString(), m["field_type"].toString(), m["default_value"].toString(),
                                  m["display_order"].toString()});
            }
        }
    }

    // Quincenas Empleados
    {
        QFile f(dir + "/quincenas_empleado.csv");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            writeCsvLine(ts, {"empleado_id", "quincena"});
            for (const auto &qe : m_db->listAllEmployeeQuincenas()) {
                auto m = qe.toMap();
                writeCsvLine(ts, {m["empleado_id"].toString(), m["quincena"].toString()});
            }
        }
    }

    // Employee Field Values (raw DB dump)
    {
        QFile f(dir + "/employee_field_values.csv");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            writeCsvLine(ts, {"id", "empleado_id", "field_id", "quincena", "value"});
            for (const auto &ev : m_db->listAllEmployeeFieldValues()) {
                auto m = ev.toMap();
                writeCsvLine(ts, {m["id"].toString(), m["empleado_id"].toString(), m["field_id"].toString(),
                                  m["quincena"].toString(), m["value"].toString()});
            }
        }
    }

    // Valores por Quincenas Empleados (Human-friendly dynamic CSV table)
    {
        QFile f(dir + "/valores_quincenas_empleados.csv");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream ts(&f);

            auto sFieldsList = m_db->listAllSchemaFields();
            QStringList dynamicHeaders;
            for (const auto &sf : sFieldsList) {
                QString fCode = sf.toMap()["field_code"].toString().trimmed();
                if (!fCode.isEmpty() && !dynamicHeaders.contains(fCode)) {
                    dynamicHeaders.append(fCode);
                }
            }

            QStringList headers = {"empleado_id", "legajo", "nombre_completo", "esquema_codigo", "quincena"};
            headers.append(dynamicHeaders);
            writeCsvLine(ts, headers);

            for (const auto &e : m_db->listEmployees()) {
                auto mEmp = e.toMap();
                int empId = mEmp["id"].toInt();
                QString legajo = mEmp["legajo"].toString();
                QString nombre = mEmp["nombre_completo"].toString();
                QString esquema = mEmp["esquema_codigo"].toString();
                QString tipoLiq = mEmp["tipo_liquidacion"].toString();

                QStringList periods;
                if (tipoLiq == "jornal") {
                    periods = m_db->listEmployeeQuincenas(empId);
                    if (periods.isEmpty()) periods = {"Q1", "Q2"};
                } else {
                    periods = {"M"};
                }

                for (const QString &periodCode : periods) {
                    QString dbQn = (periodCode == "M") ? "Q1" : periodCode;
                    auto fValues = m_db->getEmployeeFieldValues(empId, dbQn);
                    QMap<QString, QString> valMap;
                    for (const auto &fv : fValues) {
                        auto mVal = fv.toMap();
                        valMap[mVal["field_code"].toString()] = mVal["value"].toString();
                    }

                    QStringList rowFields = {QString::number(empId), legajo, nombre, esquema, periodCode};
                    for (const QString &fCode : dynamicHeaders) {
                        rowFields.append(valMap.value(fCode, ""));
                    }
                    writeCsvLine(ts, rowFields);
                }
            }
        }
    }

    // Funciones Personalizadas
    {
        QFile f(dir + "/funciones_personalizadas.csv");
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            writeCsvLine(ts, {"id", "name", "params", "description", "body"});
            for (const auto &fn : m_db->listCustomFunctions()) {
                auto m = fn.toMap();
                writeCsvLine(ts, {m["id"].toString(), m["name"].toString(), m["params"].toString(), m["description"].toString(), m["body"].toString()});
            }
        }
    }

    qInfo() << "[ExportService] Exportación CSV completada en:" << dir;
    return dir;
}

bool ExportService::importDataCsv(const QString &directoryPath)
{
    QString dir = ensureCsvDir(directoryPath);
    qInfo() << "[ExportService] Importando datos desde CSV en:" << dir;

    m_db->transaction();

    // Helper to parse a CSV line split by comma respecting quotes
    auto parseCsvLine = [](const QString &line) -> QStringList {
        QStringList result;
        QString cur;
        bool inQuotes = false;
        for (int i = 0; i < line.length(); i++) {
            QChar c = line[i];
            if (c == '"') {
                inQuotes = !inQuotes;
            } else if (c == ',' && !inQuotes) {
                result.append(cur.trimmed());
                cur.clear();
            } else {
                cur.append(c);
            }
        }
        result.append(cur.trimmed());
        return result;
    };

    // Import Schemas CSV
    {
        QFile f(dir + "/esquemas_calculo.csv");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            ts.readLine(); // skip header
            while (!ts.atEnd()) {
                QString line = ts.readLine();
                if (line.trimmed().isEmpty()) continue;
                QStringList parts = parseCsvLine(line);
                if (parts.size() >= 2) {
                    m_db->saveSchema("", parts[0], parts[1], "mensual");
                }
            }
        }
    }

    // Import Categories CSV
    {
        QFile f(dir + "/categorias_jornal.csv");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            ts.readLine();
            while (!ts.atEnd()) {
                QString line = ts.readLine();
                if (line.trimmed().isEmpty()) continue;
                QStringList parts = parseCsvLine(line);
                if (parts.size() >= 3) {
                    m_db->saveCategory(parts[0].toInt(), parts[1], parts[2].toDouble());
                }
            }
        }
    }

    // Import Schema Fields CSV
    {
        QFile f(dir + "/schema_fields.csv");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            ts.readLine();
            while (!ts.atEnd()) {
                QString line = ts.readLine();
                if (line.trimmed().isEmpty()) continue;
                QStringList parts = parseCsvLine(line);
                if (parts.size() >= 7) {
                    m_db->addSchemaField(parts[1], parts[2], parts[3], parts[4], parts[5], parts[6].toInt());
                }
            }
        }
    }

    // Import Quincenas Empleado CSV
    {
        QFile f(dir + "/quincenas_empleado.csv");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            ts.readLine();
            while (!ts.atEnd()) {
                QString line = ts.readLine();
                if (line.trimmed().isEmpty()) continue;
                QStringList parts = parseCsvLine(line);
                if (parts.size() >= 2) {
                    int empId = parts[0].toInt();
                    QString qn = parts[1];
                    if (empId > 0 && !qn.isEmpty()) {
                        m_db->addQuincena(empId, qn);
                    }
                }
            }
        }
    }

    // Import Valores por Quincenas Empleados CSV
    {
        QFile f(dir + "/valores_quincenas_empleados.csv");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            QString headerLine = ts.readLine();
            QStringList headers = parseCsvLine(headerLine);

            QMap<int, QString> colToFieldCode;
            for (int i = 5; i < headers.size(); i++) {
                QString fCode = headers[i].trimmed();
                if (!fCode.isEmpty()) {
                    colToFieldCode[i] = fCode;
                }
            }

            while (!ts.atEnd()) {
                QString line = ts.readLine();
                if (line.trimmed().isEmpty()) continue;
                QStringList parts = parseCsvLine(line);
                if (parts.size() >= 5) {
                    int empId = parts[0].toInt();
                    QString legajo = parts[1];
                    QString nombre = parts[2];
                    QString qn = parts[4];

                    QString dbQn = (qn.isEmpty() || qn == "M") ? "Q1" : qn;

                    if (empId <= 0 || m_db->getEmployee(empId).isEmpty()) {
                        for (const auto &eItem : m_db->listEmployees()) {
                            auto mE = eItem.toMap();
                            if ((!legajo.isEmpty() && mE["legajo"].toString().trimmed() == legajo) ||
                                (!nombre.isEmpty() && mE["nombre_completo"].toString().trimmed() == nombre)) {
                                empId = mE["id"].toInt();
                                break;
                            }
                        }
                    }

                    if (empId > 0) {
                        if (dbQn != "Q1") {
                            m_db->addQuincena(empId, dbQn);
                        }
                        QVariantMap fieldVals;
                        for (auto it = colToFieldCode.begin(); it != colToFieldCode.end(); ++it) {
                            int idx = it.key();
                            if (idx < parts.size()) {
                                fieldVals[it.value()] = parts[idx];
                            }
                        }
                        m_db->setEmployeeFieldValues(empId, dbQn, fieldVals);
                    }
                }
            }
        }
    }

    // Import Funciones Personalizadas CSV
    {
        QFile f(dir + "/funciones_personalizadas.csv");
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream ts(&f);
            QString header = ts.readLine(); // Header
            while (!ts.atEnd()) {
                QString line = ts.readLine();
                if (line.trimmed().isEmpty()) continue;
                QStringList parts = parseCsvLine(line);
                if (parts.size() >= 5) {
                    int funcId = parts[0].toInt();
                    QString name = parts[1];
                    QString params = parts[2];
                    QString desc = parts[3];
                    QString body = parts[4];
                    if (!name.isEmpty()) {
                        m_db->saveCustomFunction(funcId, name, params, body, desc);
                    }
                }
            }
        }
    }

    m_db->commit();
    qInfo() << "[ExportService] Importación CSV completada en:" << dir;
    return true;
}

// ═══════════════════════════════════════════════════════════════════
// PDF Receipt Export
// ═══════════════════════════════════════════════════════════════════

QString ExportService::exportReceiptPdf(const QVariantMap &liquidationResult,
                                        const QVariantMap &companyData,
                                        const QVariantMap &employeeData,
                                        const QString &path)
{
    QString filePath = ensurePdfPath(path);
    qInfo() << "[ExportService] Generando recibo PDF:" << filePath;

    QPdfWriter writer(filePath);
    writer.setPageSize(QPageSize::A4);
    writer.setPageMargins(QMarginsF(8, 8, 8, 8), QPageLayout::Millimeter);
    writer.setResolution(300);

    QPainter painter(&writer);
    if (!painter.isActive()) {
        qWarning() << "[ExportService] No se pudo iniciar QPainter para PDF.";
        return QString();
    }

    int pageW = writer.width();
    int y = 0;

    // ── Helper lambdas ──────────────────────────────────────────
    auto drawLine = [&](int y1) {
        painter.setPen(QPen(QColor(148, 163, 184), 1.5));
        painter.drawLine(0, y1, pageW, y1);
        painter.setPen(QPen(Qt::black, 1));
    };

    auto fmtNum = [](double val, int maxDecimals = 4) -> QString {
        QString s = QString::number(val, 'f', maxDecimals);
        if (s.contains('.')) {
            while (s.endsWith('0')) s.chop(1);
            if (s.endsWith('.')) s.chop(1);
        }
        return s.replace('.', ',');
    };

    auto fmtMoney = [](double val, int maxDecimals = 4) -> QString {
        QString s = QString::number(val, 'f', maxDecimals);
        if (s.contains('.')) {
            while (s.endsWith('0') && s.length() - s.indexOf('.') > 3) s.chop(1);
        }
        return s.replace('.', ',');
    };

    QFont titleFont("Helvetica", 13, QFont::Bold);
    QFont headerFont("Helvetica", 9.5, QFont::Bold);
    QFont normalFont("Helvetica", 8.5);
    QFont smallFont("Helvetica", 7.5);

    // Priorizar datos históricos de empresa y empleado encapsulados en el snapshot
    QVariantMap effectiveCompany = companyData;
    if (liquidationResult.contains("empresa") && liquidationResult.value("empresa").canConvert<QVariantMap>()) {
        QVariantMap snapComp = liquidationResult.value("empresa").toMap();
        if (!snapComp.isEmpty() && !snapComp.value("razon_social").toString().isEmpty()) {
            effectiveCompany = snapComp;
        }
    }

    QVariantMap effectiveEmployee = employeeData;
    if (liquidationResult.contains("empleado") && liquidationResult.value("empleado").canConvert<QVariantMap>()) {
        QVariantMap snapEmp = liquidationResult.value("empleado").toMap();
        if (!snapEmp.isEmpty() && !snapEmp.value("nombre_completo").toString().isEmpty()) {
            effectiveEmployee = snapEmp;
        }
    }

    // ── Company Header ──────────────────────────────────────────
    painter.setFont(titleFont);
    painter.setPen(QPen(Qt::black));
    QString razonSocial = effectiveCompany.value("razon_social", "EMPRESA").toString();
    painter.drawText(QRect(0, y, pageW, 70), Qt::AlignLeft | Qt::AlignVCenter, razonSocial);
    y += 75;

    painter.setFont(smallFont);
    painter.setPen(QPen(Qt::black));
    painter.drawText(QRect(0, y, pageW / 2, 40), Qt::AlignLeft,
                     "CUIT: " + effectiveCompany.value("cuit", "").toString());
    painter.drawText(QRect(pageW / 2, y, pageW / 2, 40), Qt::AlignRight,
                     "Dirección: " + effectiveCompany.value("direccion", "").toString());
    y += 45;
    drawLine(y);
    y += 12;

    // ── Employee & Period Header ────────────────────────────────
    painter.setFont(headerFont);
    painter.setPen(QPen(Qt::black));
    painter.drawText(QRect(0, y, pageW / 2, 40), Qt::AlignLeft | Qt::AlignVCenter, "RECIBO DE SUELDO");

    // Format Fecha de Cierre
    QString rawCierre = liquidationResult.value("FECHA_CIERRE", liquidationResult.value("fecha_cierre")).toString();
    if (rawCierre.isEmpty()) {
        rawCierre = liquidationResult.value("FECHA_CALCULO", liquidationResult.value("fecha_calculo")).toString();
    }
    QString fechaCierreStr = rawCierre;
    QDate dCierre = QDate::fromString(rawCierre, "yyyy-MM-dd");
    if (dCierre.isValid()) fechaCierreStr = dCierre.toString("dd/MM/yyyy");

    // Format Fecha de Pago
    QString rawPago = liquidationResult.value("FECHA_PAGO", liquidationResult.value("fecha_pago")).toString();
    if (rawPago.isEmpty()) {
        rawPago = liquidationResult.value("FECHA_CALCULO", liquidationResult.value("fecha_calculo")).toString();
    }
    QString fechaPagoStr = rawPago;
    QDate dPago = QDate::fromString(rawPago, "yyyy-MM-dd");
    if (dPago.isValid()) fechaPagoStr = dPago.toString("dd/MM/yyyy");
    else if (rawPago.isEmpty()) fechaPagoStr = QDate::currentDate().toString("dd/MM/yyyy");

    painter.drawText(QRect(pageW / 2, y, pageW / 2, 40), Qt::AlignRight | Qt::AlignVCenter,
                     "Fecha de Cierre: " + fechaCierreStr + "   |   Fecha de Pago: " + fechaPagoStr);
    y += 45;

    painter.setFont(normalFont);
    painter.setPen(QPen(Qt::black));
    QString empName = effectiveEmployee.value("nombre_completo", "Empleado").toString();
    QString empLegajo = effectiveEmployee.value("legajo", "").toString();
    QString empCuil = effectiveEmployee.value("cuil", "").toString();
    painter.drawText(QRect(0, y, pageW * 0.6, 32), Qt::AlignLeft, "Empleado: " + empName);
    painter.drawText(QRect(pageW * 0.6, y, pageW * 0.4, 32), Qt::AlignRight,
                     "Legajo: " + empLegajo + (!empCuil.isEmpty() ? ("   CUIL: " + empCuil) : ""));
    y += 34;

    QString tipoLiq = effectiveEmployee.value("tipo_liquidacion", "mensual").toString().toLower();
    QString categoriaNombre = effectiveEmployee.value("categoria_nombre", liquidationResult.value("categoria_nombre")).toString();
    double valorHora = liquidationResult.value("valor_hora", effectiveEmployee.value("valor_hora", 0.0)).toDouble();

    QString fechaIngresoStr = effectiveEmployee.value("fecha_ingreso", "").toString();
    QDate dIng = QDate::fromString(fechaIngresoStr, "yyyy-MM-dd");
    if (dIng.isValid()) fechaIngresoStr = dIng.toString("dd/MM/yyyy");

    int antiguedad = liquidationResult.value("antiguedad_anios",
                        liquidationResult.value("contexto_final").toMap().value("antiguedad_anios", 0)).toInt();

    QString tipoStr = (tipoLiq == "jornal") ? "Liquidación: Jornal" : "Liquidación: Mensual";
    if (tipoLiq == "jornal" && !categoriaNombre.isEmpty()) {
        tipoStr += "  |  Categoría: " + categoriaNombre;
    }
    painter.drawText(QRect(0, y, pageW * 0.6, 32), Qt::AlignLeft, tipoStr);

    QString rightDetails;
    if (tipoLiq == "jornal" && valorHora > 0) {
        rightDetails += "Valor/Hora: $ " + fmtMoney(valorHora, 2) + "   ";
    }
    if (!fechaIngresoStr.isEmpty()) {
        rightDetails += "Ingreso: " + fechaIngresoStr + " (" + QString::number(antiguedad) + " a.)";
    }
    if (!rightDetails.isEmpty()) {
        painter.drawText(QRect(pageW * 0.4, y, pageW * 0.6, 32), Qt::AlignRight, rightDetails);
    }
    y += 36;

    drawLine(y);
    y += 12;

    // ── Concept Lines ───────────────────────────────────────────
    painter.setFont(headerFont);
    painter.setPen(QPen(Qt::black));
    int colDesc = 0;
    int colUnit = pageW * 0.55;
    int colBase = pageW * 0.67;
    int colMonto = pageW * 0.81;

    painter.drawText(QRect(colDesc, y, colUnit - colDesc, 40), Qt::AlignLeft, "Concepto");
    painter.drawText(QRect(colUnit, y, colBase - colUnit, 40), Qt::AlignRight, "Unidad");
    painter.drawText(QRect(colBase, y, colMonto - colBase, 40), Qt::AlignRight, "Base");
    painter.drawText(QRect(colMonto, y, pageW - colMonto, 40), Qt::AlignRight, "Monto ($)");
    y += 45;
    drawLine(y);
    y += 8;

    painter.setFont(normalFont);
    QVariantList conceptos = liquidationResult.value("conceptos").toList();
    for (const auto &concepto : conceptos) {
        auto c = concepto.toMap();
        QVariant visVal = c.value("visible_recibo");
        bool isVisibleInReceipt = visVal.isValid() ? (visVal.toInt() != 0 && visVal.toBool()) : true;
        if (!isVisibleInReceipt) continue;

        QString desc = c["descripcion"].toString();
        QString seccion = c["seccion"].toString().toUpper();
        QString tipoCalc = c["tipo_calculo"].toString();
        QString codigo = c["codigo"].toString();
        double monto = c["monto"].toDouble();
        double unidad = c["unidad"].toDouble();
        double base = c["base"].toDouble();

        bool isSeparator = (tipoCalc == "separator" || codigo.startsWith("SEP_"));
        bool isTotal = (!isSeparator && (codigo.startsWith("TOT_") || codigo.startsWith("TOTAL_") || codigo.startsWith("NETO") || desc.toUpper().contains("TOTAL") || desc.toUpper().contains("NETO")));

        if (isSeparator) {
            y += 4;
            QRect sepRect(0, y, pageW, 36);
            painter.fillRect(sepRect, QColor(234, 242, 253));
            painter.setPen(QPen(QColor(59, 130, 246), 1));
            painter.drawRect(sepRect);

            QFont sepFont("Helvetica", 8.5, QFont::Bold);
            painter.setFont(sepFont);
            painter.setPen(QPen(QColor(15, 23, 42)));
            painter.drawText(QRect(8, y, pageW - 16, 36), Qt::AlignLeft | Qt::AlignVCenter, "■  " + desc.toUpper());

            painter.setFont(normalFont);
            painter.setPen(QPen(Qt::black));
            y += 42;
        } else {
            if (isTotal) {
                y += 2;
                QRect totalRect(0, y, pageW, 36);
                painter.fillRect(totalRect, QColor(234, 242, 253));
                painter.setPen(QPen(QColor(59, 130, 246), 1));
                painter.drawRect(totalRect);

                QFont boldFont("Helvetica", 8.5, QFont::Bold);
                painter.setFont(boldFont);
                painter.setPen(QPen(QColor(15, 23, 42)));
            } else {
                painter.setPen(QPen(Qt::black));
            }

            painter.drawText(QRect(colDesc + (isTotal ? 6 : 0), y, colUnit - colDesc - 10, 32), Qt::AlignLeft | Qt::AlignVCenter, desc);

            QString tc = c["tipo_calculo"].toString().toLower();
            double sPct = c["simple_porcentaje"].toDouble();
            QString sBaseVar = c["simple_base_variable"].toString();
            bool isPct = (tc == "porcentaje" || tc == "percentage" || tc == "simple" || sPct > 0);

            if (isPct && unidad > 0) {
                painter.drawText(QRect(colUnit, y, colBase - colUnit - 10, 32), Qt::AlignRight | Qt::AlignVCenter, "% " + fmtNum(unidad, 2));
            } else if (isPct && sPct > 0) {
                painter.drawText(QRect(colUnit, y, colBase - colUnit - 10, 32), Qt::AlignRight | Qt::AlignVCenter, "% " + fmtNum(sPct, 2));
            } else if (unidad != 0) {
                painter.drawText(QRect(colUnit, y, colBase - colUnit - 10, 32), Qt::AlignRight | Qt::AlignVCenter, fmtNum(unidad, 4));
            }

            if (!isSeparator && !isTotal && base > 0) {
                painter.drawText(QRect(colBase, y, colMonto - colBase - 10, 32), Qt::AlignRight | Qt::AlignVCenter, fmtMoney(base, 2));
            }

            if (monto != 0) {
                painter.drawText(QRect(colMonto - (isTotal ? 6 : 0), y, pageW - colMonto, 32), Qt::AlignRight | Qt::AlignVCenter,
                                 fmtMoney(monto, 4));
            }

            if (isTotal) {
                painter.setFont(normalFont);
                painter.setPen(QPen(Qt::black));
            }
            y += isTotal ? 42 : 34;
        }
    }

    // ── Vector Pie Chart PDF Rendering (Drawn once at the bottom) ──
    struct ChartSlice {
        QString label;
        double value;
        QColor color;
    };
        QList<ChartSlice> chartSlices;
        double refTotal = 0.0;

        static const QList<QColor> chartColors = {
            QColor(116, 199, 236), QColor(166, 227, 161), QColor(250, 179, 135),
            QColor(243, 139, 168), QColor(203, 166, 247), QColor(137, 180, 250),
            QColor(249, 226, 175), QColor(148, 226, 213)
        };

        // Cache schema cell definitions in case historical snapshot omitted chart flags
        QMap<int, QVariantMap> dbCellsById;
        QMap<QString, QVariantMap> dbCellsByCode;
        if (m_db) {
            QString esqCode = effectiveEmployee.value("esquema_codigo", "MENSUAL").toString();
            QVariantList schemaCells = m_db->listCellsBySchema(esqCode);
            for (const auto &scVar : schemaCells) {
                QVariantMap scMap = scVar.toMap();
                int scId = scMap.value("id", 0).toInt();
                QString scCode = scMap.value("codigo_variable").toString();
                if (scId > 0) dbCellsById[scId] = scMap;
                if (!scCode.isEmpty()) dbCellsByCode[scCode] = scMap;
            }
        }

        int colorIdx = 0;
        for (const auto &cVar : conceptos) {
            QVariantMap cMap = cVar.toMap();
            int cId = cMap.value("cell_id", 0).toInt();
            QString cCode = cMap.value("codigo", cMap.value("codigo_variable", "")).toString();

            bool hasChartMetadata = cMap.contains("en_grafico");
            bool inChart = cMap.value("en_grafico").toBool() || cMap.value("en_grafico").toInt() == 1;
            bool isTotalRef = cMap.value("es_grafico_total").toBool() || cMap.value("es_grafico_total").toInt() == 1;
            QString colHex = cMap.value("color_hex").toString();

            if (!hasChartMetadata) {
                QVariantMap fallbackCell;
                if (cId > 0 && dbCellsById.contains(cId)) fallbackCell = dbCellsById[cId];
                else if (!cCode.isEmpty() && dbCellsByCode.contains(cCode)) fallbackCell = dbCellsByCode[cCode];

                if (!fallbackCell.isEmpty()) {
                    inChart = fallbackCell.value("en_grafico").toInt() == 1;
                    isTotalRef = fallbackCell.value("es_grafico_total").toInt() == 1;
                    colHex = fallbackCell.value("color_hex").toString();
                }
            }

            double mVal = std::abs(cMap.value("monto").toDouble());

            if (isTotalRef && mVal > 0) {
                refTotal = mVal;
            }
            if (inChart && mVal > 0) {
                QColor sColor = colHex.isEmpty() ? chartColors[colorIdx % chartColors.size()] : QColor(colHex);
                colorIdx++;
                chartSlices.append({cMap.value("descripcion").toString(), mVal, sColor});
            }
        }

        if (!chartSlices.isEmpty()) {
            y += 15;
            // Title Header Bar
            int headerH = 26;
            QRect chartHeaderRect(0, y, pageW, headerH);
            painter.fillRect(chartHeaderRect, QColor(241, 245, 249));
            painter.setPen(QPen(QColor(203, 213, 225), 1));
            painter.setBrush(Qt::NoBrush);
            painter.drawRect(chartHeaderRect);

            QFont titleFont("Helvetica", 9, QFont::Bold);
            painter.setFont(titleFont);
            painter.setPen(QPen(QColor(15, 23, 42)));
            painter.setBrush(Qt::NoBrush);
            painter.drawText(chartHeaderRect.adjusted(12, 0, -12, 0), Qt::AlignLeft | Qt::AlignVCenter, "DISTRIBUCION Y ANALISIS DEL RECIBO");
            y += headerH + 18;

            double sumVal = 0;
            for (const auto &sl : chartSlices) sumVal += sl.value;
            double baseTotal = (refTotal > 0) ? refTotal : (sumVal > 0 ? sumVal : 1.0);

            int pieDiameter = qRound(pageW * 0.18);
            int pieX = qRound(pageW * 0.04);
            int pieY = y;

            // Draw pie slices vectorially
            int startAngle = 90 * 16;
            for (const auto &sl : chartSlices) {
                int spanAngle = -qRound((sl.value / baseTotal) * 360.0 * 16.0);
                painter.setBrush(QBrush(sl.color));
                painter.setPen(QPen(Qt::white, 1.5));
                painter.drawPie(pieX, pieY, pieDiameter, pieDiameter, startAngle, spanAngle);
                startAngle += spanAngle;
            }

            // Draw center donut circle for modern flat visual
            int innerD = qRound(pieDiameter * 0.45);
            int innerX = pieX + (pieDiameter - innerD) / 2;
            int innerY = pieY + (pieDiameter - innerD) / 2;
            painter.setBrush(QBrush(Qt::white));
            painter.setPen(QPen(QColor(226, 232, 240), 1));
            painter.drawEllipse(innerX, innerY, innerD, innerD);

            // Draw legend column to the right
            int legendX = pieX + pieDiameter + qRound(pageW * 0.06);
            int legendY = pieY;
            int legendW = pageW - legendX - 5;

            QFont legendFont("Helvetica", 8, QFont::Bold);
            painter.setFont(legendFont);

            int boxSize = 11;
            int lineH = 24;

            for (const auto &sl : chartSlices) {
                // Color box
                QRect boxRect(legendX, legendY + (lineH - boxSize) / 2, boxSize, boxSize);
                painter.fillRect(boxRect, sl.color);
                painter.setPen(QPen(QColor(148, 163, 184), 1));
                painter.setBrush(Qt::NoBrush);
                painter.drawRect(boxRect);

                // Label & percentage formatted nicely with spanish monetary style
                painter.setPen(QPen(Qt::black));
                painter.setBrush(Qt::NoBrush);
                double pct = (sl.value / baseTotal) * 100.0;
                QString lineText = QString("%1:  $ %2  (%3%)")
                                   .arg(sl.label)
                                   .arg(fmtMoney(sl.value, 2))
                                   .arg(QString::number(pct, 'f', 1));
                painter.drawText(QRect(legendX + boxSize + 12, legendY, legendW - boxSize - 12, lineH), Qt::AlignLeft | Qt::AlignVCenter, lineText);
                legendY += lineH + 4;
            }

            y = std::max(pieY + pieDiameter + 15, legendY + 10);
        }

    // ── Signatures Block (Empleador y Trabajador) ─────────────────
    int pageH = writer.height();
    int sigWidth = qRound(pageW * 0.36);
    int sigLeftX = qRound(pageW * 0.06);
    int sigRightX = pageW - sigLeftX - sigWidth;

    // Posicionar la firma asegurando que esté en la parte inferior de la página A4
    int sigLineY = qMax(y + 50, pageH - 90);

    painter.setPen(QPen(QColor(15, 23, 42), 1.5));
    painter.drawLine(sigLeftX, sigLineY, sigLeftX + sigWidth, sigLineY);
    painter.drawLine(sigRightX, sigLineY, sigRightX + sigWidth, sigLineY);

    QFont sigFont("Helvetica", 9, QFont::Bold);
    painter.setFont(sigFont);
    painter.setPen(QPen(QColor(15, 23, 42)));
    painter.setBrush(Qt::NoBrush);

    painter.drawText(QRect(sigLeftX, sigLineY + 8, sigWidth, 30), Qt::AlignCenter, "Firma del Empleador");
    painter.drawText(QRect(sigRightX, sigLineY + 8, sigWidth, 30), Qt::AlignCenter, "Firma del Trabajador");

    painter.end();

    qInfo() << "[ExportService] Recibo PDF generado exitosamente:" << filePath;
    return filePath;
}
