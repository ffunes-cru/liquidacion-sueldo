#ifndef FORMULAENGINE_H
#define FORMULAENGINE_H

#include <QObject>
#include <QJSEngine>
#include <QJSValue>
#include <QVariantMap>
#include <QString>

/**
 * @brief Wrapper around QJSEngine for evaluating payroll formulas safely.
 *
 * Supports:
 * - Basic math: +, -, *, /, %
 * - Built-in functions: round, max, min, abs, int, float
 * - Custom functions: sumar_q, promedio_q, max_q, min_q, cant_q
 * - Historical functions: sumatoria_mes, maximo_semestre, etc.
 * - Dynamic variable resolution via context
 */
class FormulaEngine : public QObject
{
    Q_OBJECT

public:
    explicit FormulaEngine(QObject *parent = nullptr);
    ~FormulaEngine();

    /// Set the evaluation context (variable name -> value)
    void setContext(const QVariantMap &context);

    /// Update a single variable in the current context
    void setVariable(const QString &name, const QVariant &value);

    /// Get a variable from the current context
    QVariant getVariable(const QString &name) const;

    /// Register a callable JS function in the engine
    void registerFunction(const QString &name, QJSValue callable);

    /// Evaluate a formula string and return the result
    QVariant evaluate(const QString &formula, QString *error = nullptr);

    /// Evaluate a boolean condition
    bool evaluateCondition(const QString &condition, QString *error = nullptr);

    /// Clear all variables and reset the engine
    void reset();

private:
    void setupBuiltinFunctions();
    void syncContextToEngine();

    QJSEngine *m_engine = nullptr;
    QVariantMap m_context;
    bool m_contextDirty = true;
};

#endif // FORMULAENGINE_H
