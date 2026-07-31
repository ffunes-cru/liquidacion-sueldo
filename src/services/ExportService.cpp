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
#include <QPainter>
#include <QPdfWriter>
#include <QSqlQuery>
#include <QTextStream>

#include "xlsxdocument.h"

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

    // 10. Valores de Empleados (employee_field_values)
    xlsx.addSheet("Valores de Empleados");
    xlsx.selectSheet("Valores de Empleados");
    xlsx.write(1, 1, "id");
    xlsx.write(1, 2, "empleado_id");
    xlsx.write(1, 3, "field_id");
    xlsx.write(1, 4, "quincena");
    xlsx.write(1, 5, "value");
    auto efVals = m_db->listAllEmployeeFieldValues();
    row = 2;
    for (const auto &ev : efVals) {
        auto m = ev.toMap();
        xlsx.write(row, 1, m["id"].toInt());
        xlsx.write(row, 2, m["empleado_id"].toInt());
        xlsx.write(row, 3, m["field_id"].toInt());
        xlsx.write(row, 4, m["quincena"].toString());
        xlsx.write(row, 5, m["value"].toString());
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
            QString codigoVar = xlsx.read(r, 3).toString();
            if (codigoVar.isEmpty()) continue;

            m_db->saveCell(
                0,  // new
                xlsx.read(r, 2).toString(),  // seccion_codigo
                codigoVar,
                xlsx.read(r, 4).toString(),  // descripcion
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

    // Import Valores de Empleados
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

    qInfo() << "[ExportService] Importación Excel completada.";
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

    // Employee Field Values
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

    qInfo() << "[ExportService] Exportación CSV completada en:" << dir;
    return dir;
}

bool ExportService::importDataCsv(const QString &directoryPath)
{
    // TODO: implement CSV import if needed
    Q_UNUSED(directoryPath)
    qInfo() << "[ExportService] Importación CSV no implementada aún.";
    return false;
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
    writer.setPageMargins(QMarginsF(15, 15, 15, 15), QPageLayout::Millimeter);
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
        painter.setPen(QPen(Qt::gray, 2));
        painter.drawLine(0, y1, pageW, y1);
    };

    QFont titleFont("Helvetica", 14, QFont::Bold);
    QFont headerFont("Helvetica", 10, QFont::Bold);
    QFont normalFont("Helvetica", 9);
    QFont smallFont("Helvetica", 8);

    // ── Company Header ──────────────────────────────────────────
    painter.setFont(titleFont);
    QString razonSocial = companyData.value("razon_social", "EMPRESA").toString();
    painter.drawText(QRect(0, y, pageW, 120), Qt::AlignLeft | Qt::AlignVCenter, razonSocial);
    y += 130;

    painter.setFont(smallFont);
    painter.drawText(QRect(0, y, pageW / 2, 60), Qt::AlignLeft,
                     "CUIT: " + companyData.value("cuit", "").toString());
    painter.drawText(QRect(pageW / 2, y, pageW / 2, 60), Qt::AlignRight,
                     "Dirección: " + companyData.value("direccion", "").toString());
    y += 70;
    drawLine(y);
    y += 20;

    // ── Employee Data ───────────────────────────────────────────
    painter.setFont(headerFont);
    painter.drawText(QRect(0, y, pageW, 80), Qt::AlignLeft, "RECIBO DE SUELDO");
    y += 90;

    painter.setFont(normalFont);
    QString empName = employeeData.value("nombre_completo", "Empleado").toString();
    QString empLegajo = employeeData.value("legajo", "").toString();
    painter.drawText(QRect(0, y, pageW / 2, 60), Qt::AlignLeft, "Empleado: " + empName);
    painter.drawText(QRect(pageW / 2, y, pageW / 2, 60), Qt::AlignRight, "Legajo: " + empLegajo);
    y += 70;
    drawLine(y);
    y += 20;

    // ── Concept Lines ───────────────────────────────────────────
    painter.setFont(headerFont);
    int colDesc = 0;
    int colUnit = pageW * 0.50;
    int colBase = pageW * 0.62;
    int colHab  = pageW * 0.76;
    int colDesc2 = pageW * 0.88;

    painter.drawText(QRect(colDesc, y, colUnit - colDesc, 60), Qt::AlignLeft, "Concepto");
    painter.drawText(QRect(colUnit, y, colBase - colUnit, 60), Qt::AlignRight, "Unidad");
    painter.drawText(QRect(colBase, y, colHab - colBase, 60), Qt::AlignRight, "Base");
    painter.drawText(QRect(colHab, y, colDesc2 - colHab, 60), Qt::AlignRight, "Haberes");
    painter.drawText(QRect(colDesc2, y, pageW - colDesc2, 60), Qt::AlignRight, "Descuentos");
    y += 70;
    drawLine(y);
    y += 10;

    painter.setFont(normalFont);
    QVariantList conceptos = liquidationResult.value("conceptos").toList();
    for (const auto &concepto : conceptos) {
        auto c = concepto.toMap();
        QString desc = c["descripcion"].toString();
        QString seccion = c["seccion"].toString();
        QString tipoCalc = c["tipo_calculo"].toString();
        QString codigo = c["codigo"].toString();
        double monto = c["monto"].toDouble();
        double unidad = c["unidad"].toDouble();
        double base = c["base"].toDouble();

        bool isSeparator = (tipoCalc == "separator" || codigo.startsWith("SEP_"));

        if (isSeparator) {
            y += 8;
            QRect sepRect(0, y, pageW, 55);
            painter.fillRect(sepRect, QColor(240, 243, 250)); // Light subtle tint background
            painter.setPen(QPen(QColor(180, 195, 220), 1));
            painter.drawRect(sepRect);

            QFont sepFont("Helvetica", 9, QFont::Bold);
            painter.setFont(sepFont);
            painter.setPen(QPen(QColor(30, 40, 70)));
            painter.drawText(QRect(15, y, pageW - 30, 55), Qt::AlignLeft | Qt::AlignVCenter, "■  " + desc.toUpper());

            painter.setFont(normalFont);
            painter.setPen(QPen(Qt::black));
            y += 65;
        } else {
            painter.drawText(QRect(colDesc, y, colUnit - colDesc - 10, 50), Qt::AlignLeft, desc);

            if (unidad != 0)
                painter.drawText(QRect(colUnit, y, colBase - colUnit - 10, 50), Qt::AlignRight,
                                 QString::number(unidad, 'f', 2));
            if (base > 0)
                painter.drawText(QRect(colBase, y, colHab - colBase - 10, 50), Qt::AlignRight,
                                 QString::number(base, 'f', 2));

            if (seccion == "REMUNERATIVO" || seccion == "NO_REMUNERATIVO" || seccion == "COMPOSICION") {
                painter.drawText(QRect(colHab, y, colDesc2 - colHab - 10, 50), Qt::AlignRight,
                                 QString::number(monto, 'f', 2));
            } else if (seccion == "DESCUENTO" || seccion == "RECIBO") {
                painter.drawText(QRect(colDesc2, y, pageW - colDesc2, 50), Qt::AlignRight,
                                 QString::number(monto, 'f', 2));
            }
            y += 55;
        }

        if (y > writer.height() - 400) {
            writer.newPage();
            y = 50;
        }
    }

    // ── Totals ──────────────────────────────────────────────────
    y += 20;
    drawLine(y);
    y += 20;

    painter.setFont(headerFont);
    double totalRem = liquidationResult.value("total_remunerativo", 0).toDouble();
    double totalDesc = liquidationResult.value("total_descuentos", 0).toDouble();
    double neto = liquidationResult.value("neto_a_cobrar", 0).toDouble();

    painter.drawText(QRect(colDesc, y, colHab - colDesc, 60), Qt::AlignLeft, "TOTAL REMUNERATIVO:");
    painter.drawText(QRect(colHab, y, colDesc2 - colHab, 60), Qt::AlignRight, QString::number(totalRem, 'f', 2));
    y += 70;

    painter.drawText(QRect(colDesc, y, colDesc2 - colDesc, 60), Qt::AlignLeft, "TOTAL DESCUENTOS:");
    painter.drawText(QRect(colDesc2, y, pageW - colDesc2, 60), Qt::AlignRight, QString::number(totalDesc, 'f', 2));
    y += 70;

    drawLine(y);
    y += 20;

    titleFont.setPointSize(12);
    painter.setFont(titleFont);
    painter.drawText(QRect(colDesc, y, pageW * 0.75, 80), Qt::AlignLeft, "NETO A COBRAR:");
    painter.drawText(QRect(pageW * 0.75, y, pageW * 0.25, 80), Qt::AlignRight,
                     "$ " + QString::number(neto, 'f', 2));

    painter.end();

    qInfo() << "[ExportService] Recibo PDF generado exitosamente:" << filePath;
    return filePath;
}
