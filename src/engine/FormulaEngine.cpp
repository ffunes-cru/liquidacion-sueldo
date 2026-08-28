#include "FormulaEngine.h"
#include <QDebug>
#include <cmath>
#include <functional>

FormulaEngine::FormulaEngine(QObject *parent) : QObject(parent) {
  m_engine = new QJSEngine(this);
  setupBuiltinFunctions();
}

FormulaEngine::~FormulaEngine() {}

void FormulaEngine::setupBuiltinFunctions() {
  if (!m_engine)
    return;

  // Install Python-compatible built-in functions into the JS global scope.
  m_engine->evaluate(R"(
        function round(value, decimals) {
            if (typeof decimals === 'undefined') decimals = 0;
            var factor = Math.pow(10, decimals);
            return Math.round(value * factor) / factor;
        }

        function abs(x) { return Math.abs(x); }
        function floor(x) { return Math.floor(x); }
        function ceil(x) { return Math.ceil(x); }
        function int_(x) { return Math.trunc(x); }

        // Python-compatible True/False
        var True = true;
        var False = false;
    )");

  // max() and min() with variable arguments (Python-style)
  m_engine->evaluate(R"(
        function max() {
            var args = Array.prototype.slice.call(arguments);
            if (args.length === 0) return 0;
            return Math.max.apply(null, args);
        }
        function min() {
            var args = Array.prototype.slice.call(arguments);
            if (args.length === 0) return 0;
            return Math.min.apply(null, args);
        }

        function Q_sum_(varName) {
            if (typeof env !== 'undefined' && env.quincenas && Array.isArray(env.quincenas)) {
                return env.quincenas.reduce(function(acc, q) { return acc + (Number(q[varName]) || 0); }, 0);
            }
            return typeof this['Q_sum_' + varName] !== 'undefined' ? this['Q_sum_' + varName] : 0;
        }
        function Q_avg_(varName) {
            if (typeof env !== 'undefined' && env.quincenas && Array.isArray(env.quincenas) && env.quincenas.length > 0) {
                return Q_sum_(varName) / env.quincenas.length;
            }
            return typeof this['Q_avg_' + varName] !== 'undefined' ? this['Q_avg_' + varName] : 0;
        }
        function Q_max_(varName) {
            if (typeof env !== 'undefined' && env.quincenas && Array.isArray(env.quincenas) && env.quincenas.length > 0) {
                var vals = env.quincenas.map(function(q) { return Number(q[varName]) || 0; });
                return Math.max.apply(null, vals);
            }
            return typeof this['Q_max_' + varName] !== 'undefined' ? this['Q_max_' + varName] : 0;
        }
        function Q_min_(varName) {
            if (typeof env !== 'undefined' && env.quincenas && Array.isArray(env.quincenas) && env.quincenas.length > 0) {
                var vals = env.quincenas.map(function(q) { return Number(q[varName]) || 0; });
                return Math.min.apply(null, vals);
            }
            return typeof this['Q_min_' + varName] !== 'undefined' ? this['Q_min_' + varName] : 0;
        }
        function sumar_q(varName) { return Q_sum_(varName); }
        function promedio_q(varName) { return Q_avg_(varName); }
        function max_q(varName) { return Q_max_(varName); }
        function min_q(varName) { return Q_min_(varName); }
        function cant_q() {
            if (typeof env !== 'undefined' && env.quincenas && Array.isArray(env.quincenas)) {
                return env.quincenas.length;
            }
            return typeof _cant_q !== 'undefined' ? _cant_q : 1;
        }
    )");
}

void FormulaEngine::evaluateScript(const QString &script) {
  if (m_engine) {
    m_engine->evaluate(script);
  }
}

void FormulaEngine::setContext(const QVariantMap &context) {
  m_context = context;
  m_contextDirty = true;
}

void FormulaEngine::setVariable(const QString &name, const QVariant &value) {
  m_context[name] = value;
  m_contextDirty = true;
}

QVariant FormulaEngine::getVariable(const QString &name) const {
  return m_context.value(name);
}

void FormulaEngine::registerFunction(const QString &name, QJSValue callable) {
  if (m_engine) {
    m_engine->globalObject().setProperty(name, callable);
  }
}

// Helper: convert a QVariantMap to a QJSValue object
static QJSValue variantMapToJSObject(QJSEngine *engine,
                                     const QVariantMap &map) {
  QJSValue obj = engine->newObject();
  for (auto mi = map.begin(); mi != map.end(); ++mi) {
    const QVariant &v = mi.value();
    if (v.typeId() == QMetaType::Bool) {
      obj.setProperty(mi.key(), v.toBool());
    } else if (v.canConvert<double>()) {
      bool ok;
      double d = v.toDouble(&ok);
      if (ok)
        obj.setProperty(mi.key(), d);
      else
        obj.setProperty(mi.key(), v.toString());
    } else if (v.canConvert<QVariantMap>()) {
      obj.setProperty(mi.key(), variantMapToJSObject(engine, v.toMap()));
    } else if (v.canConvert<QVariantList>()) {
      QVariantList list = v.toList();
      QJSValue arr = engine->newArray(list.size());
      for (int i = 0; i < list.size(); i++) {
        if (list[i].canConvert<QVariantMap>()) {
          arr.setProperty(i, variantMapToJSObject(engine, list[i].toMap()));
        } else if (list[i].canConvert<double>()) {
          arr.setProperty(i, list[i].toDouble());
        } else {
          arr.setProperty(i, list[i].toString());
        }
      }
      obj.setProperty(mi.key(), arr);
    } else {
      obj.setProperty(mi.key(), v.toString());
    }
  }
  return obj;
}

// Helper: convert a QVariantList to a QJSValue array
static QJSValue variantListToJSArray(QJSEngine *engine,
                                     const QVariantList &list) {
  QJSValue arr = engine->newArray(list.size());
  for (int i = 0; i < list.size(); i++) {
    const QVariant &item = list[i];
    if (item.canConvert<QVariantMap>()) {
      arr.setProperty(i, variantMapToJSObject(engine, item.toMap()));
    } else if (item.typeId() == QMetaType::Bool) {
      arr.setProperty(i, item.toBool());
    } else if (item.canConvert<double>()) {
      arr.setProperty(i, item.toDouble());
    } else {
      arr.setProperty(i, item.toString());
    }
  }
  return arr;
}

void FormulaEngine::syncContextToEngine() {
  if (!m_contextDirty || !m_engine)
    return;

  QJSValue global = m_engine->globalObject();
  static const QSet<QString> protectedFuncNames = {
      "Q1",     "Q2",     "Q_sum",  "Q_sum_",  "Q_avg",      "Q_avg_", "Q_max",
      "Q_max_", "Q_min",  "Q_min_", "sumar_q", "promedio_q", "max_q",  "min_q",
      "cant_q", "H_list", "H_sum",  "H_max",   "H_avg",      "H_val",  "round",
      "abs",    "min",    "max",    "int_",    "env"};

  for (auto it = m_context.begin(); it != m_context.end(); ++it) {
    const QString &key = it.key();
    const QVariant &val = it.value();

    // Protected function names that are also QVariantMaps → inject as _X_obj /
    // X_obj
    if (protectedFuncNames.contains(key)) {
      if (val.canConvert<QVariantMap>()) {
        QJSValue obj = variantMapToJSObject(m_engine, val.toMap());
        global.setProperty("_" + key + "_obj", obj);
        global.setProperty(key + "_obj", obj);
      }
      continue;
    }

    // Keys ending in _obj → treat as JS objects (e.g. Q1_obj, Q2_obj)
    if (key.endsWith("_obj") && val.canConvert<QVariantMap>()) {
      QJSValue obj = variantMapToJSObject(m_engine, val.toMap());
      global.setProperty(key, obj);
      // Also set with underscore prefix for the JS lookup functions
      global.setProperty("_" + key, obj);
      continue;
    }

    // QVariantList → convert to native JS Array (critical for _history)
    if (val.canConvert<QVariantList>() && val.typeId() != QMetaType::QString &&
        val.typeId() != QMetaType::QVariantMap) {
      QVariantList list = val.toList();
      if (!list.isEmpty()) {
        QJSValue arr = variantListToJSArray(m_engine, list);
        global.setProperty(key, arr);
        continue;
      }
    }

    if (val.typeId() == QMetaType::Bool) {
      global.setProperty(key, val.toBool());
    } else if (val.typeId() == QMetaType::Int ||
               val.typeId() == QMetaType::LongLong) {
      global.setProperty(key, val.toDouble());
    } else if (val.typeId() == QMetaType::Double ||
               val.typeId() == QMetaType::Float) {
      global.setProperty(key, val.toDouble());
    } else if (val.typeId() == QMetaType::QString) {
      bool ok;
      double d = val.toDouble(&ok);
      if (ok) {
        global.setProperty(key, d);
      } else {
        QString s = val.toString().toLower();
        if (s == "true") {
          global.setProperty(key, true);
        } else if (s == "false") {
          global.setProperty(key, false);
        } else {
          global.setProperty(key, val.toString());
        }
      }
    } else if (val.canConvert<QVariantMap>()) {
      QJSValue obj = variantMapToJSObject(m_engine, val.toMap());
      global.setProperty(key, obj);
    } else {
      global.setProperty(key, m_engine->toScriptValue(val));
    }
  }

  m_contextDirty = false;
}

QVariant FormulaEngine::evaluate(const QString &formula, QString *error) {
  if (formula.trimmed().isEmpty() || !m_engine) {
    return 0.0;
  }

  syncContextToEngine();

  QString expr = formula.trimmed();

  // 1. Transpile Python ternary: A if COND else B  ->  ((COND) ? (A) : (B))
  //    Strategy: Process parenthesized sub-expressions first (innermost out),
  //    then handle top-level ternaries. This correctly handles embedded cases like:
  //    (100 if a > 5 else 50) + (200 if b > 15 else 75)
  //    basico * (0.10 if antiguedad > 5 else 0.05)
  {
    // Helper lambda: transpile a flat ternary expression (no nested parens).
    // Handles chaining by recursively processing the else-branch first.
    std::function<QString(QString)> transpileFlatTernary;
    transpileFlatTernary = [&transpileFlatTernary](QString s) -> QString {
      s = s.trimmed();
      QRegularExpression ternaryRe(R"(^\s*(.+?)\s+if\s+(.+?)\s+else\s+(.+)\s*$)");
      QRegularExpressionMatch m = ternaryRe.match(s);
      if (!m.hasMatch()) return s;

      QString trueVal = m.captured(1).trimmed();
      QString condVal = m.captured(2).trimmed();
      QString falseVal = m.captured(3).trimmed();

      // Recursively transpile the else-branch (handles chaining: a if c1 else b if c2 else d)
      falseVal = transpileFlatTernary(falseVal);

      condVal.replace(QRegularExpression(R"(\bor\b)"), "||");
      condVal.replace(QRegularExpression(R"(\band\b)"), "&&");
      condVal.replace(QRegularExpression(R"(\bnot\b)"), "!");
      return QString("((%1) ? (%2) : (%3))").arg(condVal, trueVal, falseVal);
    };

    // Iteratively resolve innermost parenthesized groups containing ternaries
    int safetyLimit = 30;
    while (safetyLimit-- > 0) {
      // Find innermost parenthesized group that contains ' if ' and ' else '
      int bestStart = -1, bestEnd = -1;
      int depth = 0;
      QVector<int> openStack;
      for (int i = 0; i < expr.length(); i++) {
        if (expr[i] == '(') {
          openStack.push_back(i);
          depth++;
        } else if (expr[i] == ')') {
          if (!openStack.isEmpty()) {
            int start = openStack.takeLast();
            depth--;
            // Check if this group contains a Python ternary
            QString inner = expr.mid(start + 1, i - start - 1);
            if (inner.contains(QRegularExpression(R"(\s+if\s+.*\s+else\s+)"))) {
              bestStart = start;
              bestEnd = i;
              break;  // Process innermost first
            }
          }
        }
      }

      if (bestStart >= 0 && bestEnd > bestStart) {
        // Extract the inner content, transpile it, and replace
        QString inner = expr.mid(bestStart + 1, bestEnd - bestStart - 1);
        QString transpiled = transpileFlatTernary(inner);
        expr = expr.left(bestStart) + "(" + transpiled + ")" + expr.mid(bestEnd + 1);
      } else {
        // No more parenthesized ternaries; try top-level
        if (expr.contains(QRegularExpression(R"(\s+if\s+.*\s+else\s+)"))) {
          expr = transpileFlatTernary(expr);
        }
        break;
      }
    }
  }

  // Replace Python logical operators outside of ternary context
  expr.replace(QRegularExpression(R"(\bor\b)"), "||");
  expr.replace(QRegularExpression(R"(\band\b)"), "&&");
  expr.replace(QRegularExpression(R"(\bnot\b)"), "!");

  // 2. Auto-initialize undefined identifiers to 0.0 to prevent ReferenceErrors
  //    BUT skip identifiers that appear inside quoted strings (arguments to
  //    Q1(), H_sum(), etc.) and skip property accesses (e.g. env.quincenas, Math.max)
  QJSValue global = m_engine->globalObject();
  static const QSet<QString> jsKeywords = {
      "if",     "else",      "true",     "false",    "True",    "False",
      "null",   "undefined", "return",   "function", "var",     "let",
      "const",  "round",     "abs",      "min",      "max",     "floor",   "ceil",
      "int_",   "Math",      "Number",   "Array",    "Object",  "String",  "env",
      "typeof", "for",       "while",    "do",       "break",   "continue","new",
      "this",   "in",        "of",       "length",   "push",    "pop",
      "forEach","map",       "filter",   "reduce",   "indexOf", "isArray",
      // Helper functions registered by LiquidationEngine
      "Q_sum_", "Q_avg_",    "Q_max_",   "Q_min_",   "sumar_q", "promedio_q",
      "max_q",  "min_q",     "cant_q",   "_cant_q",  "varName", "arguments",
      "Q1",     "Q2",        "H_list",   "H_sum",    "H_max",   "H_avg",  "H_val"};

  // Build a set of character positions that are inside quoted strings,
  // correctly handling escaped quotes (\' and \")
  QSet<int> quotedPositions;
  bool inSingle = false, inDouble = false;
  for (int i = 0; i < expr.length(); i++) {
    QChar c = expr[i];
    // Skip escaped quotes
    if (c == '\\' && i + 1 < expr.length()) {
      quotedPositions.insert(i);
      quotedPositions.insert(i + 1);
      i++;  // skip next character
      continue;
    }
    if (c == '\'' && !inDouble)
      inSingle = !inSingle;
    else if (c == '"' && !inSingle)
      inDouble = !inDouble;
    if (inSingle || inDouble)
      quotedPositions.insert(i);
  }

  static const QRegularExpression identRegex(R"(\b[A-Za-z_][A-Za-z0-9_]*\b)");
  QRegularExpressionMatchIterator it = identRegex.globalMatch(expr);
  while (it.hasNext()) {
    QRegularExpressionMatch match = it.next();
    int pos = match.capturedStart(0);
    // Skip identifiers inside quoted strings
    if (quotedPositions.contains(pos))
      continue;

    // Skip property accesses: if preceded by a dot (e.g. env.quincenas, Math.max)
    if (pos > 0 && expr[pos - 1] == '.')
      continue;

    QString varName = match.captured(0);
    if (!jsKeywords.contains(varName) && !global.hasProperty(varName)) {
      global.setProperty(varName, 0.0);
      m_autoInitialized.insert(varName);
      qWarning() << "[FormulaEngine] Variable no definida auto-inicializada a 0.0:"
                 << varName << "en fórmula:" << formula;
    }
  }

  QJSValue result = m_engine->evaluate(expr);

  if (result.isError()) {
    QString errMsg = result.toString();
    if (error)
      *error = errMsg;
    qWarning() << "Formula evaluation error:" << formula << "(Expr:" << expr
               << ") ->" << errMsg;
    return 0.0;
  }

  if (result.isBool()) {
    return result.toBool();
  }
  if (result.isNumber()) {
    double num = result.toNumber();
    if (std::isnan(num) || std::isinf(num)) {
      return 0.0;
    }
    return num;
  }
  if (result.isString()) {
    return result.toString();
  }

  return result.toVariant();
}

bool FormulaEngine::evaluateCondition(const QString &condition,
                                      QString *error) {
  if (condition.trimmed().isEmpty()) {
    return true;
  }

  QVariant result = evaluate(condition, error);
  return result.toBool();
}

void FormulaEngine::reset() {
  m_context.clear();
  m_contextDirty = true;
  m_autoInitialized.clear();

  if (m_engine) {
    delete m_engine;
  }
  m_engine = new QJSEngine(this);
  setupBuiltinFunctions();
}

QStringList FormulaEngine::autoInitializedVars() const {
  return QStringList(m_autoInitialized.begin(), m_autoInitialized.end());
}

void FormulaEngine::clearAutoInitializedVars() {
  m_autoInitialized.clear();
}

void FormulaEngine::registerCustomFunctions(const QVariantList &functions) {
  if (!m_engine)
    return;

  for (const QVariant &f : functions) {
    QVariantMap func = f.toMap();
    QString name = func["name"].toString().trimmed();
    QString params = func["params"].toString().trimmed();
    QString body = func["body"].toString().trimmed();

    if (name.isEmpty() || body.isEmpty())
      continue;

    // Validate name is a valid JS identifier
    static const QRegularExpression validIdent(R"(^[A-Za-z_][A-Za-z0-9_]*$)");
    if (!validIdent.match(name).hasMatch()) {
      qWarning()
          << "[FormulaEngine] Custom function name is not a valid identifier:"
          << name;
      continue;
    }

    // Build JS function definition
    QString jsFunc =
        QString("function %1(%2) {\n%3\n}").arg(name, params, body);

    QJSValue result = m_engine->evaluate(jsFunc);
    if (result.isError()) {
      qWarning() << "[FormulaEngine] Error registering custom function" << name
                 << ":" << result.toString();
    } else {
      qInfo() << "[FormulaEngine] Registered custom function:" << name << "("
              << params << ")";
    }
  }
}

void FormulaEngine::setEnvObject(const QVariantMap &envData) {
  if (!m_engine)
    return;

  QJSValue envObj = variantMapToJSObject(m_engine, envData);
  m_engine->globalObject().setProperty("env", envObj);
}
