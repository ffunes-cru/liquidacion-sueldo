#include "QuincenaAggregator.h"
#include <limits>

QuincenaAggregator::QuincenaAggregator(QObject *parent)
    : QObject(parent)
{
}

void QuincenaAggregator::setQuincenaData(const QMap<QString, QVariantMap> &data)
{
    m_data = data;
}

double QuincenaAggregator::sumarQ(const QString &varName) const
{
    double total = 0.0;
    for (auto it = m_data.begin(); it != m_data.end(); ++it) {
        const QVariant &val = it.value().value(varName, 0.0);
        if (val.canConvert<double>()) {
            total += val.toDouble();
        }
    }
    return total;
}

double QuincenaAggregator::promedioQ(const QString &varName) const
{
    if (m_data.isEmpty()) return 0.0;

    double total = 0.0;
    int count = 0;
    for (auto it = m_data.begin(); it != m_data.end(); ++it) {
        const QVariant &val = it.value().value(varName, 0.0);
        if (val.canConvert<double>()) {
            total += val.toDouble();
            count++;
        }
    }
    return count > 0 ? total / count : 0.0;
}

double QuincenaAggregator::maxQ(const QString &varName) const
{
    double result = -std::numeric_limits<double>::infinity();
    bool found = false;
    for (auto it = m_data.begin(); it != m_data.end(); ++it) {
        const QVariant &val = it.value().value(varName, 0.0);
        if (val.canConvert<double>()) {
            double d = val.toDouble();
            if (d > result) result = d;
            found = true;
        }
    }
    return found ? result : 0.0;
}

double QuincenaAggregator::minQ(const QString &varName) const
{
    double result = std::numeric_limits<double>::infinity();
    bool found = false;
    for (auto it = m_data.begin(); it != m_data.end(); ++it) {
        const QVariant &val = it.value().value(varName, 0.0);
        if (val.canConvert<double>()) {
            double d = val.toDouble();
            if (d < result) result = d;
            found = true;
        }
    }
    return found ? result : 0.0;
}

int QuincenaAggregator::cantQ() const
{
    return m_data.size();
}

double QuincenaAggregator::getQuincenaValue(const QString &quincenaCode, const QString &varName) const
{
    if (!m_data.contains(quincenaCode)) return 0.0;
    const QVariant &val = m_data[quincenaCode].value(varName, 0.0);
    return val.canConvert<double>() ? val.toDouble() : 0.0;
}

QStringList QuincenaAggregator::quincenaCodes() const
{
    return m_data.keys();
}
