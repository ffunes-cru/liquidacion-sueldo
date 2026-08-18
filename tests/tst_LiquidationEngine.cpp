/**
 * Integration tests for LiquidationEngine — end-to-end liquidation with real DB.
 *
 * Uses in-memory SQLite database to test the complete liquidation pipeline:
 * - Schema + cells setup
 * - Employee with field values
 * - processLiquidation() for mensual and jornal
 * - persistLiquidation() save/load/upsert
 * - Condition evaluation (skip cells)
 * - Global variables injection
 * - Seniority calculation
 * - Error handling
 */

#include <QTest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include "database/DatabaseManager.h"
#include "engine/LiquidationEngine.h"
#include "services/ExportService.h"

class TestLiquidationEngine : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    // ── Basic Liquidation ─────────────────────────────────────
    void testMensualBasicFormula();
    void testMensualPercentageCell();
    void testMensualFixedCell();
    void testMensualSimpleCell();
    void testCellChaining();

    // ── Conditions ────────────────────────────────────────────
    void testConditionSkipsCell();
    void testConditionPassesCell();

    // ── Global Variables ──────────────────────────────────────
    void testGlobalVariablesInjected();

    // ── Seniority ─────────────────────────────────────────────
    void testSeniorityCalculation();

    // ── Jornal with Quincenas ─────────────────────────────────
    void testJornalWithTwoQuincenas();

    // ── Persist Liquidation ───────────────────────────────────
    void testPersistAndRetrieve();
    void testPersistUpsert();
    void testPersistSavesQuincenaData();

    // ── Error Handling ────────────────────────────────────────
    void testNonExistentEmployee();

    // ── Custom Functions ──────────────────────────────────────
    void testCustomFunctionInFormula();

    // ── Separator type ────────────────────────────────────────
    void testSeparatorCellZeroAmount();

    // ── Export Service ────────────────────────────────────────
    void testExportServiceDynamicValues();

private:
    DatabaseManager *m_db = nullptr;
    LiquidationEngine *m_engine = nullptr;
    static int s_dbCounter;

    // Helpers
    void setupBasicSchema();
    int createEmployee(const QString &tipo = "mensual",
                       const QString &esquema = "TEST",
                       const QString &fechaIngreso = "2020-01-01");
};

int TestLiquidationEngine::s_dbCounter = 0;

void TestLiquidationEngine::init()
{
    // Use a unique connection name per test to avoid conflicts
    QString connName = QString("test_liq_%1").arg(++s_dbCounter);
    // Use in-memory SQLite with unique connection
    m_db = new DatabaseManager(":memory:");
    m_engine = new LiquidationEngine(m_db);
}

void TestLiquidationEngine::cleanup()
{
    delete m_engine;
    m_engine = nullptr;
    delete m_db;
    m_db = nullptr;
}

void TestLiquidationEngine::setupBasicSchema()
{
    m_db->saveSchema("", "TEST", "Test Schema", "mensual");
}

int TestLiquidationEngine::createEmployee(const QString &tipo,
                                           const QString &esquema,
                                           const QString &fechaIngreso)
{
    return m_db->saveEmployee(0, "001", "Test Employee", tipo, esquema,
                              0, fechaIngreso, "20-12345678-9");
}

// ════════════════════════════════════════════════════════════════
// Basic Liquidation
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testMensualBasicFormula()
{
    setupBasicSchema();

    // Add a schema field for basico
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "50000", 1);

    // Add a formula cell that just returns basico
    m_db->saveCell(0, "RECIBO", "sueldo_basico", "Sueldo Básico", "",
                   "", "", "basico", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = createEmployee();
    // Set field value
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "50000"}});

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    QCOMPARE(ctx["sueldo_basico"].toDouble(), 50000.0);
}

void TestLiquidationEngine::testMensualPercentageCell()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "100000", 1);

    // Percentage cell: 11% of basico
    m_db->saveCell(0, "RECIBO", "aporte_jubilatorio", "Aporte Jubilatorio", "",
                   "", "", "", 10, "TEST",
                   "porcentaje", 11.0, "basico", 0.0, true);

    int empId = createEmployee();
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "100000"}});

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    QCOMPARE(ctx["aporte_jubilatorio"].toDouble(), 11000.0);
}

void TestLiquidationEngine::testMensualFixedCell()
{
    setupBasicSchema();

    // Fixed amount cell
    m_db->saveCell(0, "RECIBO", "viatico", "Viático Fijo", "",
                   "", "", "", 10, "TEST",
                   "fijo", 0.0, "", 5000.0, true);

    int empId = createEmployee();

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    QCOMPARE(ctx["viatico"].toDouble(), 5000.0);
}

void TestLiquidationEngine::testMensualSimpleCell()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "100000", 1);

    // Simple cell: 10% of basico + 2000 fijo
    m_db->saveCell(0, "RECIBO", "premio", "Premio", "",
                   "", "", "", 10, "TEST",
                   "simple", 10.0, "basico", 2000.0, true);

    int empId = createEmployee();
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "100000"}});

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    // 100000 * 0.10 + 2000 = 12000
    QCOMPARE(ctx["premio"].toDouble(), 12000.0);
}

void TestLiquidationEngine::testCellChaining()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "50000", 1);

    // Cell 1: basico (formula that returns basico)
    m_db->saveCell(0, "RECIBO", "sueldo_basico", "Sueldo Básico", "",
                   "", "", "basico", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    // Cell 2: uses sueldo_basico computed above
    m_db->saveCell(0, "RECIBO", "aporte", "Aporte", "",
                   "", "", "sueldo_basico * 0.11", 20, "TEST",
                   "formula", 0.0, "", 0.0, true);

    // Cell 3: neto = sueldo_basico - aporte
    m_db->saveCell(0, "RECIBO", "neto", "Neto", "",
                   "", "", "sueldo_basico - aporte", 30, "TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = createEmployee();
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "50000"}});

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    QCOMPARE(ctx["sueldo_basico"].toDouble(), 50000.0);
    QCOMPARE(ctx["aporte"].toDouble(), 5500.0);
    QCOMPARE(ctx["neto"].toDouble(), 44500.0);
}

// ════════════════════════════════════════════════════════════════
// Conditions
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testConditionSkipsCell()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "50000", 1);

    // Cell with condition that evaluates to false
    m_db->saveCell(0, "RECIBO", "bonus_jornal", "Bonus Jornal", "tipo_liquidacion == 'jornal'",
                   "", "", "basico * 0.5", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = createEmployee("mensual"); // tipo is mensual, condition requires jornal

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    // Should be 0 because the cell was skipped
    QCOMPARE(ctx["bonus_jornal"].toDouble(), 0.0);
}

void TestLiquidationEngine::testConditionPassesCell()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "50000", 1);

    // Cell with condition that evaluates to true
    m_db->saveCell(0, "RECIBO", "bonus_mensual", "Bonus Mensual", "tipo_liquidacion == 'mensual'",
                   "", "", "basico * 0.1", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = createEmployee("mensual");
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "50000"}});

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    QCOMPARE(ctx["bonus_mensual"].toDouble(), 5000.0);
}

// ════════════════════════════════════════════════════════════════
// Global Variables
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testGlobalVariablesInjected()
{
    setupBasicSchema();

    // Add global variable
    m_db->saveGlobalVariable(0, "tope_maximo", "200000", "Tope máximo contribución");

    // Cell uses global var
    m_db->saveCell(0, "RECIBO", "resultado", "Resultado", "",
                   "", "", "tope_maximo * 0.5", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = createEmployee();

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    QCOMPARE(ctx["resultado"].toDouble(), 100000.0);
}

// ════════════════════════════════════════════════════════════════
// Seniority
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testSeniorityCalculation()
{
    setupBasicSchema();

    // Cell that uses antiguedad_anios
    m_db->saveCell(0, "RECIBO", "bono_antiguedad", "Bono Antigüedad", "",
                   "", "", "antiguedad_anios * 1000", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    // Employee hired 2020-01-01, calculate at 2026-08-15 = 6 years
    int empId = createEmployee("mensual", "TEST", "2020-01-01");

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    QCOMPARE(ctx["antiguedad_anios"].toInt(), 6);
    QCOMPARE(ctx["bono_antiguedad"].toDouble(), 6000.0);
}

// ════════════════════════════════════════════════════════════════
// Jornal with Quincenas
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testJornalWithTwoQuincenas()
{
    m_db->saveSchema("", "JORNAL_TEST", "Test Jornal", "jornal");
    m_db->addSchemaField("JORNAL_TEST", "horas_trabajadas", "Horas Trabajadas", "number", "0", 1);

    // Add a category for valor_hora
    int catId = m_db->saveCategory(0, "Cat A", 500.0);

    // Formula cell: horas_trabajadas * valor_hora
    m_db->saveCell(0, "RECIBO", "basico", "Básico", "",
                   "", "", "horas_trabajadas * valor_hora", 10, "JORNAL_TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = m_db->saveEmployee(0, "002", "Jornalero Test", "jornal", "JORNAL_TEST",
                                    catId, "2022-01-01", "20-99999999-9");

    // Add Q2
    m_db->addQuincena(empId, "Q2");

    // Set values for each quincena
    m_db->setEmployeeFieldValues(empId, "Q1", {{"horas_trabajadas", "80"}});
    m_db->setEmployeeFieldValues(empId, "Q2", {{"horas_trabajadas", "90"}});

    // Process Q1
    QVariantMap resultQ1 = m_engine->processLiquidation(empId, "Q1", "2026-08-15");
    QVariantMap ctxQ1 = resultQ1["contexto_final"].toMap();
    QCOMPARE(ctxQ1["basico"].toDouble(), 40000.0); // 80 * 500

    // Process Q2
    QVariantMap resultQ2 = m_engine->processLiquidation(empId, "Q2", "2026-08-15");
    QVariantMap ctxQ2 = resultQ2["contexto_final"].toMap();
    QCOMPARE(ctxQ2["basico"].toDouble(), 45000.0); // 90 * 500
}

// ════════════════════════════════════════════════════════════════
// Persist Liquidation
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testPersistAndRetrieve()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "75000", 1);

    m_db->saveCell(0, "RECIBO", "sueldo", "Sueldo", "",
                   "", "", "basico", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = createEmployee();
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "75000"}});

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");

    // Persist
    int receiptId = m_engine->persistLiquidation(result, 8, 2026, "M");
    QVERIFY(receiptId > 0);

    // Retrieve
    QVariantMap receipt = m_db->getReceipt(receiptId);
    QVERIFY(!receipt.isEmpty());
    QCOMPARE(receipt["mes"].toInt(), 8);
    QCOMPARE(receipt["anio"].toInt(), 2026);

    // Parse JSON and verify concepts
    QJsonDocument doc = QJsonDocument::fromJson(receipt["datos_json"].toString().toUtf8());
    QVERIFY(doc.isObject());
    QJsonObject root = doc.object();
    QVERIFY(root.contains("conceptos"));
    QVERIFY(root["conceptos"].isArray());
    QVERIFY(root["conceptos"].toArray().size() > 0);

    // Verify the sueldo variable was persisted
    QCOMPARE(root["sueldo"].toDouble(), 75000.0);
}

void TestLiquidationEngine::testPersistUpsert()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "50000", 1);
    m_db->saveCell(0, "RECIBO", "sueldo", "Sueldo", "",
                   "", "", "basico", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = createEmployee();
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "50000"}});

    QVariantMap result1 = m_engine->processLiquidation(empId, "", "2026-08-15");
    int id1 = m_engine->persistLiquidation(result1, 8, 2026, "M");

    // Change basico and re-persist for same period
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "60000"}});
    QVariantMap result2 = m_engine->processLiquidation(empId, "", "2026-08-15");
    int id2 = m_engine->persistLiquidation(result2, 8, 2026, "M");

    // Should be same receipt ID (upsert)
    QCOMPARE(id1, id2);

    // Verify updated value
    QVariantMap receipt = m_db->getReceipt(id2);
    QJsonDocument doc = QJsonDocument::fromJson(receipt["datos_json"].toString().toUtf8());
    QCOMPARE(doc.object()["sueldo"].toDouble(), 60000.0);
}

void TestLiquidationEngine::testPersistSavesQuincenaData()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "50000", 1);
    m_db->saveCell(0, "RECIBO", "sueldo", "Sueldo", "",
                   "", "", "basico", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = createEmployee();
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "50000"}});

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");

    int receiptId = m_engine->persistLiquidation(result, 8, 2026, "M");
    QVERIFY(receiptId > 0);

    // Retrieve and check that variables section contains the data
    QVariantMap receipt = m_db->getReceipt(receiptId);
    QJsonDocument doc = QJsonDocument::fromJson(receipt["datos_json"].toString().toUtf8());
    QJsonObject root = doc.object();

    // Verify the variables object is present and has our field
    QVERIFY(root.contains("variables"));
    QJsonObject vars = root["variables"].toObject();
    QCOMPARE(vars["basico"].toDouble(), 50000.0);
}

// ════════════════════════════════════════════════════════════════
// Error Handling
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testNonExistentEmployee()
{
    QVariantMap result = m_engine->processLiquidation(99999, "", "2026-08-15");
    QVariantMap emp = result["empleado"].toMap();
    QVERIFY(emp.isEmpty());

    // Should have error
    QStringList errores = result["errores"].toStringList();
    QVERIFY(!errores.isEmpty());
    QVERIFY(errores.first().contains("Empleado no encontrado"));
}

// ════════════════════════════════════════════════════════════════
// Custom Functions
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testCustomFunctionInFormula()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "100000", 1);

    // Register a custom function
    m_db->saveCustomFunction(0, "calcular_desc", "base, pct",
                             "return base * (pct / 100);",
                             "Calcula descuento");

    // Cell uses custom function
    m_db->saveCell(0, "RECIBO", "descuento", "Descuento", "",
                   "", "", "calcular_desc(basico, 11)", 10, "TEST",
                   "formula", 0.0, "", 0.0, true);

    int empId = createEmployee();
    m_db->setEmployeeFieldValues(empId, "Q1", {{"basico", "100000"}});

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    QCOMPARE(ctx["descuento"].toDouble(), 11000.0);
}

// ════════════════════════════════════════════════════════════════
// Separator type
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testSeparatorCellZeroAmount()
{
    setupBasicSchema();

    m_db->saveCell(0, "RECIBO", "sep_descuentos", "--- Descuentos ---", "",
                   "", "", "", 10, "TEST",
                   "separator", 0.0, "", 0.0, true);

    int empId = createEmployee();

    QVariantMap result = m_engine->processLiquidation(empId, "", "2026-08-15");
    QVariantMap ctx = result["contexto_final"].toMap();

    QCOMPARE(ctx["sep_descuentos"].toDouble(), 0.0);
}

// ════════════════════════════════════════════════════════════════
// ExportService Dynamic Values Test
// ════════════════════════════════════════════════════════════════

void TestLiquidationEngine::testExportServiceDynamicValues()
{
    setupBasicSchema();
    m_db->addSchemaField("TEST", "basico", "Sueldo Básico", "number", "100000", 1);
    m_db->addSchemaField("TEST", "antiguedad_manual", "Antigüedad Manual", "number", "5", 2);

    int empId1 = createEmployee("mensual", "TEST", "2020-01-01");
    m_db->setEmployeeFieldValues(empId1, "Q1", {{"basico", "120000"}, {"antiguedad_manual", "3"}});

    int empId2 = createEmployee("jornal", "TEST", "2021-01-01");
    m_db->addQuincena(empId2, "Q2");
    m_db->setEmployeeFieldValues(empId2, "Q1", {{"basico", "50000"}, {"antiguedad_manual", "1"}});
    m_db->setEmployeeFieldValues(empId2, "Q2", {{"basico", "55000"}, {"antiguedad_manual", "1"}});

    ExportService exportSvc(m_db);
    QString tempXlsx = QDir::tempPath() + "/test_export_dynamic.xlsx";
    QString resultPath = exportSvc.exportDataXlsx(tempXlsx);
    QVERIFY(!resultPath.isEmpty());
    QVERIFY(QFile::exists(tempXlsx));

    // Clear DB and re-import
    DatabaseManager db2(":memory:");
    ExportService exportSvc2(&db2);
    bool imported = exportSvc2.importDataXlsx(tempXlsx);
    QVERIFY(imported);

    // Verify employees imported
    auto emps = db2.listEmployees();
    QCOMPARE(emps.size(), 2);

    // Verify dynamic field values imported for monthly (mapped M -> Q1)
    auto fVals1 = db2.getEmployeeFieldValues(empId1, "Q1");
    QMap<QString, QString> valMap1;
    for (const auto &fv : fVals1) {
        auto m = fv.toMap();
        valMap1[m["field_code"].toString()] = m["value"].toString();
    }
    QCOMPARE(valMap1["basico"], "120000");

    // Clean up
    QFile::remove(tempXlsx);
}

#include "tst_LiquidationEngine.moc"

QObject *createTestLiquidationEngine() { return new TestLiquidationEngine(); }
