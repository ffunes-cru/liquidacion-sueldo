#ifndef LIQUIDATIONENGINE_H
#define LIQUIDATIONENGINE_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QString>

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
class LiquidationEngine : public QObject
{
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
     *   - "resultados_por_seccion": { sectionCode: [{codigo, descripcion, unidad, base, monto, visible_recibo}] }
     *   - "resultados_grafico": [{etiqueta, valor}]
     *   - "contexto_final": all computed variables
     *   - "errores": [error strings]
     *   - "quincena_sel": selected quincena
     */
    Q_INVOKABLE QVariantMap processLiquidation(int employeeId,
                                                const QString &quincenaSel = "",
                                                const QString &fechaCalculo = "");

    /**
     * @brief Persist the current liquidation result as a receipt snapshot.
     */
    Q_INVOKABLE int persistLiquidation(const QVariantMap &result, int mes, int anio, const QString &periodo);

private:
    int calculateSeniorityYears(const QString &fechaIngreso, const QString &fechaCalculo) const;

    /// Build the evaluation context for a specific quincena of a jornalero
    QVariantMap buildQuincenaContext(int employeeId, const QString &quincenaCode,
                                     const QVariantMap &globalFlat,
                                     const QMap<QString, QVariantMap> &globalNamespaces,
                                     const QVariantMap &baseContext,
                                     const QVariantList &cells);

    DatabaseManager *m_db;
};

#endif // LIQUIDATIONENGINE_H
