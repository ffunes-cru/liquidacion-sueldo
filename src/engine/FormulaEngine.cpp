#include "FormulaEngine.h"
#include <QDebug>
#include <cmath>

FormulaEngine::FormulaEngine(QObject *parent)
    : QObject(parent)
{
    m_engine = new QJSEngine(this);
    setupBuiltinFunctions();
}

FormulaEngine::~FormulaEngine()
{
}

void FormulaEngine::setupBuiltinFunctions()
{
    if (!m_engine) return;

    // Install Python-compatible built-in functions into the JS global scope.
    m_engine->evaluate(R"(
        function round(value, decimals) {
            if (typeof decimals === 'undefined') decimals = 0;
            var factor = Math.pow(10, decimals);
            return Math.round(value * factor) / factor;
        }

        function abs(x) { return Math.abs(x); }

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
    )");

    // int() and float() for Python compatibility
    // int() and float() for Python compatibility
    m_engine->evaluate(R"(
        function int_(x) { return Math.trunc(x); }

        var g = (typeof globalThis !== 'undefined' ? globalThis : this);

        function Q1(v) {
            var obj = g._Q1_obj || g.Q1_obj;
            if (obj && typeof obj[v] !== 'undefined') return Number(obj[v]) || 0;
            if (obj && typeof obj['Q1_' + v] !== 'undefined') return Number(obj['Q1_' + v]) || 0;
            if (typeof g['Q1_' + v] !== 'undefined') return Number(g['Q1_' + v]) || 0;
            return 0;
        }

        function Q2(v) {
            var obj = g._Q2_obj || g.Q2_obj;
            if (obj && typeof obj[v] !== 'undefined') return Number(obj[v]) || 0;
            if (obj && typeof obj['Q2_' + v] !== 'undefined') return Number(obj['Q2_' + v]) || 0;
            if (typeof g['Q2_' + v] !== 'undefined') return Number(g['Q2_' + v]) || 0;
            return 0;
        }

        function Q_sum(v) {
            var total = 0, count = 0;
            var obj1 = g._Q1_obj || g.Q1_obj;
            if (obj1 && typeof obj1[v] !== 'undefined') { total += Number(obj1[v]) || 0; count++; }
            var obj2 = g._Q2_obj || g.Q2_obj;
            if (obj2 && typeof obj2[v] !== 'undefined') { total += Number(obj2[v]) || 0; count++; }

            for (var k in g) {
                if (k !== '_Q1_obj' && k !== '_Q2_obj' && k !== 'Q1_obj' && k !== 'Q2_obj' && k.match(/^_?Q\d+_obj$/)) {
                    var obj = g[k];
                    if (obj && typeof obj[v] !== 'undefined') { total += Number(obj[v]) || 0; count++; }
                }
            }
            if (count === 0 && typeof g[v] !== 'undefined') return Number(g[v]) || 0;
            return total;
        }

        function Q_sum_(v) { return Q_sum(v); }
        function sumar_q(v) { return Q_sum(v); }

        function Q_avg(v) {
            var total = 0, count = 0;
            var obj1 = g._Q1_obj || g.Q1_obj;
            if (obj1 && typeof obj1[v] !== 'undefined') { total += Number(obj1[v]) || 0; count++; }
            var obj2 = g._Q2_obj || g.Q2_obj;
            if (obj2 && typeof obj2[v] !== 'undefined') { total += Number(obj2[v]) || 0; count++; }

            for (var k in g) {
                if (k !== '_Q1_obj' && k !== '_Q2_obj' && k !== 'Q1_obj' && k !== 'Q2_obj' && k.match(/^_?Q\d+_obj$/)) {
                    var obj = g[k];
                    if (obj && typeof obj[v] !== 'undefined') { total += Number(obj[v]) || 0; count++; }
                }
            }
            return count > 0 ? total / count : (typeof g[v] !== 'undefined' ? Number(g[v]) || 0 : 0);
        }

        function Q_avg_(v) { return Q_avg(v); }
        function promedio_q(v) { return Q_avg(v); }

        function Q_max(v) {
            var maxVal = -Infinity, count = 0;
            var obj1 = g._Q1_obj || g.Q1_obj;
            if (obj1 && typeof obj1[v] !== 'undefined') { maxVal = Math.max(maxVal, Number(obj1[v]) || 0); count++; }
            var obj2 = g._Q2_obj || g.Q2_obj;
            if (obj2 && typeof obj2[v] !== 'undefined') { maxVal = Math.max(maxVal, Number(obj2[v]) || 0); count++; }

            for (var k in g) {
                if (k !== '_Q1_obj' && k !== '_Q2_obj' && k !== 'Q1_obj' && k !== 'Q2_obj' && k.match(/^_?Q\d+_obj$/)) {
                    var obj = g[k];
                    if (obj && typeof obj[v] !== 'undefined') { maxVal = Math.max(maxVal, Number(obj[v]) || 0); count++; }
                }
            }
            return count > 0 ? maxVal : (typeof g[v] !== 'undefined' ? Number(g[v]) || 0 : 0);
        }

        function Q_max_(v) { return Q_max(v); }
        function max_q(v) { return Q_max(v); }

        function Q_min(v) {
            var minVal = Infinity, count = 0;
            var obj1 = g._Q1_obj || g.Q1_obj;
            if (obj1 && typeof obj1[v] !== 'undefined') { minVal = Math.min(minVal, Number(obj1[v]) || 0); count++; }
            var obj2 = g._Q2_obj || g.Q2_obj;
            if (obj2 && typeof obj2[v] !== 'undefined') { minVal = Math.min(minVal, Number(obj2[v]) || 0); count++; }

            for (var k in g) {
                if (k !== '_Q1_obj' && k !== '_Q2_obj' && k !== 'Q1_obj' && k !== 'Q2_obj' && k.match(/^_?Q\d+_obj$/)) {
                    var obj = g[k];
                    if (obj && typeof obj[v] !== 'undefined') { minVal = Math.min(minVal, Number(obj[v]) || 0); count++; }
                }
            }
            return count > 0 ? minVal : (typeof g[v] !== 'undefined' ? Number(g[v]) || 0 : 0);
        }

        function Q_min_(v) { return Q_min(v); }
        function min_q(v) { return Q_min(v); }

        function H_list(v, limit) {
            if (typeof _history === 'undefined' || !Array.isArray(_history)) return [];
            var n = limit || _history.length;
            var res = [];
            for (var i = 0; i < Math.min(n, _history.length); i++) {
                var item = _history[i];
                if (item && typeof item[v] !== 'undefined') res.push(Number(item[v]) || 0);
            }
            return res;
        }

        function H_sum(v, limit) {
            var arr = H_list(v, limit), s = 0;
            for (var i = 0; i < arr.length; i++) s += arr[i];
            return s;
        }

        function H_max(v, limit) {
            var arr = H_list(v, limit);
            if (arr.length === 0) return 0;
            var m = -Infinity;
            for (var i = 0; i < arr.length; i++) if (arr[i] > m) m = arr[i];
            return m;
        }

        function H_avg(v, limit) {
            var arr = H_list(v, limit);
            if (arr.length === 0) return 0;
            var s = 0;
            for (var i = 0; i < arr.length; i++) s += arr[i];
            return s / arr.length;
        }

        function H_val(v, offset) {
            var arr = H_list(v, (offset || 1) + 1);
            var idx = (offset || 1) - 1;
            return (idx >= 0 && idx < arr.length) ? arr[idx] : 0;
        }
    )");
}

void FormulaEngine::setContext(const QVariantMap &context)
{
    m_context = context;
    m_contextDirty = true;
}

void FormulaEngine::setVariable(const QString &name, const QVariant &value)
{
    m_context[name] = value;
    m_contextDirty = true;
}

QVariant FormulaEngine::getVariable(const QString &name) const
{
    return m_context.value(name);
}

void FormulaEngine::registerFunction(const QString &name, QJSValue callable)
{
    if (m_engine) {
        m_engine->globalObject().setProperty(name, callable);
    }
}

void FormulaEngine::syncContextToEngine()
{
    if (!m_contextDirty || !m_engine) return;

    QJSValue global = m_engine->globalObject();
    static const QSet<QString> protectedFuncNames = {
        "Q1", "Q2", "Q_sum", "Q_sum_", "Q_avg", "Q_avg_", "Q_max", "Q_max_", "Q_min", "Q_min_",
        "sumar_q", "promedio_q", "max_q", "min_q", "cant_q",
        "H_list", "H_sum", "H_max", "H_avg", "H_val", "round", "abs", "min", "max", "int_"
    };

    for (auto it = m_context.begin(); it != m_context.end(); ++it) {
        const QString &key = it.key();
        const QVariant &val = it.value();

        if (protectedFuncNames.contains(key)) {
            if (val.canConvert<QVariantMap>()) {
                QJSValue obj = m_engine->newObject();
                QVariantMap map = val.toMap();
                for (auto mi = map.begin(); mi != map.end(); ++mi) {
                    if (mi.value().canConvert<double>()) {
                        obj.setProperty(mi.key(), mi.value().toDouble());
                    } else {
                        obj.setProperty(mi.key(), mi.value().toString());
                    }
                }
                global.setProperty("_" + key + "_obj", obj);
                global.setProperty(key + "_obj", obj);
            }
            continue;
        }

        if (val.typeId() == QMetaType::Bool) {
            global.setProperty(key, val.toBool());
        } else if (val.typeId() == QMetaType::Int || val.typeId() == QMetaType::LongLong) {
            global.setProperty(key, val.toDouble());
        } else if (val.typeId() == QMetaType::Double || val.typeId() == QMetaType::Float) {
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
            QJSValue obj = m_engine->newObject();
            QVariantMap map = val.toMap();
            for (auto mi = map.begin(); mi != map.end(); ++mi) {
                if (mi.value().canConvert<double>()) {
                    obj.setProperty(mi.key(), mi.value().toDouble());
                } else {
                    obj.setProperty(mi.key(), mi.value().toString());
                }
            }
            global.setProperty(key, obj);
        } else {
            global.setProperty(key, m_engine->toScriptValue(val));
        }
    }

    m_contextDirty = false;
}

QVariant FormulaEngine::evaluate(const QString &formula, QString *error)
{
    if (formula.trimmed().isEmpty() || !m_engine) {
        return 0.0;
    }

    syncContextToEngine();

    QString expr = formula.trimmed();

    // 1. Transpile Python ternary: A if COND else B  ->  ((COND) ? (A) : (B))
    QRegularExpression pythonTernaryRegex(R"(^\s*(.+?)\s+if\s+(.+?)\s+else\s+(.+)\s*$)");
    QRegularExpressionMatch ternaryMatch = pythonTernaryRegex.match(expr);
    if (ternaryMatch.hasMatch()) {
        QString trueVal = ternaryMatch.captured(1).trimmed();
        QString condVal = ternaryMatch.captured(2).trimmed();
        QString falseVal = ternaryMatch.captured(3).trimmed();

        condVal.replace(QRegularExpression(R"(\bor\b)"), "||");
        condVal.replace(QRegularExpression(R"(\band\b)"), "&&");
        condVal.replace(QRegularExpression(R"(\bnot\b)"), "!");

        expr = QString("((%1) ? (%2) : (%3))").arg(condVal, trueVal, falseVal);
    } else {
        expr.replace(QRegularExpression(R"(\bor\b)"), "||");
        expr.replace(QRegularExpression(R"(\band\b)"), "&&");
        expr.replace(QRegularExpression(R"(\bnot\b)"), "!");
    }

    // 2. Auto-initialize undefined identifiers to 0.0 to prevent ReferenceErrors
    QJSValue global = m_engine->globalObject();
    static const QSet<QString> jsKeywords = {
        "if", "else", "true", "false", "True", "False", "null", "undefined", "return", "function", "var", "let", "const",
        "round", "abs", "min", "max", "int_", "Q1", "Q2", "Q_sum", "Q_sum_", "Q_avg", "Q_avg_", "Q_max", "Q_max_", "Q_min", "Q_min_",
        "sumar_q", "promedio_q", "max_q", "min_q", "cant_q",
        "H_list", "H_sum", "H_max", "H_avg", "H_val", "Math", "Number", "Array", "Object", "String", "_history"
    };

    static const QRegularExpression identRegex(R"(\b[A-Za-z_][A-Za-z0-9_]*\b)");
    QRegularExpressionMatchIterator it = identRegex.globalMatch(expr);
    while (it.hasNext()) {
        QRegularExpressionMatch match = it.next();
        QString varName = match.captured(0);
        if (!jsKeywords.contains(varName) && !global.hasProperty(varName)) {
            global.setProperty(varName, 0.0);
        }
    }

    QJSValue result = m_engine->evaluate(expr);

    if (result.isError()) {
        QString errMsg = result.toString();
        if (error) *error = errMsg;
        qWarning() << "Formula evaluation error:" << formula << "(Expr:" << expr << ") ->" << errMsg;
        return 0.0;
    }

    if (result.isBool()) {
        return result.toBool();
    }
    if (result.isNumber()) {
        return result.toNumber();
    }
    if (result.isString()) {
        return result.toString();
    }

    return result.toVariant();
}

bool FormulaEngine::evaluateCondition(const QString &condition, QString *error)
{
    if (condition.trimmed().isEmpty()) {
        return true;
    }

    QVariant result = evaluate(condition, error);
    return result.toBool();
}

void FormulaEngine::reset()
{
    m_context.clear();
    m_contextDirty = true;

    if (m_engine) {
        delete m_engine;
    }
    m_engine = new QJSEngine(this);
    setupBuiltinFunctions();
}
