#include "LiquidationEngine.h"
#include "FormulaEngine.h"
#include "QuincenaAggregator.h"
#include "database/DatabaseManager.h"
#include "services/ExportService.h"

#include <QDate>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <functional>

LiquidationEngine::LiquidationEngine(DatabaseManager *db, QObject *parent)
    : QObject(parent), m_db(db) {}

int LiquidationEngine::calculateSeniorityYears(
    const QString &fechaIngreso, const QString &fechaCalculo) const {
  QDate ingreso = QDate::fromString(fechaIngreso, "yyyy-MM-dd");
  QDate calculo = QDate::fromString(fechaCalculo, "yyyy-MM-dd");

  if (!ingreso.isValid() || !calculo.isValid())
    return 0;

  int years = calculo.year() - ingreso.year();
  if (calculo.month() < ingreso.month() ||
      (calculo.month() == ingreso.month() && calculo.day() < ingreso.day())) {
    years--;
  }
  return qMax(0, years);
}

// Helper to parse a string value to its native type
static QVariant parseValue(const QString &val) {
  if (val.isEmpty())
    return 0.0;

  QString trimmed = val.trimmed().toLower();
  if (trimmed == "true")
    return true;
  if (trimmed == "false")
    return false;

  bool ok;
  int intVal = val.toInt(&ok);
  if (ok)
    return intVal;

  double dblVal = val.toDouble(&ok);
  if (ok)
    return dblVal;

  return val;
}

QVariantMap LiquidationEngine::processLiquidation(int employeeId,
                                                  const QString &quincenaSel,
                                                  const QString &fechaCalculo,
                                                  const QString &fechaCierre,
                                                  const QString &fechaPago) {
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
  // The fecha_cierre (closing date) takes priority as the calculation date
  // for seniority, then fechaCalculo, then today's date.
  QString fechaCalc = fechaCalculo.isEmpty()
                          ? QDate::currentDate().toString("yyyy-MM-dd")
                          : fechaCalculo;
  if (!fechaCierre.isEmpty()) {
    fechaCalc = fechaCierre;
  }
  QString fechaIngreso =
      employee.value("fecha_ingreso", "2020-01-01").toString();
  int antiguedadAnios = calculateSeniorityYears(fechaIngreso, fechaCalc);

  contexto["antiguedad_anios"] = antiguedadAnios;
  contexto["antiguedad"] = antiguedadAnios;
  contexto["fecha_ingreso"] = fechaIngreso;
  contexto["fecha_calculo"] = fechaCalc;
  contexto["tipo_liquidacion"] = employee["tipo_liquidacion"];
  contexto["fecha_cierre"] = fechaCierre.isEmpty() ? fechaCalc : fechaCierre;
  contexto["FECHA_CIERRE"] = contexto["fecha_cierre"];
  contexto["fecha_pago"] = fechaPago;
  contexto["FECHA_PAGO"] = fechaPago;

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
  if (quincenas.isEmpty()) {
    quincenas = {"Q1", "Q2"};
  } else if (quincenas.size() == 1 && quincenas.contains("Q1")) {
    quincenas.append("Q2");
  }

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
    for (const QString &k : globalNamespaces.keys())
      allQNames.insert(k);

    for (const QString &qn : allQNames) {
      QVariantMap qVars;
      if (globalNamespaces.contains(qn))
        qVars.insert(globalNamespaces[qn]);
      if (quincenasData.contains(qn))
        qVars.insert(quincenasData[qn]);
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

  // Override seniority and inject full employee metadata into formula context
  contexto["antiguedad_anios"] = antiguedadAnios;
  contexto["antiguedad"] = antiguedadAnios;
  contexto["legajo"] = employee["legajo"];
  contexto["nombre"] = employee["nombre_completo"];
  contexto["cuil"] = employee["cuil"];
  contexto["fecha_calculo"] = fechaCalc;
  contexto["FECHA_CALCULO"] = fechaCalc;

  QDate fDate = QDate::fromString(fechaCalc, "yyyy-MM-dd");
  if (!fDate.isValid()) fDate = QDate::currentDate();
  contexto["mes"] = fDate.month();
  contexto["MES_CALCULO"] = fDate.month();
  contexto["anio"] = fDate.year();
  contexto["ANIO_CALCULO"] = fDate.year();
  contexto["dia"] = fDate.day();
  contexto["DIA_CALCULO"] = fDate.day();

  // Inject valor_hora, jornal, basico from category
  int catId = employee.value("categoria_jornal_id").toInt();
  double valorHora = 0.0;
  QString categoriaNombre;
  if (catId > 0) {
    QVariantMap cat = m_db->getCategory(catId);
    valorHora = cat.value("valor_hora", 0.0).toDouble();
    categoriaNombre = cat.value("nombre").toString();
  }
  contexto["valor_hora"] = valorHora;
  contexto["jornal"] = valorHora;
  contexto["categoria_nombre"] = categoriaNombre;

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

  // Build the 'env' object for custom user functions (base for Step 4)
  QVariantMap baseEnvObj;
  {
    QVariantMap empEnv;
    empEnv["id"] = employee["id"];
    empEnv["nombre"] = employee["nombre_completo"];
    empEnv["legajo"] = employee["legajo"];
    empEnv["tipo_liquidacion"] = employee["tipo_liquidacion"];
    empEnv["fecha_ingreso"] = fechaIngreso;
    empEnv["antiguedad_anios"] = antiguedadAnios;
    empEnv["cuil"] = employee["cuil"];
    empEnv["esquema_codigo"] = esquema;
    if (catId > 0) {
      QVariantMap cat = m_db->getCategory(catId);
      QVariantMap catEnv;
      catEnv["nombre"] = cat.value("nombre");
      catEnv["valor_hora"] = cat.value("valor_hora", 0.0);
      empEnv["categoria"] = catEnv;
    }
    baseEnvObj["empleado"] = empEnv;
    baseEnvObj["fecha_calculo"] = fechaCalc;
    baseEnvObj["fecha_cierre"] = contexto["fecha_cierre"];
    baseEnvObj["fecha_pago"] = fechaPago;
    QDate fechaDate = QDate::fromString(fechaCalc, "yyyy-MM-dd");
    baseEnvObj["mes"] = fechaDate.isValid() ? fechaDate.month() : QDate::currentDate().month();
    baseEnvObj["anio"] = fechaDate.isValid() ? fechaDate.year() : QDate::currentDate().year();
    baseEnvObj["globals"] = globalFlat;
    baseEnvObj["quincenas"] = QVariantList();
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 3: Pre-compute all quincenas for aggregation
  // ═══════════════════════════════════════════════════════════════
  QMap<QString, QVariantMap> quincenaComputed;

  if (esJornal && !quincenasData.isEmpty()) {
    for (auto it = quincenasData.begin(); it != quincenasData.end(); ++it) {
      quincenaComputed[it.key()] = buildQuincenaContext(
          employeeId, it.key(), globalFlat, globalNamespaces, contexto, cells, baseEnvObj);
      contexto[it.key() + "_obj"] = quincenaComputed[it.key()];
    }
  } else {
    quincenaComputed["M"] = buildQuincenaContext(
        employeeId, "M", globalFlat, globalNamespaces, contexto, cells, baseEnvObj);
    contexto["M_obj"] = quincenaComputed["M"];
  }

  // Map current cells by ID to support alias lookup if renamed
  QMap<int, QString> cellIdToCurrentCode;
  for (const QVariant &c : cells) {
    QVariantMap cm = c.toMap();
    int cId = cm.value("id", 0).toInt();
    QString code = cm.value("codigo_variable", "").toString();
    if (cId > 0 && !code.isEmpty()) {
      cellIdToCurrentCode[cId] = code;
    }
  }

  // Load historical receipt snapshots for custom functions evaluation
  QVariantList historyList;
  QVariantList receipts = m_db->listReceiptsByEmployee(employeeId);
  for (const QVariant &r : receipts) {
    QVariantMap rec = r.toMap();
    QString jsonStr = rec["datos_json"].toString();
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (doc.isObject()) {
      QJsonObject obj = doc.object();
      QVariantMap histItem = obj.toVariantMap();

      // Reverse lookup: map concept amounts by cell_id to current schema code
      if (obj.contains("conceptos") && obj["conceptos"].isArray()) {
        QJsonArray concArr = obj["conceptos"].toArray();
        for (const QJsonValue &cv : concArr) {
          if (cv.isObject()) {
            QJsonObject cObj = cv.toObject();
            int cId = cObj["cell_id"].toInt();
            double monto = cObj["monto"].toDouble();
            QString origCode = cObj["codigo"].toString();
            if (!origCode.isEmpty()) {
              histItem[origCode] = monto;
            }
            if (cId > 0) {
              histItem["cell_" + QString::number(cId)] = monto;
              if (cellIdToCurrentCode.contains(cId)) {
                histItem[cellIdToCurrentCode[cId]] = monto;
              }
            }
          }
        }
      }

      // Inject month/year metadata
      histItem["_mes"] = rec["mes"];
      histItem["_anio"] = rec["anio"];
      histItem["_periodo"] = rec["periodo"];
      histItem["mes"] = rec["mes"];
      histItem["anio"] = rec["anio"];
      histItem["periodo"] = rec["periodo"];
      historyList.append(histItem);
    }
  }
  contexto["_history"] = historyList;
  qDebug() << "[LiquidationEngine] Loaded" << historyList.size()
           << "historical receipt snapshots for env.historial";

  // Inject flat aggregated variables (Q_sum_*, Q_avg_*, Q_max_*, Q_min_*) for formulas
  if (esJornal) {
    QSet<QString> allVarNames;
    for (const auto &qData : quincenaComputed) {
      for (auto vi = qData.begin(); vi != qData.end(); ++vi) {
        allVarNames.insert(vi.key());
      }
    }
    for (const QString &varName : allVarNames) {
      double sumVal = 0.0;
      double maxVal = -1e18;
      double minVal = 1e18;
      int count = quincenaComputed.size();
      for (const auto &qData : quincenaComputed) {
        double v = qData.value(varName).toDouble();
        sumVal += v;
        if (v > maxVal) maxVal = v;
        if (v < minVal) minVal = v;
      }
      contexto["Q_sum_" + varName] = sumVal;
      contexto["Q_avg_" + varName] = count > 0 ? (sumVal / count) : 0.0;
      contexto["Q_max_" + varName] = maxVal;
      contexto["Q_min_" + varName] = minVal;
    }
    contexto["_cant_q"] = quincenaComputed.size();
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 4: Setup env object, custom functions and evaluate cells
  // ═══════════════════════════════════════════════════════════════
  FormulaEngine engine;
  engine.setContext(contexto);

  // Build the 'env' object for custom user functions
  QVariantMap envObj = baseEnvObj;
  {
    // env.quincenas (array of computed quincena data)
    QVariantList quincenasArray;
    for (auto it = quincenaComputed.begin(); it != quincenaComputed.end();
         ++it) {
      QVariantMap qEnv = it.value();
      qEnv["code"] = it.key();
      quincenasArray.append(qEnv);
    }
    envObj["quincenas"] = quincenasArray;

    // env.historial
    envObj["historial"] = historyList;
  }

  engine.setEnvObject(envObj);

  // Load and register custom user-defined functions
  QVariantList customFuncs = m_db->listCustomFunctions();
  if (!customFuncs.isEmpty()) {
    engine.registerCustomFunctions(customFuncs);
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 5: Evaluate all cells sequentially
  // ═══════════════════════════════════════════════════════════════
  QVariantMap resultadosPorSeccion;
  QVariantList allConceptosList;

  QVariantList quincenasArray = envObj["quincenas"].toList();

  for (const QVariant &c : cells) {
    QVariantMap cell = c.toMap();
    QString seccion = cell["seccion_codigo"].toString();
    QString codigoVar = cell["codigo_variable"].toString();
    QString tipoCalc = cell.value("tipo_calculo", "formula").toString();

    // Evaluate condition
    QString condicion = cell.value("condicion", "").toString().trimmed();
    if (!condicion.isEmpty()) {
      QString condError;
      bool condResult = engine.evaluateCondition(condicion, &condError);
      if (!condError.isEmpty()) {
        errores.append(QString("[%1] Error en condición '%2': %3")
                           .arg(codigoVar, condicion, condError));
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

    if (tipoCalc == "separator") {
      monto = 0.0;
    } else if (tipoCalc == "porcentaje") {
      double pct = cell.value("simple_porcentaje", 0.0).toDouble();
      QString baseVar =
          cell.value("simple_base_variable", "").toString().trimmed().toLower();
      double baseVal = 0.0;
      if (!baseVar.isEmpty()) {
        baseVal = engine.getVariable(baseVar).toDouble();
      }
      unidad = pct;
      base = baseVal;
      monto = qRound((baseVal * (pct / 100.0)) * 100.0) / 100.0;

    } else if (tipoCalc == "fijo") {
      monto = cell.value("simple_monto_fijo", 0.0).toDouble();

    } else if (tipoCalc == "simple") {
      double pct = cell.value("simple_porcentaje", 0.0).toDouble();
      QString baseVar =
          cell.value("simple_base_variable", "").toString().trimmed().toLower();
      double montoFijo = cell.value("simple_monto_fijo", 0.0).toDouble();
      double baseVal = 0.0;
      if (!baseVar.isEmpty()) {
        baseVal = engine.getVariable(baseVar).toDouble();
      }

      if (pct != 0.0 && baseVal != 0.0) {
        unidad = pct;
        base = baseVal;
        monto = (baseVal * (pct / 100.0)) + montoFijo;
      } else if (montoFijo != 0.0) {
        monto = montoFijo;
        if (pct != 0.0)
          unidad = pct;
        if (baseVal != 0.0)
          base = baseVal;
      } else if (pct != 0.0) {
        unidad = pct;
        base = baseVal;
        monto = baseVal * (pct / 100.0);
      }
      monto = qRound(monto * 100.0) / 100.0;

    } else {
      // Formula type
      QString formulaU = cell.value("formula_unidad", "").toString().trimmed();
      if (!formulaU.isEmpty()) {
        QString err;
        unidad = engine.evaluate(formulaU, &err);
        if (!err.isEmpty()) {
          errores.append(QString("[%1] Error en fórmula unidad '%2': %3")
                             .arg(codigoVar, formulaU, err));
          unidad = 0.0;
        }
      }
      engine.setVariable("unidad", unidad.isValid() ? unidad : QVariant(0.0));

      QString formulaB = cell.value("formula_base", "").toString().trimmed();
      if (!formulaB.isEmpty()) {
        QString err;
        base = engine.evaluate(formulaB, &err);
        if (!err.isEmpty()) {
          errores.append(QString("[%1] Error en fórmula base '%2': %3")
                             .arg(codigoVar, formulaB, err));
          base = 0.0;
        }
      }
      engine.setVariable("base", base.isValid() ? base : QVariant(0.0));

      QString formulaM = cell.value("formula_monto", "").toString().trimmed();
      if (!formulaM.isEmpty()) {
        QString err;
        QVariant montoResult = engine.evaluate(formulaM, &err);
        if (!err.isEmpty()) {
          errores.append(QString("[%1] Error en fórmula monto '%2': %3")
                             .arg(codigoVar, formulaM, err));
        } else {
          monto = montoResult.toDouble();
        }
      } else if (!formulaB.isEmpty() || !formulaU.isEmpty()) {
        // Fallback: if no monto formula but base/unit exist, compute monto = base * (unit > 0 ? unit : 1)
        double bVal = engine.getVariable("base").toDouble();
        double uVal = engine.getVariable("unidad").toDouble();
        monto = bVal * (uVal > 0.0 ? uVal : 1.0);
      }
    }

    // Store in context for subsequent formulas
    contexto[codigoVar] = monto;
    engine.setVariable(codigoVar, monto);

    // Update live calculated variable into env.quincenas for current period
    for (int qi = 0; qi < quincenasArray.size(); ++qi) {
        QVariantMap qMap = quincenasArray[qi].toMap();
        if (qMap["code"].toString() == selectedQ || (selectedQ.isEmpty() && qMap["code"].toString() == "M")) {
            qMap[codigoVar] = monto;
            quincenasArray[qi] = qMap;
        }
    }
    envObj["quincenas"] = quincenasArray;
    engine.setEnvObject(envObj);

    // Build result row
    QVariantMap fila = {
        {"cell_id", cell.value("id", 0)},
        {"codigo", codigoVar},
        {"codigo_variable", codigoVar},
        {"descripcion", cell["descripcion"]},
        {"unidad", unidad},
        {"base", base},
        {"monto", monto},
        {"seccion", seccion},
        {"tipo_calculo", tipoCalc},
        {"simple_porcentaje", cell.value("simple_porcentaje", 0.0)},
        {"simple_base_variable", cell.value("simple_base_variable", "")},
        {"simple_monto_fijo", cell.value("simple_monto_fijo", 0.0)},
        {"visible_recibo", cell.value("visible_recibo", 1)},
        {"en_grafico", cell.value("en_grafico", 0)},
        {"es_grafico_total", cell.value("es_grafico_total", 0)},
        {"color_hex", cell.value("color_hex", "")}
    };

    QVariantList seccionList = resultadosPorSeccion.value(seccion).toList();
    seccionList.append(fila);
    resultadosPorSeccion[seccion] = seccionList;

    allConceptosList.append(fila);
  }

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
        errores.append(
            QString("[Gráfico: %1] Error en fórmula '%2': %3")
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

  // Collect auto-initialized variable warnings
  QStringList autoVars = engine.autoInitializedVars();
  for (const QString &av : autoVars) {
    errores.append(QString("[Advertencia] Variable '%1' no estaba definida y fue inicializada a 0.0 (posible error de tipeo)").arg(av));
  }

  double totalRemunerativo = contexto.value("total_remunerativo", 0.0).toDouble();
  double totalNoRemunerativo = contexto.value("total_no_remunerativo", 0.0).toDouble();
  double totalDescuentos = contexto.value("total_descuentos", 0.0).toDouble();
  double netoACobrar = contexto.value("neto", contexto.value("neto_a_cobrar", 0.0)).toDouble();

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
      {"fecha_cierre", contexto.value("fecha_cierre")},
      {"FECHA_CIERRE", contexto.value("fecha_cierre")},
      {"fecha_pago", fechaPago},
      {"FECHA_PAGO", fechaPago},
      {"categoria_nombre", categoriaNombre},
      {"valor_hora", valorHora},
  };
}

QVariantMap LiquidationEngine::buildQuincenaContext(
    int employeeId, const QString &quincenaCode, const QVariantMap &globalFlat,
    const QMap<QString, QVariantMap> &globalNamespaces,
    const QVariantMap &baseContext, const QVariantList &cells,
    const QVariantMap &baseEnvObj) {
  // Build a temporary context for evaluating all cells for a specific quincena
  QVariantMap ctx = globalFlat;

  // Copy base context values (seniority, tipo_liquidacion, valor_hora, jornal, etc.)
  ctx.insert(baseContext);
  ctx["antiguedad_anios"] = baseContext.value("antiguedad_anios", 0);
  ctx["antiguedad"] = baseContext.value("antiguedad", 0);
  ctx["tipo_liquidacion"] = baseContext.value("tipo_liquidacion");
  double vh = baseContext.value("valor_hora", 0.0).toDouble();
  ctx["valor_hora"] = vh;
  ctx["jornal"] = vh;

  // Inject employee values for this quincena (if 'M', map to 'Q1' where monthly values are stored)
  QString qnToFetch = (quincenaCode == "M" || quincenaCode.isEmpty()) ? "Q1" : quincenaCode;
  QVariantList fieldValues =
      m_db->getEmployeeFieldValues(employeeId, qnToFetch);
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
    if (!ctx.contains(code))
      ctx[code] = 0.0;
  }

  // Evaluate all cells with a temporary engine
  FormulaEngine tmpEngine;
  tmpEngine.setContext(ctx);
  tmpEngine.setEnvObject(baseEnvObj);

  QVariantList customFuncs = m_db->listCustomFunctions();
  if (!customFuncs.isEmpty()) {
    tmpEngine.registerCustomFunctions(customFuncs);
  }

  double qBruto = 0.0;
  double qNoRemun = 0.0;
  double qDesc = 0.0;

  for (const QVariant &c : cells) {
    QVariantMap cell = c.toMap();
    QString codigo = cell["codigo_variable"].toString();
    QString seccion = cell["seccion_codigo"].toString().trimmed().toUpper();
    QString tipoCalc = cell.value("tipo_calculo", "formula").toString();

    // Condition check
    QString cond = cell.value("condicion", "").toString().trimmed();
    if (!cond.isEmpty()) {
      if (!tmpEngine.evaluateCondition(cond))
        continue;
    }

    double monto = 0.0;
    if (tipoCalc == "separator") {
      monto = 0.0;
    } else if (tipoCalc == "porcentaje") {
      double pct = cell.value("simple_porcentaje", 0.0).toDouble();
      QString baseVar = cell.value("simple_base_variable", "").toString();
      double baseVal = tmpEngine.getVariable(baseVar).toDouble();
      monto = qRound((pct / 100.0) * baseVal * 100.0) / 100.0;
    } else if (tipoCalc == "fijo") {
      monto = cell.value("simple_monto_fijo", 0.0).toDouble();
    } else if (tipoCalc == "simple") {
      double pct = cell.value("simple_porcentaje", 0.0).toDouble();
      QString baseVar = cell.value("simple_base_variable", "").toString().trimmed().toLower();
      double montoFijo = cell.value("simple_monto_fijo", 0.0).toDouble();
      double baseVal = 0.0;
      if (!baseVar.isEmpty()) {
        baseVal = tmpEngine.getVariable(baseVar).toDouble();
      }
      if (pct != 0.0 && baseVal != 0.0) {
        monto = (baseVal * (pct / 100.0)) + montoFijo;
      } else if (montoFijo != 0.0) {
        monto = montoFijo;
      } else if (pct != 0.0) {
        monto = baseVal * (pct / 100.0);
      }
      monto = qRound(monto * 100.0) / 100.0;
    } else {
      // Formula type
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
      } else if (!fb.isEmpty() || !fu.isEmpty()) {
        double bVal = tmpEngine.getVariable("base").toDouble();
        double uVal = tmpEngine.getVariable("unidad").toDouble();
        monto = bVal * (uVal > 0.0 ? uVal : 1.0);
      }
    }

    tmpEngine.setVariable(codigo, monto);
    ctx[codigo] = monto;
  }


  return ctx;
}

int LiquidationEngine::persistLiquidation(const QVariantMap &result, int mes,
                                          int anio, const QString &periodo,
                                          const QString &fechaCierre,
                                          const QString &fechaPago,
                                          int cierreId) {
  QVariantMap emp = result.value("empleado").toMap();
  if (emp.isEmpty())
    return -1;

  QString esquema = emp.value("esquema_codigo", "MENSUAL").toString();
  QVariantMap ctx = result.value("contexto_final").toMap();

  QJsonObject rootObj;

  // 1. Meta
  QJsonObject metaObj;
  metaObj["empleado_id"] = emp["id"].toInt();
  metaObj["esquema_codigo"] = esquema;
  metaObj["mes"] = mes;
  metaObj["anio"] = anio;
  metaObj["periodo"] = periodo;
  metaObj["fecha_calculo"] = ctx.value("fecha_calculo").toString();
  metaObj["fecha_cierre"] = fechaCierre.isEmpty() ? ctx.value("fecha_cierre").toString() : fechaCierre;
  metaObj["fecha_pago"] = fechaPago.isEmpty() ? ctx.value("fecha_pago").toString() : fechaPago;
  if (cierreId > 0) {
    metaObj["cierre_id"] = cierreId;
  }
  rootObj["meta"] = metaObj;

  // 1.1 Snapshot de la Empresa al momento de emitir el recibo
  QVariantMap comp = m_db->getCompany();
  QJsonObject compObj;
  compObj["razon_social"] = comp.value("razon_social").toString();
  compObj["cuit"] = comp.value("cuit").toString();
  compObj["direccion"] = comp.value("direccion").toString();
  compObj["lugar_de_pago"] = comp.value("lugar_de_pago").toString();
  rootObj["empresa"] = compObj;

  // 1.2 Snapshot del Empleado al momento de emitir el recibo
  QJsonObject empObj;
  empObj["id"] = emp["id"].toInt();
  empObj["legajo"] = emp["legajo"].toString();
  empObj["nombre_completo"] = emp["nombre_completo"].toString();
  empObj["cuil"] = emp["cuil"].toString();
  empObj["tipo_liquidacion"] = emp["tipo_liquidacion"].toString();
  empObj["esquema_codigo"] = esquema;
  empObj["categoria_nombre"] = result.value("categoria_nombre", emp.value("categoria_nombre")).toString();
  empObj["fecha_ingreso"] = emp.value("fecha_ingreso").toString();
  empObj["antiguedad_anios"] = ctx.value("antiguedad_anios", 0).toInt();
  empObj["valor_hora"] = result.value("valor_hora", 0.0).toDouble();
  rootObj["empleado"] = empObj;

  // 2. Totales
  QJsonObject totalesObj;
  totalesObj["total_remunerativo"] = result.value("total_remunerativo").toDouble();
  totalesObj["total_no_remunerativo"] = result.value("total_no_remunerativo").toDouble();
  totalesObj["total_descuentos"] = result.value("total_descuentos").toDouble();
  totalesObj["neto_a_cobrar"] = result.value("neto_a_cobrar").toDouble();
  rootObj["totales"] = totalesObj;

  // 3. Variables planas de insumos
  // Helper lambda to convert QVariant to QJsonValue recursively
  std::function<QJsonValue(const QVariant &)> variantToJson;
  variantToJson = [&variantToJson](const QVariant &v) -> QJsonValue {
    if (v.typeId() == QMetaType::Bool) {
      return QJsonValue(v.toBool());
    } else if (v.typeId() == QMetaType::Double || v.typeId() == QMetaType::Float) {
      return QJsonValue(v.toDouble());
    } else if (v.typeId() == QMetaType::Int || v.typeId() == QMetaType::LongLong) {
      return QJsonValue(v.toInt());
    } else if (v.typeId() == QMetaType::QString) {
      return QJsonValue(v.toString());
    } else if (v.canConvert<QVariantMap>()) {
      QVariantMap map = v.toMap();
      QJsonObject obj;
      for (auto mi = map.begin(); mi != map.end(); ++mi) {
        obj[mi.key()] = variantToJson(mi.value());
      }
      return QJsonValue(obj);
    } else if (v.canConvert<QVariantList>()) {
      QVariantList list = v.toList();
      QJsonArray arr;
      for (const QVariant &item : list) {
        arr.append(variantToJson(item));
      }
      return QJsonValue(arr);
    }
    return QJsonValue(v.toString());
  };

  QJsonObject varsObj;
  for (auto it = ctx.begin(); it != ctx.end(); ++it) {
    const QString &key = it.key();
    // Skip internal calculation metadata and intermediate quincena evaluation contexts (*_obj)
    if (key == "_history" || key.endsWith("_obj"))
      continue;
    QJsonValue jv = variantToJson(it.value());
    varsObj[key] = jv;
    rootObj[key] = jv;
  }
  rootObj["variables"] = varsObj;

  // 4. Conceptos con cell_id permanente (Overwrites input variables with final concept amounts)
  QJsonArray conceptosArr;
  QVariantList concList = result.value("conceptos").toList();
  for (const QVariant &c : concList) {
    QVariantMap cm = c.toMap();
    QJsonObject cObj;
    cObj["cell_id"] = cm.value("cell_id", cm.value("id", 0)).toInt();
    cObj["codigo"] = cm.value("codigo", cm.value("codigo_variable", "")).toString();
    cObj["descripcion"] = cm.value("descripcion", "").toString();
    cObj["seccion"] = cm.value("seccion", "").toString();
    cObj["monto"] = cm.value("monto", 0.0).toDouble();
    cObj["base"] = cm.value("base", 0.0).toDouble();
    cObj["unidad"] = cm.value("unidad", 0.0).toDouble();
    cObj["tipo_calculo"] = cm.value("tipo_calculo", "").toString();
    cObj["visible_recibo"] = cm.value("visible_recibo", 1).toInt();
    cObj["en_grafico"] = cm.value("en_grafico", 0).toInt();
    cObj["es_grafico_total"] = cm.value("es_grafico_total", 0).toInt();
    cObj["color_hex"] = cm.value("color_hex", "").toString();
    conceptosArr.append(cObj);

    // Concept amount ALWAYS overwrites input variable of same name
    QString code = cObj["codigo"].toString();
    if (!code.isEmpty()) {
      rootObj[code] = cObj["monto"].toDouble();
    }
  }
  rootObj["conceptos"] = conceptosArr;

  QString datosJson = QJsonDocument(rootObj).toJson(QJsonDocument::Compact);
  return m_db->saveReceipt(emp["id"].toInt(), esquema, mes, anio, periodo, datosJson, cierreId);
}

QVariantMap LiquidationEngine::validateBatch(int mes, int anio,
                                            const QString &esquemaTipo,
                                            const QString &quincena,
                                            const QString &fechaCierre,
                                            const QString &fechaPago)
{
  qInfo() << "[LiquidationEngine] Validando batch para esquema:" << esquemaTipo
          << "quincena:" << quincena << "mes:" << mes << "año:" << anio;

  QVariantList employees = m_db->listActiveEmployeesByTipo(esquemaTipo);
  QVariantList erroresPorEmpleado;
  QVariantList resultadosList;
  int procesados = 0;
  double totalNeto = 0.0;
  double totalRemunerativo = 0.0;
  double totalNoRemunerativo = 0.0;
  double totalDescuentos = 0.0;

  for (const QVariant &ev : employees) {
    QVariantMap emp = ev.toMap();
    int empId = emp["id"].toInt();

    // If jornal, check if employee has this quincena configured
    if (esquemaTipo == "jornal") {
      QStringList empQuincenas = m_db->listEmployeeQuincenas(empId);
      if (!empQuincenas.contains(quincena)) {
        continue;
      }
    }

    QVariantMap res = processLiquidation(empId, quincena, fechaCierre, fechaCierre, fechaPago);
    QVariantList errs = res.value("errores").toList();
    if (!errs.isEmpty()) {
      QVariantMap errItem;
      errItem["empleado_id"] = empId;
      errItem["legajo"] = emp.value("legajo").toString();
      errItem["nombre"] = emp.value("nombre_completo").toString();
      errItem["errores"] = errs;
      erroresPorEmpleado.append(errItem);
    }

    double empNeto = res.value("neto_a_cobrar").toDouble();
    if (empNeto == 0.0) {
      empNeto = res.value("total_remunerativo").toDouble() - res.value("total_descuentos").toDouble() + res.value("total_no_remunerativo").toDouble();
    }
    if (empNeto == 0.0) {
      for (const auto &c : res.value("conceptos").toList()) {
        empNeto += c.toMap().value("monto").toDouble();
      }
    }
    totalNeto += empNeto;
    totalRemunerativo += res.value("total_remunerativo").toDouble();
    totalNoRemunerativo += res.value("total_no_remunerativo").toDouble();
    totalDescuentos += res.value("total_descuentos").toDouble();
    procesados++;

    QVariantMap resItem;
    resItem["empleado_id"] = empId;
    resItem["legajo"] = emp.value("legajo").toString();
    resItem["nombre"] = emp.value("nombre_completo").toString();
    resItem["quincena"] = quincena;
    resItem["result"] = res;
    resultadosList.append(resItem);
  }

  QVariantMap result;
  result["valido"] = erroresPorEmpleado.isEmpty();
  result["empleados_procesados"] = procesados;
  result["total_neto"] = totalNeto;
  result["total_remunerativo"] = totalRemunerativo;
  result["total_no_remunerativo"] = totalNoRemunerativo;
  result["total_descuentos"] = totalDescuentos;
  result["errores_por_empleado"] = erroresPorEmpleado;
  result["resultados"] = resultadosList;

  return result;
}

QVariantMap LiquidationEngine::executeBatchClose(int mes, int anio,
                                                const QString &esquemaTipo,
                                                const QString &quincena,
                                                const QString &fechaCierre,
                                                const QString &fechaPago,
                                                const QString &exportPath)
{
  qInfo() << "[LiquidationEngine] Ejecutando cierre batch para esquema:" << esquemaTipo
          << "quincena:" << quincena << "mes:" << mes << "año:" << anio;

  // 1. Sequential & Status checks
  if (esquemaTipo == "jornal") {
    if (!m_db->canCloseQuincena(anio, mes, quincena)) {
      return {
          {"ok", false},
          {"mensaje", QString("No se puede cerrar la quincena %1. Verifique que la quincena previa esté cerrada y que no haya sido cerrada previamente.").arg(quincena)}
      };
    }
  } else {
    if (m_db->isCierreClosed(anio, mes, "M", "mensual")) {
      return {
          {"ok", false},
          {"mensaje", "El cierre mensual para este período ya se encuentra cerrado."}
      };
    }
  }

  // 2. Validate all calculations
  QVariantMap val = validateBatch(mes, anio, esquemaTipo, quincena, fechaCierre, fechaPago);
  if (!val.value("valido").toBool()) {
    return {
        {"ok", false},
        {"mensaje", "Existen errores de cálculo en uno o más empleados."},
        {"errores_por_empleado", val.value("errores_por_empleado")}
    };
  }

  // 3. Create pre-closing backup
  QString backupPath = m_db->createBackup();

  // 4. Build comprehensive snapshot JSON of this closing
  QJsonObject snapshot;
  QJsonObject metaObj;
  metaObj["anio"] = anio;
  metaObj["mes"] = mes;
  metaObj["tipo"] = (esquemaTipo == "jornal") ? quincena : "M";
  metaObj["esquema_tipo"] = esquemaTipo;
  metaObj["fecha_cierre"] = fechaCierre;
  metaObj["fecha_pago"] = fechaPago;
  metaObj["fecha_registro"] = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
  metaObj["backup_path"] = backupPath;
  snapshot["meta"] = metaObj;

  // Snapshot company
  QVariantMap comp = m_db->getCompany();
  QJsonObject compObj;
  compObj["razon_social"] = comp.value("razon_social").toString();
  compObj["cuit"] = comp.value("cuit").toString();
  compObj["direccion"] = comp.value("direccion").toString();
  compObj["lugar_de_pago"] = comp.value("lugar_de_pago").toString();
  snapshot["empresa"] = compObj;

  // Snapshot categories
  QJsonArray catsArr;
  QVariantList cats = m_db->listCategories();
  for (const QVariant &cv : cats) {
    QVariantMap c = cv.toMap();
    QJsonObject catObj;
    catObj["id"] = c["id"].toInt();
    catObj["nombre"] = c["nombre"].toString();
    catObj["valor_hora"] = c["valor_hora"].toDouble();
    catsArr.append(catObj);
  }
  snapshot["categorias"] = catsArr;

  // Snapshot global variables
  QJsonArray globalsArr;
  QVariantList globals = m_db->listGlobalVariables();
  for (const QVariant &gv : globals) {
    QVariantMap g = gv.toMap();
    QJsonObject gObj;
    gObj["id"] = g["id"].toInt();
    gObj["codigo"] = g["codigo"].toString();
    gObj["valor"] = g["valor"].toString();
    gObj["descripcion"] = g["descripcion"].toString();
    globalsArr.append(gObj);
  }
  snapshot["variables_globales"] = globalsArr;

  // Snapshot employees in this closing
  QJsonArray empsArr;
  QVariantList resultsList = val.value("resultados").toList();
  for (const QVariant &rv : resultsList) {
    QVariantMap item = rv.toMap();
    int empId = item["empleado_id"].toInt();
    QVariantMap empData = m_db->getEmployee(empId);
    QJsonObject eObj;
    eObj["id"] = empId;
    eObj["legajo"] = empData.value("legajo").toString();
    eObj["nombre_completo"] = empData.value("nombre_completo").toString();
    eObj["tipo_liquidacion"] = empData.value("tipo_liquidacion").toString();
    eObj["esquema_codigo"] = empData.value("esquema_codigo").toString();
    eObj["categoria_nombre"] = empData.value("categoria_nombre").toString();

    QVariantList fValues = m_db->getEmployeeFieldValues(empId, (esquemaTipo == "jornal") ? quincena : "Q1");
    QJsonArray fieldsArr;
    for (const QVariant &fv : fValues) {
      QVariantMap fm = fv.toMap();
      QJsonObject fObj;
      fObj["field_id"] = fm["field_id"].toInt();
      fObj["field_code"] = fm["field_code"].toString();
      fObj["value"] = fm["value"].toString();
      fieldsArr.append(fObj);
    }
    eObj["field_values"] = fieldsArr;
    empsArr.append(eObj);
  }
  snapshot["empleados"] = empsArr;

  QString snapshotJson = QJsonDocument(snapshot).toJson(QJsonDocument::Compact);

  // 5. Execute in atomic SQLite transaction
  m_db->transaction();

  QString tipoStr = (esquemaTipo == "jornal") ? quincena : "M";
  int cierreId = m_db->insertCierre(anio, mes, tipoStr, esquemaTipo, fechaCierre, fechaPago, snapshotJson, backupPath);
  if (cierreId <= 0) {
    m_db->rollback();
    return {
        {"ok", false},
        {"mensaje", "Error al registrar el cierre en la base de datos."}
    };
  }

  int receiptsPersisted = 0;
  int pdfsExported = 0;
  ExportService exportService(m_db);

  for (const QVariant &rv : resultsList) {
    QVariantMap item = rv.toMap();
    int empId = item["empleado_id"].toInt();
    QVariantMap res = item["result"].toMap();

    QString periodoStr = (esquemaTipo == "jornal")
                             ? QString("Mes %1/%2 (%3)").arg(mes).arg(anio).arg(quincena)
                             : QString("Mes %1/%2").arg(mes).arg(anio);

    int recId = persistLiquidation(res, mes, anio, periodoStr, fechaCierre, fechaPago, cierreId);
    if (recId <= 0) {
      m_db->rollback();
      return {
          {"ok", false},
          {"mensaje", QString("Error al guardar el recibo para el empleado ID %1").arg(empId)}
      };
    }
    receiptsPersisted++;

    if (!exportPath.isEmpty()) {
      QVariantMap empData = m_db->getEmployee(empId);
      QString legajo = empData.value("legajo", QString::number(empId)).toString();
      QString cleanPeriod = periodoStr;
      cleanPeriod.replace("/", "_").replace(" ", "_").replace("(", "").replace(")", "");
      QString pdfPath = QString("%1/Recibo_%2_%3.pdf").arg(exportPath, legajo, cleanPeriod);
      QString outPdf = exportService.exportReceiptPdf(res, comp, empData, pdfPath);
      if (!outPdf.isEmpty()) {
        pdfsExported++;
      }
    }
  }

  m_db->commit();

  qInfo() << "[LiquidationEngine] Cierre batch completado con éxito. Recibos:" << receiptsPersisted
          << "PDFs:" << pdfsExported << "Backup:" << backupPath;

  return {
      {"ok", true},
      {"cierre_id", cierreId},
      {"empleados_procesados", receiptsPersisted},
      {"pdfs_exportados", pdfsExported},
      {"backup_path", backupPath},
      {"mensaje", QString("Cierre completado exitosamente. Se generaron %1 recibos.").arg(receiptsPersisted)}
  };
}
