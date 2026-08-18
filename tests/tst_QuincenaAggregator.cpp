/**
 * Tests for QuincenaAggregator — quincena-level data aggregation.
 *
 * Covers:
 * - sumarQ across 1, 2, N quincenas
 * - promedioQ with uniform and variable data
 * - maxQ, minQ
 * - cantQ with empty, 1, and multiple quincenas
 * - getQuincenaValue for existing and non-existing quincenas
 * - quincenaCodes
 */

#include <QTest>
#include "engine/QuincenaAggregator.h"

class TestQuincenaAggregator : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    // ── sumarQ ────────────────────────────────────────────────
    void testSumarQSingleQuincena();
    void testSumarQTwoQuincenas();
    void testSumarQMissingVar();

    // ── promedioQ ─────────────────────────────────────────────
    void testPromedioQUniform();
    void testPromedioQVariable();
    void testPromedioQEmpty();

    // ── maxQ / minQ ───────────────────────────────────────────
    void testMaxQ();
    void testMinQ();
    void testMaxQSingleQuincena();

    // ── cantQ ─────────────────────────────────────────────────
    void testCantQEmpty();
    void testCantQOne();
    void testCantQMultiple();

    // ── getQuincenaValue ──────────────────────────────────────
    void testGetQuincenaValueExists();
    void testGetQuincenaValueNotExists();

    // ── quincenaCodes ─────────────────────────────────────────
    void testQuincenaCodes();

private:
    QuincenaAggregator *m_agg = nullptr;
};

void TestQuincenaAggregator::init()
{
    m_agg = new QuincenaAggregator();
}

void TestQuincenaAggregator::cleanup()
{
    delete m_agg;
    m_agg = nullptr;
}

// ════════════════════════════════════════════════════════════════
// sumarQ
// ════════════════════════════════════════════════════════════════

void TestQuincenaAggregator::testSumarQSingleQuincena()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 50000.0}, {"horas", 160.0}};
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->sumarQ("basico"), 50000.0);
    QCOMPARE(m_agg->sumarQ("horas"), 160.0);
}

void TestQuincenaAggregator::testSumarQTwoQuincenas()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 25000.0}};
    data["Q2"] = {{"basico", 30000.0}};
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->sumarQ("basico"), 55000.0);
}

void TestQuincenaAggregator::testSumarQMissingVar()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 50000.0}};
    m_agg->setQuincenaData(data);

    // Variable that doesn't exist — default QVariant(0.0) should be convertible
    QCOMPARE(m_agg->sumarQ("no_existe"), 0.0);
}

// ════════════════════════════════════════════════════════════════
// promedioQ
// ════════════════════════════════════════════════════════════════

void TestQuincenaAggregator::testPromedioQUniform()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 100.0}};
    data["Q2"] = {{"basico", 100.0}};
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->promedioQ("basico"), 100.0);
}

void TestQuincenaAggregator::testPromedioQVariable()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 100.0}};
    data["Q2"] = {{"basico", 200.0}};
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->promedioQ("basico"), 150.0);
}

void TestQuincenaAggregator::testPromedioQEmpty()
{
    QMap<QString, QVariantMap> data;
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->promedioQ("basico"), 0.0);
}

// ════════════════════════════════════════════════════════════════
// maxQ / minQ
// ════════════════════════════════════════════════════════════════

void TestQuincenaAggregator::testMaxQ()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 25000.0}};
    data["Q2"] = {{"basico", 30000.0}};
    data["Q3"] = {{"basico", 20000.0}};
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->maxQ("basico"), 30000.0);
}

void TestQuincenaAggregator::testMinQ()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 25000.0}};
    data["Q2"] = {{"basico", 30000.0}};
    data["Q3"] = {{"basico", 20000.0}};
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->minQ("basico"), 20000.0);
}

void TestQuincenaAggregator::testMaxQSingleQuincena()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 42.0}};
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->maxQ("basico"), 42.0);
    QCOMPARE(m_agg->minQ("basico"), 42.0);
}

// ════════════════════════════════════════════════════════════════
// cantQ
// ════════════════════════════════════════════════════════════════

void TestQuincenaAggregator::testCantQEmpty()
{
    QMap<QString, QVariantMap> data;
    m_agg->setQuincenaData(data);
    QCOMPARE(m_agg->cantQ(), 0);
}

void TestQuincenaAggregator::testCantQOne()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {};
    m_agg->setQuincenaData(data);
    QCOMPARE(m_agg->cantQ(), 1);
}

void TestQuincenaAggregator::testCantQMultiple()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {};
    data["Q2"] = {};
    data["Q3"] = {};
    m_agg->setQuincenaData(data);
    QCOMPARE(m_agg->cantQ(), 3);
}

// ════════════════════════════════════════════════════════════════
// getQuincenaValue
// ════════════════════════════════════════════════════════════════

void TestQuincenaAggregator::testGetQuincenaValueExists()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 50000.0}};
    data["Q2"] = {{"basico", 60000.0}};
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->getQuincenaValue("Q1", "basico"), 50000.0);
    QCOMPARE(m_agg->getQuincenaValue("Q2", "basico"), 60000.0);
}

void TestQuincenaAggregator::testGetQuincenaValueNotExists()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {{"basico", 50000.0}};
    m_agg->setQuincenaData(data);

    QCOMPARE(m_agg->getQuincenaValue("Q99", "basico"), 0.0);
    QCOMPARE(m_agg->getQuincenaValue("Q1", "no_existe"), 0.0);
}

// ════════════════════════════════════════════════════════════════
// quincenaCodes
// ════════════════════════════════════════════════════════════════

void TestQuincenaAggregator::testQuincenaCodes()
{
    QMap<QString, QVariantMap> data;
    data["Q1"] = {};
    data["Q2"] = {};
    m_agg->setQuincenaData(data);

    QStringList codes = m_agg->quincenaCodes();
    QCOMPARE(codes.size(), 2);
    QVERIFY(codes.contains("Q1"));
    QVERIFY(codes.contains("Q2"));
}

#include "tst_QuincenaAggregator.moc"

QObject *createTestQuincenaAggregator() { return new TestQuincenaAggregator(); }
