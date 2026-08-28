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

#ifndef LIQUIDATIONENGINE_H
#define LIQUIDATIONENGINE_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class DatabaseManager;
class FormulaEngine;
class QuincenaAggregator;

/**
 * @brief Orchestrates the complete payroll liquidation for an employee.
 *
 * Sequence:
 * 1. Calculate seniority from dates
 * 2. Inject global variables (with quincena namespace resolution)
 * 3. Inject employee field values from schema_fields/employee_field_values
 * 4. Pre-compute all quincenas for aggregation functions
 * 5. Evaluate all calculation cells sequentially
 * 6. Evaluate chart cells
 * 7. Return complete result
 */
class LiquidationEngine : public QObject {
  Q_OBJECT

public:
  explicit LiquidationEngine(DatabaseManager *db, QObject *parent = nullptr);

  /**
   * @brief Process the complete liquidation for an employee.
   * @param employeeId The employee ID
   * @param quincenaSel Selected quincena (for jornaleros), or empty for monthly
   * @param fechaCalculo Calculation date (YYYY-MM-DD), defaults to today
   * @return QVariantMap with keys:
   *   - "empleado": employee data
   *   - "resultados_por_seccion": { sectionCode: [{codigo, descripcion, unidad,
   * base, monto, visible_recibo}] }
   *   - "resultados_grafico": [{etiqueta, valor}]
   *   - "contexto_final": all computed variables
   *   - "errores": [error strings]
   *   - "quincena_sel": selected quincena
   */
  Q_INVOKABLE QVariantMap processLiquidation(int employeeId,
                                              const QString &quincenaSel = "",
                                              const QString &fechaCalculo = "",
                                              const QString &fechaCierre = "",
                                              const QString &fechaPago = "");

  /**
   * @brief Persist the current liquidation result as a receipt snapshot.
   */
  Q_INVOKABLE int persistLiquidation(const QVariantMap &result, int mes,
                                      int anio, const QString &periodo,
                                      const QString &fechaCierre = "",
                                      const QString &fechaPago = "",
                                      int cierreId = 0);

  /**
   * @brief Validate batch liquidation for a specific schema type and quincena.
   */
  Q_INVOKABLE QVariantMap validateBatch(int mes, int anio,
                                        const QString &esquemaTipo,
                                        const QString &quincena,
                                        const QString &fechaCierre,
                                        const QString &fechaPago);

  /**
   * @brief Execute atomic batch closing: backup, persist all receipts, create closure snapshot, export PDFs.
   */
  Q_INVOKABLE QVariantMap executeBatchClose(int mes, int anio,
                                            const QString &esquemaTipo,
                                            const QString &quincena,
                                            const QString &fechaCierre,
                                            const QString &fechaPago,
                                            const QString &exportPath = "");

private:
  int calculateSeniorityYears(const QString &fechaIngreso,
                              const QString &fechaCalculo) const;

  /// Build the evaluation context for a specific quincena of a jornalero
  QVariantMap buildQuincenaContext(int employeeId, const QString &quincenaCode,
                                   const QVariantMap &globalFlat,
                                   const QMap<QString, QVariantMap> &globalNamespaces,
                                   const QVariantMap &baseContext,
                                   const QVariantList &cells,
                                   const QVariantMap &baseEnvObj = QVariantMap());

  DatabaseManager *m_db;
};

#endif // LIQUIDATIONENGINE_H
