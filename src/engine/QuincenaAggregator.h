#ifndef QUINCENAAGGREGATOR_H
#define QUINCENAAGGREGATOR_H

#include <QObject>
#include <QVariantMap>
#include <QStringList>

/**
 * @brief Handles aggregation of quincena-level data for jornalero employees.
 *
 * Provides functions like Q_sum_, Q_avg_, Q_max_, Q_min_, cant_q()
 * that aggregate values across all quincenas of an employee.
 */
class QuincenaAggregator : public QObject
{
    Q_OBJECT

public:
    explicit QuincenaAggregator(QObject *parent = nullptr);

    /// Set the computed data for each quincena (e.g., {"Q1": {bruto: 100, ...}, "Q2": {...}})
    void setQuincenaData(const QMap<QString, QVariantMap> &data);

    /// Sum a variable across all quincenas
    double sumarQ(const QString &varName) const;

    /// Average a variable across all quincenas
    double promedioQ(const QString &varName) const;

    /// Max of a variable across all quincenas
    double maxQ(const QString &varName) const;

    /// Min of a variable across all quincenas
    double minQ(const QString &varName) const;

    /// Number of quincenas loaded
    int cantQ() const;

    /// Get the value of a variable for a specific quincena
    double getQuincenaValue(const QString &quincenaCode, const QString &varName) const;

    /// Get list of quincena codes
    QStringList quincenaCodes() const;

private:
    QMap<QString, QVariantMap> m_data;
};

#endif // QUINCENAAGGREGATOR_H
