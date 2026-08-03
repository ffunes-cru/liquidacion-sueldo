/*
 * Sistema de Liquidación de Sueldos
 * Copyright (C) 2026
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#ifndef FORMULAENGINE_H
#define FORMULAENGINE_H

#include <QJSEngine>
#include <QJSValue>
#include <QObject>
#include <QRegularExpression>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

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
class FormulaEngine : public QObject {
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

  /// Register custom user-defined functions from DB
  void registerCustomFunctions(const QVariantList &functions);

  /// Set the 'env' global object for user functions
  void setEnvObject(const QVariantMap &envData);

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
