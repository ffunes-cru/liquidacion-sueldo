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
    m_engine->evaluate(R"(
        function int_(x) { return Math.trunc(x); }
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
    return m_context.value(name, 0.0);
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

    for (auto it = m_context.begin(); it != m_context.end(); ++it) {
        const QVariant &val = it.value();

        if (val.typeId() == QMetaType::Bool) {
            global.setProperty(it.key(), val.toBool());
        } else if (val.typeId() == QMetaType::Int || val.typeId() == QMetaType::LongLong) {
            global.setProperty(it.key(), val.toDouble());
        } else if (val.typeId() == QMetaType::Double || val.typeId() == QMetaType::Float) {
            global.setProperty(it.key(), val.toDouble());
        } else if (val.typeId() == QMetaType::QString) {
            bool ok;
            double d = val.toDouble(&ok);
            if (ok) {
                global.setProperty(it.key(), d);
            } else {
                QString s = val.toString().toLower();
                if (s == "true") {
                    global.setProperty(it.key(), true);
                } else if (s == "false") {
                    global.setProperty(it.key(), false);
                } else {
                    global.setProperty(it.key(), val.toString());
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
            global.setProperty(it.key(), obj);
        } else {
            global.setProperty(it.key(), m_engine->toScriptValue(val));
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

    QJSValue result = m_engine->evaluate(formula);

    if (result.isError()) {
        QString errMsg = result.toString();
        if (error) *error = errMsg;
        qWarning() << "Formula evaluation error:" << formula << "->" << errMsg;
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
