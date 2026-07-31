#include "LiquidationEngine.h"
#include "FormulaEngine.h"
#include "QuincenaAggregator.h"
#include "database/DatabaseManager.h"

#include <QDate>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QDebug>

LiquidationEngine::LiquidationEngine(DatabaseManager *db, QObject *parent)
    : QObject(parent), m_db(db)
{
}

int LiquidationEngine::calculateSeniorityYears(const QString &fechaIngreso, const QString &fechaCalculo) const
{
    QDate ingreso = QDate::fromString(fechaIngreso, "yyyy-MM-dd");
    QDate calculo = QDate::fromString(fechaCalculo, "yyyy-MM-dd");

    if (!ingreso.isValid() || !calculo.isValid()) return 0;

    int years = calculo.year() - ingreso.year();
    if (calculo.month() < ingreso.month() ||
        (calculo.month() == ingreso.month() && calculo.day() < ingreso.day())) {
        years--;
    }
    return qMax(0, years);
}

// Helper to parse a string value to its native type
static QVariant parseValue(const QString &val)
{
    if (val.isEmpty()) return 0.0;

    QString trimmed = val.trimmed().toLower();
    if (trimmed == "true") return true;
    if (trimmed == "false") return false;

    bool ok;
    int intVal = val.toInt(&ok);
    if (ok) return intVal;

    double dblVal = val.toDouble(&ok);
    if (ok) return dblVal;

    return val;
}

QVariantMap LiquidationEngine::processLiquidation(int employeeId,
                                                    const QString &quincenaSel,
                                                    const QString &fechaCalculo)
{
    QVariantMap employee = m_db->getEmployee(employeeId);
    if (employee.isEmpty()) {
        return {
            {"empleado", QVariantMap()},
            {"resultados_por_seccion", QVariantMap()},
            {"resultados_grafico", QVariantList()},
            {"contexto_final", QVariantMap()},
            {"errores", QVariantList{{"Empleado no encontrado"}}},
            {"quincena_sel", ""},
        };
    }

    QStringList errores;
    QVariantMap contexto;

    // ═══════════════════════════════════════════════════════════════
    // STEP 0: Calculate seniority
    // ═══════════════════════════════════════════════════════════════
    QString fechaCalc = fechaCalculo.isEmpty() ? QDate::currentDate().toString("yyyy-MM-dd") : fechaCalculo;
    QString fechaIngreso = employee.value("fecha_ingreso", "2020-01-01").toString();
    int antiguedadAnios = calculateSeniorityYears(fechaIngreso, fechaCalc);

    contexto["antiguedad_anios"] = antiguedadAnios;
    contexto["antiguedad"] = antiguedadAnios;
    contexto["fecha_ingreso"] = fechaIngreso;
    contexto["fecha_calculo"] = fechaCalc;
    contexto["tipo_liquidacion"] = employee["tipo_liquidacion"];

    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Inject global variables
    // ═══════════════════════════════════════════════════════════════
    QVariantMap globalFlat;
    QMap<QString, QVariantMap> globalNamespaces; // e.g. {"Q1": {"Horas_Mes": 97}}

    static QRegularExpression dotPattern(R"(^([qQ]\d+)\.(.+))");
    static QRegularExpression suffixPattern(R"((.+)_([qQ]\d+)$)");
    static QRegularExpression prefixPattern(R"(^([qQ]\d+)_(.+))");

    QVariantList globalVars = m_db->listGlobalVariables();
    for (const QVariant &gv : globalVars) {
        QVariantMap g = gv.toMap();
        QString code = g["codigo"].toString().trimmed();
        QVariant val = parseValue(g["valor"].toString().trimmed());

        // Try to match quincena patterns
        QString qMatch;
        QString baseName = code;

        auto m = dotPattern.match(code);
        if (m.hasMatch()) {
            qMatch = m.captured(1).toUpper();
            baseName = m.captured(2).trimmed();
        } else {
            m = suffixPattern.match(code);
            if (m.hasMatch()) {
                qMatch = m.captured(2).toUpper();
                baseName = m.captured(1);
            } else {
                m = prefixPattern.match(code);
                if (m.hasMatch()) {
                    qMatch = m.captured(1).toUpper();
                    baseName = m.captured(2);
                }
            }
        }

        if (!qMatch.isEmpty()) {
            globalNamespaces[qMatch][baseName] = val;
            globalNamespaces[qMatch][code] = val; // Keep original name too
        } else {
            globalFlat[code] = val;
        }
    }

    contexto.insert(globalFlat);

    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Inject employee field values
    // ═══════════════════════════════════════════════════════════════
    bool esJornal = employee["tipo_liquidacion"].toString() == "jornal";
    QString selectedQ = quincenaSel;

    // Get all quincenas for this employee
    QStringList quincenas = m_db->listEmployeeQuincenas(employeeId);
    if (quincenas.isEmpty()) quincenas = {"Q1"};

    QMap<QString, QVariantMap> quincenasData; // Raw input values per quincena

    if (esJornal) {
        // Load values for each quincena
        for (const QString &qn : quincenas) {
            QVariantList fieldValues = m_db->getEmployeeFieldValues(employeeId, qn);
            QVariantMap qVars;
            for (const QVariant &fv : fieldValues) {
                QVariantMap f = fv.toMap();
                qVars[f["field_code"].toString()] = parseValue(f["value"].toString());
            }
            quincenasData[qn] = qVars;
        }

        // Select quincena
        if (selectedQ.isEmpty() || !quincenasData.contains(selectedQ)) {
            selectedQ = quincenas.first();
        }

        // Inject selected quincena's values at top level
        contexto.insert(quincenasData[selectedQ]);

        // Inject global namespace for selected quincena
        if (globalNamespaces.contains(selectedQ)) {
            contexto.insert(globalNamespaces[selectedQ]);
        }

        // Create namespace objects for each quincena (Q1.horas_trabajadas)
        QSet<QString> allQNames = QSet<QString>(quincenas.begin(), quincenas.end());
        for (const QString &k : globalNamespaces.keys()) allQNames.insert(k);

        for (const QString &qn : allQNames) {
            QVariantMap qVars;
            if (globalNamespaces.contains(qn)) qVars.insert(globalNamespaces[qn]);
            if (quincenasData.contains(qn)) qVars.insert(quincenasData[qn]);
            contexto[qn] = qVars;
        }
    } else {
        // Monthly employee — load Q1 values
        QVariantList fieldValues = m_db->getEmployeeFieldValues(employeeId, "Q1");
        for (const QVariant &fv : fieldValues) {
            QVariantMap f = fv.toMap();
            contexto[f["field_code"].toString()] = parseValue(f["value"].toString());
        }
        selectedQ = "";
    }

    // Override seniority (calculated from dates, not user input)
    contexto["antiguedad_anios"] = antiguedadAnios;
    contexto["antiguedad"] = antiguedadAnios;

    // Inject valor_hora from hourly category
    int catId = employee.value("categoria_jornal_id").toInt();
    if (catId > 0) {
        QVariantMap cat = m_db->getCategory(catId);
        contexto["valor_hora"] = cat.value("valor_hora", 0.0);
    } else {
        contexto["valor_hora"] = 0.0;
    }

    // Get schema and cells
    QString esquema = employee.value("esquema_codigo", "MENSUAL").toString();
    QVariantList cells = m_db->listCellsBySchema(esquema);

    // Pre-initialize calculated variables to 0
    for (const QVariant &c : cells) {
        QVariantMap cell = c.toMap();
        QString code = cell["codigo_variable"].toString();
        if (!contexto.contains(code)) {
            contexto[code] = 0.0;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Pre-compute all quincenas for aggregation
    // ═══════════════════════════════════════════════════════════════
    QMap<QString, QVariantMap> quincenaComputed;

    if (esJornal && !quincenasData.isEmpty()) {
        for (auto it = quincenasData.begin(); it != quincenasData.end(); ++it) {
            quincenaComputed[it.key()] = buildQuincenaContext(
                employeeId, it.key(), globalFlat, globalNamespaces, contexto, cells);
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Setup aggregation functions and evaluate cells
    // ═══════════════════════════════════════════════════════════════
    QuincenaAggregator aggregator;
    aggregator.setQuincenaData(quincenaComputed);

    FormulaEngine engine;

    // Register aggregation functions as JS callables
    // We need to use a lambda approach via QJSEngine
    engine.setContext(contexto);

    // Install aggregation functions into the JS engine
    // Since we can't directly pass C++ lambdas as JS functions easily,
    // we pre-compute Q_sum_, Q_avg_ etc. and inject them as variables
    if (esJornal) {
        // Collect all variable names from quincena data
        QSet<QString> allVarNames;
        for (const auto &qData : quincenaComputed) {
            for (auto vi = qData.begin(); vi != qData.end(); ++vi) {
                allVarNames.insert(vi.key());
            }
        }

        // Pre-compute and inject Q_sum_, Q_avg_, Q_max_, Q_min_ for every variable
        for (const QString &varName : allVarNames) {
            engine.setVariable("Q_sum_" + varName, aggregator.sumarQ(varName));
            engine.setVariable("Q_avg_" + varName, aggregator.promedioQ(varName));
            engine.setVariable("Q_max_" + varName, aggregator.maxQ(varName));
            engine.setVariable("Q_min_" + varName, aggregator.minQ(varName));
        }
        engine.setVariable("_cant_q", aggregator.cantQ());
    }

    // Register helper functions as JS code
    auto setupFunctions = QString(R"(
        function sumar_q(varName) { return typeof this['Q_sum_' + varName] !== 'undefined' ? this['Q_sum_' + varName] : 0; }
        function promedio_q(varName) { return typeof this['Q_avg_' + varName] !== 'undefined' ? this['Q_avg_' + varName] : 0; }
        function max_q(varName) { return typeof this['Q_max_' + varName] !== 'undefined' ? this['Q_max_' + varName] : 0; }
        function min_q(varName) { return typeof this['Q_min_' + varName] !== 'undefined' ? this['Q_min_' + varName] : 0; }
        function cant_q() { return typeof _cant_q !== 'undefined' ? _cant_q : 1; }
    )");
    engine.evaluate(setupFunctions);

    // Historical functions using receipts
    // For now, implement as JavaScript stubs that look up pre-injected data
    // (Full implementation will query DB - we inject the results as variables)

    // ═══════════════════════════════════════════════════════════════
    // STEP 5: Evaluate all cells sequentially
    // ═══════════════════════════════════════════════════════════════
    QVariantMap resultadosPorSeccion;
    QVariantList allConceptosList;
    double totalRemunerativo = 0.0;
    double totalNoRemunerativo = 0.0;
    double totalDescuentos = 0.0;

    for (const QVariant &c : cells) {
        QVariantMap cell = c.toMap();
        QString seccion = cell["seccion_codigo"].toString();
        QString codigo = cell["codigo_variable"].toString();
        QString tipoCalc = cell.value("tipo_calculo", "formula").toString();

        // Evaluate condition
        QString condicion = cell.value("condicion", "").toString().trimmed();
        if (!condicion.isEmpty()) {
            QString condError;
            bool condResult = engine.evaluateCondition(condicion, &condError);
            if (!condError.isEmpty()) {
                errores.append(QString("[%1] Error en condición '%2': %3").arg(codigo, condicion, condError));
                continue;
            }
            if (!condResult) {
                continue;
            }
        }

        // Evaluate based on calculation type
        QVariant unidad;
        QVariant base;
        double monto = 0.0;

        if (tipoCalc == "porcentaje") {
            double pct = cell.value("simple_porcentaje", 0.0).toDouble();
            QString baseVar = cell.value("simple_base_variable", "").toString();
            double baseVal = engine.getVariable(baseVar).toDouble();

            unidad = pct / 100.0;
            base = baseVal;
            monto = qRound(unidad.toDouble() * baseVal * 100.0) / 100.0; // round to 2 decimals

        } else if (tipoCalc == "fijo") {
            monto = cell.value("simple_monto_fijo", 0.0).toDouble();

        } else {
            // Formula type
            QString formulaU = cell.value("formula_unidad", "").toString().trimmed();
            if (!formulaU.isEmpty()) {
                QString err;
                unidad = engine.evaluate(formulaU, &err);
                if (!err.isEmpty()) {
                    errores.append(QString("[%1] Error en fórmula unidad '%2': %3").arg(codigo, formulaU, err));
                    unidad = 0.0;
                }
            }
            engine.setVariable("unidad", unidad.isValid() ? unidad : QVariant(0.0));

            QString formulaB = cell.value("formula_base", "").toString().trimmed();
            if (!formulaB.isEmpty()) {
                QString err;
                base = engine.evaluate(formulaB, &err);
                if (!err.isEmpty()) {
                    errores.append(QString("[%1] Error en fórmula base '%2': %3").arg(codigo, formulaB, err));
                    base = 0.0;
                }
            }
            engine.setVariable("base", base.isValid() ? base : QVariant(0.0));

            QString formulaM = cell.value("formula_monto", "").toString().trimmed();
            if (!formulaM.isEmpty()) {
                QString err;
                QVariant montoResult = engine.evaluate(formulaM, &err);
                if (!err.isEmpty()) {
                    errores.append(QString("[%1] Error en fórmula monto '%2': %3").arg(codigo, formulaM, err));
                } else {
                    monto = montoResult.toDouble();
                }
            }
        }

        // Store result in context for subsequent formulas
        engine.setVariable(codigo, monto);
        contexto[codigo] = monto;

        // Build result row
        QVariantMap fila = {
            {"codigo_variable", codigo},
            {"codigo", codigo},
            {"descripcion", cell["descripcion"]},
            {"unidad", unidad},
            {"base", base},
            {"monto", monto},
            {"seccion", seccion},
            {"visible_recibo", cell.value("visible_recibo", 1)},
        };

        QVariantList seccionList = resultadosPorSeccion.value(seccion).toList();
        seccionList.append(fila);
        resultadosPorSeccion[seccion] = seccionList;

        allConceptosList.append(fila);

        // Classify and accumulate totals
        QString secUpper = seccion.trimmed().toUpper();
        if (secUpper == "REMUNERATIVO" || secUpper == "COMPOSICION" || secUpper == "HABERES") {
            totalRemunerativo += monto;
        } else if (secUpper == "NO_REMUNERATIVO") {
            totalNoRemunerativo += monto;
        } else if (secUpper == "DESCUENTO" || secUpper == "RECIBO" || secUpper == "RETENCION" || secUpper == "RETENCIONES") {
            totalDescuentos += monto;
        }
    }

    double netoACobrar = (totalRemunerativo + totalNoRemunerativo) - totalDescuentos;

    contexto["total_remunerativo"] = totalRemunerativo;
    contexto["total_no_remunerativo"] = totalNoRemunerativo;
    contexto["total_descuentos"] = totalDescuentos;
    contexto["neto_a_cobrar"] = netoACobrar;
    contexto["neto"] = netoACobrar;

    // ═══════════════════════════════════════════════════════════════
    // STEP 6: Evaluate chart cells
    // ═══════════════════════════════════════════════════════════════
    QVariantList resultadosGrafico;
    QVariantList chartCells = m_db->listChartCellsBySchema(esquema);
    for (const QVariant &cg : chartCells) {
        QVariantMap chartCell = cg.toMap();
        QString formula = chartCell["formula"].toString().trimmed();
        double valor = 0.0;
        if (!formula.isEmpty()) {
            QString err;
            QVariant result = engine.evaluate(formula, &err);
            if (!err.isEmpty()) {
                errores.append(QString("[Gráfico: %1] Error en fórmula '%2': %3")
                    .arg(chartCell["etiqueta"].toString(), formula, err));
            } else {
                valor = result.toDouble();
            }
        }
        resultadosGrafico.append(QVariantMap{
            {"id", chartCell["id"]},
            {"etiqueta", chartCell["etiqueta"]},
            {"valor", valor},
        });
    }

    return {
        {"empleado", employee},
        {"conceptos", allConceptosList},
        {"total_remunerativo", totalRemunerativo},
        {"total_no_remunerativo", totalNoRemunerativo},
        {"total_descuentos", totalDescuentos},
        {"neto_a_cobrar", netoACobrar},
        {"resultados_por_seccion", resultadosPorSeccion},
        {"resultados_grafico", resultadosGrafico},
        {"contexto_final", contexto},
        {"errores", QVariant::fromValue(errores)},
        {"quincena_sel", selectedQ},
    };
}

QVariantMap LiquidationEngine::buildQuincenaContext(int employeeId, const QString &quincenaCode,
                                                      const QVariantMap &globalFlat,
                                                      const QMap<QString, QVariantMap> &globalNamespaces,
                                                      const QVariantMap &baseContext,
                                                      const QVariantList &cells)
{
    // Build a temporary context for evaluating all cells for a specific quincena
    QVariantMap ctx = globalFlat;

    // Copy base context values (seniority, tipo_liquidacion, valor_hora, etc.)
    ctx["antiguedad_anios"] = baseContext.value("antiguedad_anios", 0);
    ctx["antiguedad"] = baseContext.value("antiguedad", 0);
    ctx["tipo_liquidacion"] = baseContext.value("tipo_liquidacion");
    ctx["valor_hora"] = baseContext.value("valor_hora", 0.0);

    // Inject employee values for this quincena
    QVariantList fieldValues = m_db->getEmployeeFieldValues(employeeId, quincenaCode);
    for (const QVariant &fv : fieldValues) {
        QVariantMap f = fv.toMap();
        ctx[f["field_code"].toString()] = parseValue(f["value"].toString());
    }

    // Inject global namespace for this quincena
    if (globalNamespaces.contains(quincenaCode)) {
        ctx.insert(globalNamespaces[quincenaCode]);
    }

    // Pre-initialize calculated variables
    for (const QVariant &c : cells) {
        QVariantMap cell = c.toMap();
        QString code = cell["codigo_variable"].toString();
        if (!ctx.contains(code)) ctx[code] = 0.0;
    }

    // Evaluate all cells with a temporary engine
    FormulaEngine tmpEngine;
    tmpEngine.setContext(ctx);

    for (const QVariant &c : cells) {
        QVariantMap cell = c.toMap();
        QString codigo = cell["codigo_variable"].toString();
        QString tipoCalc = cell.value("tipo_calculo", "formula").toString();

        // Condition check
        QString cond = cell.value("condicion", "").toString().trimmed();
        if (!cond.isEmpty()) {
            if (!tmpEngine.evaluateCondition(cond)) continue;
        }

        double monto = 0.0;
        if (tipoCalc == "porcentaje") {
            double pct = cell.value("simple_porcentaje", 0.0).toDouble();
            QString baseVar = cell.value("simple_base_variable", "").toString();
            double baseVal = tmpEngine.getVariable(baseVar).toDouble();
            monto = qRound((pct / 100.0) * baseVal * 100.0) / 100.0;
        } else if (tipoCalc == "fijo") {
            monto = cell.value("simple_monto_fijo", 0.0).toDouble();
        } else {
            QString fu = cell.value("formula_unidad", "").toString().trimmed();
            if (!fu.isEmpty()) {
                QVariant u = tmpEngine.evaluate(fu);
                tmpEngine.setVariable("unidad", u);
            } else {
                tmpEngine.setVariable("unidad", 0.0);
            }

            QString fb = cell.value("formula_base", "").toString().trimmed();
            if (!fb.isEmpty()) {
                QVariant b = tmpEngine.evaluate(fb);
                tmpEngine.setVariable("base", b);
            } else {
                tmpEngine.setVariable("base", 0.0);
            }

            QString fm = cell.value("formula_monto", "").toString().trimmed();
            if (!fm.isEmpty()) {
                QVariant result = tmpEngine.evaluate(fm);
                monto = result.toDouble();
            }
        }

        tmpEngine.setVariable(codigo, monto);
        ctx[codigo] = monto;
    }

    return ctx;
}

int LiquidationEngine::persistLiquidation(const QVariantMap &result, int mes, int anio, const QString &periodo)
{
    QVariantMap emp = result.value("empleado").toMap();
    if (emp.isEmpty()) return -1;

    QString esquema = emp.value("esquema_codigo", "MENSUAL").toString();
    QVariantMap ctx = result.value("contexto_final").toMap();

    // Filter to serializable values only
    QJsonObject jsonObj;
    for (auto it = ctx.begin(); it != ctx.end(); ++it) {
        const QVariant &v = it.value();
        if (v.typeId() == QMetaType::Double || v.typeId() == QMetaType::Float) {
            jsonObj[it.key()] = v.toDouble();
        } else if (v.typeId() == QMetaType::Int || v.typeId() == QMetaType::LongLong) {
            jsonObj[it.key()] = v.toInt();
        } else if (v.typeId() == QMetaType::Bool) {
            jsonObj[it.key()] = v.toBool();
        } else if (v.typeId() == QMetaType::QString) {
            jsonObj[it.key()] = v.toString();
        }
        // Skip non-serializable types (QVariantMaps for namespaces, etc.)
    }

    QString datosJson = QJsonDocument(jsonObj).toJson(QJsonDocument::Compact);
    return m_db->saveReceipt(emp["id"].toInt(), esquema, mes, anio, periodo, datosJson);
}
