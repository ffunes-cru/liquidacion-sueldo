/**
 * Tests for DatabaseManager — SQLite database operations, schema model syncing,
 * cascade deletions, validation, transactions, backup/reset, and single instance lock.
 */

#include <QTest>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include "database/DatabaseManager.h"

class TestDatabaseManager : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    // ── Schemas ───────────────────────────────────────────────
    void testSchemaCrud();

    // ── Categories ────────────────────────────────────────────
    void testCategoryCrud();

    // ── Employees ─────────────────────────────────────────────
    void testEmployeeCrud();
    void testDuplicateEmployee();
    void testEmployeeSoftDeleteWithReceipts();

    // ── Schema Fields ─────────────────────────────────────────
    void testSchemaFieldCrud();
    void testSyncEmployeeFieldsForSchema();

    // ── Employee Field Values ─────────────────────────────────
    void testEmployeeFieldValues();

    // ── Quincenas ─────────────────────────────────────────────
    void testQuincenasCrud();

    // ── Calculation Cells ─────────────────────────────────────
    void testCalculationCellsCrud();
    void testEnforceUniqueGraficoTotal();

    // ── Chart Cells ───────────────────────────────────────────
    void testChartCellsCrud();

    // ── Global Variables ──────────────────────────────────────
    void testGlobalVariablesCrud();

    // ── Custom Functions ──────────────────────────────────────
    void testCustomFunctionsCrud();

    // ── Company ───────────────────────────────────────────────
    void testCompanyCrud();

    // ── Receipts ──────────────────────────────────────────────
    void testReceiptsCrud();

    // ── Config ────────────────────────────────────────────────
    void testConfigKeyValue();

    // ── Code Validation ───────────────────────────────────────
    void testValidateVariableCode();

    // ── Single Instance Lock ──────────────────────────────────
    void testSingleInstanceLocking();

    // ── Reset New Month & Backup ──────────────────────────────
    void testResetNewMonth();

private:
    DatabaseManager *m_db = nullptr;
    static int s_dbCounter;
};

int TestDatabaseManager::s_dbCounter = 100;

void TestDatabaseManager::init()
{
    QString connName = QString("test_db_%1").arg(++s_dbCounter);
    m_db = new DatabaseManager(":memory:");
}

void TestDatabaseManager::cleanup()
{
    delete m_db;
    m_db = nullptr;
}

// ════════════════════════════════════════════════════════════════
// Schemas
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testSchemaCrud()
{
    // Default schemas seeded
    auto list = m_db->listSchemas();
    QVERIFY(list.size() >= 2);

    // Save new schema
    QVERIFY(m_db->saveSchema("", "NUEVO_ESQ", "Nuevo Esquema", "mensual"));
    auto esq = m_db->getSchema("NUEVO_ESQ");
    QCOMPARE(esq["nombre"].toString(), "Nuevo Esquema");

    // Delete schema
    QVERIFY(m_db->deleteSchema("NUEVO_ESQ"));
    QVERIFY(m_db->getSchema("NUEVO_ESQ").isEmpty());
}

// ════════════════════════════════════════════════════════════════
// Categories
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testCategoryCrud()
{
    int catId = m_db->saveCategory(0, "Oficial Especializado", 1250.50);
    QVERIFY(catId > 0);

    auto cat = m_db->getCategory(catId);
    QCOMPARE(cat["nombre"].toString(), "Oficial Especializado");
    QCOMPARE(cat["valor_hora"].toDouble(), 1250.50);

    // Update
    m_db->saveCategory(catId, "Oficial Esp. Mod", 1300.00);
    QCOMPARE(m_db->getCategory(catId)["valor_hora"].toDouble(), 1300.00);

    // Delete
    QVERIFY(m_db->deleteCategory(catId));
    QVERIFY(m_db->getCategory(catId).isEmpty());
}

// ════════════════════════════════════════════════════════════════
// Employees
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testEmployeeCrud()
{
    int empId = m_db->saveEmployee(0, "L001", "Perez Juan", "mensual", "MENSUAL", 0, "2020-01-01", "20-12345678-9");
    QVERIFY(empId > 0);

    auto emp = m_db->getEmployee(empId);
    QCOMPARE(emp["nombre_completo"].toString(), "Perez Juan");
    QCOMPARE(emp["legajo"].toString(), "L001");

    // Update
    m_db->saveEmployee(empId, "L001_UPD", "Perez Juan Mod", "mensual", "MENSUAL", 0, "2020-01-01", "20-12345678-9");
    QCOMPARE(m_db->getEmployee(empId)["nombre_completo"].toString(), "Perez Juan Mod");

    // Delete
    QVERIFY(m_db->deleteEmployee(empId));
    QVERIFY(m_db->getEmployee(empId).isEmpty());
}

void TestDatabaseManager::testDuplicateEmployee()
{
    int origId = m_db->saveEmployee(0, "L100", "Original Emp", "mensual", "MENSUAL", 0, "2021-05-10", "27-11111111-4");
    int fieldId = m_db->addSchemaField("MENSUAL", "sueldo_fijo", "Sueldo Fijo", "number", "0", 1);
    m_db->setEmployeeFieldValue(origId, fieldId, "Q1", "85000");

    int dupId = m_db->duplicateEmployee(origId);
    QVERIFY(dupId > 0);
    QVERIFY(dupId != origId);

    auto dupEmp = m_db->getEmployee(dupId);
    QVERIFY(dupEmp["nombre_completo"].toString().contains("(Copia)"));

    // Check duplicated field values
    auto fVals = m_db->getEmployeeFieldValues(dupId, "Q1");
    QVERIFY(!fVals.isEmpty());
    QCOMPARE(fVals.first().toMap()["value"].toString(), "85000");
}

void TestDatabaseManager::testEmployeeSoftDeleteWithReceipts()
{
    int empId = m_db->saveEmployee(0, "L900", "Empleado Con Recibos", "mensual", "MENSUAL", 0, "2020-01-01", "20-99999999-9");
    QVERIFY(empId > 0);

    int recId = m_db->saveReceipt(empId, "MENSUAL", 8, 2026, "M", "{\"totales\":{\"neto_a_cobrar\":200000}}");
    QVERIFY(recId > 0);

    // Intentar eliminar el empleado: debe realizar soft-delete (activo = 0)
    QVERIFY(m_db->deleteEmployee(empId));

    // El empleado no debe aparecer en la lista de empleados activos
    auto activeEmployees = m_db->listEmployees();
    for (const auto &e : activeEmployees) {
        QVERIFY(e.toMap()["id"].toInt() != empId);
    }

    // El recibo histórico debe seguir existiendo intacto
    auto rec = m_db->getReceipt(recId);
    QVERIFY(!rec.isEmpty());
    QCOMPARE(rec["empleado_id"].toInt(), empId);

    // Eliminar el recibo
    QVERIFY(m_db->deleteReceipt(recId));

    // Ahora que no tiene recibos, deleteEmployee lo remueve físicamente
    QVERIFY(m_db->deleteEmployee(empId));
    QVERIFY(m_db->getEmployee(empId).isEmpty());
}


// ════════════════════════════════════════════════════════════════
// Schema Fields & Sync
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testSchemaFieldCrud()
{
    int fId = m_db->addSchemaField("MENSUAL", "horas_extras", "Horas Extras", "number", "0", 10);
    QVERIFY(fId > 0);

    auto fields = m_db->listSchemaFields("MENSUAL");
    bool found = false;
    for (const auto &f : fields) {
        if (f.toMap()["field_code"].toString() == "horas_extras") {
            found = true;
            break;
        }
    }
    QVERIFY(found);

    // Update
    QVERIFY(m_db->updateSchemaField(fId, "horas_extras", "Horas Extras Mod", "number", "5"));
    // Rename
    QVERIFY(m_db->renameSchemaField(fId, "horas_extras_renamed", "Horas Extras Renamed"));

    // Remove
    QVERIFY(m_db->removeSchemaField(fId));
}

void TestDatabaseManager::testSyncEmployeeFieldsForSchema()
{
    int empId = m_db->saveEmployee(0, "L200", "Sync Emp", "mensual", "MENSUAL", 0, "2020-01-01", "");
    int fId = m_db->addSchemaField("MENSUAL", "campo_sync", "Campo Sync", "number", "100", 1);

    // Sync should automatically create field values for existing employees with default_value
    m_db->syncEmployeeFieldsForSchema("MENSUAL");

    auto fVals = m_db->getEmployeeFieldValues(empId, "Q1");
    bool foundVal = false;
    for (const auto &fv : fVals) {
        auto m = fv.toMap();
        if (m["field_code"].toString() == "campo_sync") {
            QCOMPARE(m["value"].toString(), "100");
            foundVal = true;
            break;
        }
    }
    QVERIFY(foundVal);
}

// ════════════════════════════════════════════════════════════════
// Employee Field Values
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testEmployeeFieldValues()
{
    int empId = m_db->saveEmployee(0, "L300", "Val Emp", "mensual", "MENSUAL", 0, "2020-01-01", "");
    int fId = m_db->addSchemaField("MENSUAL", "val_test", "Val Test", "number", "0", 1);

    QVERIFY(m_db->setEmployeeFieldValue(empId, fId, "Q1", "5000"));
    auto vals = m_db->getEmployeeFieldValues(empId, "Q1");
    QCOMPARE(vals.first().toMap()["value"].toString(), "5000");

    // setEmployeeFieldValues map
    QVERIFY(m_db->setEmployeeFieldValues(empId, "Q1", {{"val_test", "7500"}}));
    vals = m_db->getEmployeeFieldValues(empId, "Q1");
    QCOMPARE(vals.first().toMap()["value"].toString(), "7500");
}

// ════════════════════════════════════════════════════════════════
// Quincenas
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testQuincenasCrud()
{
    int empId = m_db->saveEmployee(0, "L400", "Q Emp", "jornal", "JORNAL", 0, "2020-01-01", "");
    QCOMPARE(m_db->listEmployeeQuincenas(empId).size(), 1);

    QVERIFY(m_db->addQuincena(empId, "Q2"));
    QCOMPARE(m_db->listEmployeeQuincenas(empId).size(), 2);

    // Prevent removing Q1
    QVERIFY(!m_db->removeQuincena(empId, "Q1"));
    QCOMPARE(m_db->listEmployeeQuincenas(empId).size(), 2);

    // Remove Q2
    QVERIFY(m_db->removeQuincena(empId, "Q2"));
    QCOMPARE(m_db->listEmployeeQuincenas(empId).size(), 1);
}

// ════════════════════════════════════════════════════════════════
// Calculation Cells & Chart Cells
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testCalculationCellsCrud()
{
    int cId = m_db->saveCell(0, "RECIBO", "basico_cell", "Básico", "", "", "", "basico", 10, "MENSUAL",
                             "formula", 0.0, "", 0.0, true, "#FFFFFF", false, false);
    QVERIFY(cId > 0);

    auto cells = m_db->listCellsBySchema("MENSUAL");
    QVERIFY(!cells.isEmpty());

    QVERIFY(m_db->updateCellColor(cId, "#00FF00"));
    QVERIFY(m_db->deleteCell(cId));
}

void TestDatabaseManager::testEnforceUniqueGraficoTotal()
{
    // Save cell 1 with es_grafico_total = true
    int c1 = m_db->saveCell(0, "RECIBO", "total_1", "Total 1", "", "", "", "100", 10, "MENSUAL",
                            "formula", 0.0, "", 0.0, true, "", false, true);

    // Save cell 2 with es_grafico_total = true (should reset cell 1's total flag)
    int c2 = m_db->saveCell(0, "RECIBO", "total_2", "Total 2", "", "", "", "200", 20, "MENSUAL",
                            "formula", 0.0, "", 0.0, true, "", false, true);

    auto cells = m_db->listCellsBySchema("MENSUAL");
    for (const auto &c : cells) {
        auto m = c.toMap();
        if (m["id"].toInt() == c1) {
            QCOMPARE(m["es_grafico_total"].toInt(), 0);
        } else if (m["id"].toInt() == c2) {
            QCOMPARE(m["es_grafico_total"].toInt(), 1);
        }
    }
}

void TestDatabaseManager::testChartCellsCrud()
{
    int cgId = m_db->saveChartCell(0, "Sueldo Neto", "neto", 10, "MENSUAL");
    QVERIFY(cgId > 0);

    auto list = m_db->listChartCellsBySchema("MENSUAL");
    QVERIFY(!list.isEmpty());
    QCOMPARE(list.first().toMap()["etiqueta"].toString(), "Sueldo Neto");

    QVERIFY(m_db->deleteChartCell(cgId));
}

// ════════════════════════════════════════════════════════════════
// Global Variables & Custom Functions
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testGlobalVariablesCrud()
{
    int gId = m_db->saveGlobalVariable(0, "min_jubilacion", "50000", "Jubilación mínima");
    QVERIFY(gId > 0);

    auto list = m_db->listGlobalVariables();
    QVERIFY(!list.isEmpty());

    QVERIFY(m_db->deleteGlobalVariable(gId));
}

void TestDatabaseManager::testCustomFunctionsCrud()
{
    int funcId = m_db->saveCustomFunction(0, "mi_funcion", "a, b", "return a + b;", "Suma dos números", "MENSUAL");
    QVERIFY(funcId > 0);

    auto list = m_db->listCustomFunctions("MENSUAL");
    QVERIFY(!list.isEmpty());
    bool found = false;
    for (const auto &f : list) {
        if (f.toMap()["name"].toString() == "mi_funcion") {
            found = true;
            break;
        }
    }
    QVERIFY(found);

    QVERIFY(m_db->deleteCustomFunction(funcId));
}

// ════════════════════════════════════════════════════════════════
// Company & Receipts & Config
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testCompanyCrud()
{
    QVERIFY(m_db->saveCompany("Mi Empresa S.A.", "Av. Corrientes 1234", "30-11111111-8", "Buenos Aires"));

    auto comp = m_db->getCompany();
    QCOMPARE(comp["razon_social"].toString(), "Mi Empresa S.A.");
    QCOMPARE(comp["cuit"].toString(), "30-11111111-8");
}

void TestDatabaseManager::testReceiptsCrud()
{
    int empId = m_db->saveEmployee(0, "L500", "Rec Emp", "mensual", "MENSUAL", 0, "2020-01-01", "");

    int recId = m_db->saveReceipt(empId, "MENSUAL", 8, 2026, "M", "{\"totales\":{\"neto_a_cobrar\":100000}}");
    QVERIFY(recId > 0);

    auto rec = m_db->getReceipt(recId);
    QCOMPARE(rec["mes"].toInt(), 8);

    auto search = m_db->searchReceipts(empId, 8, 2026);
    QCOMPARE(search.size(), 1);

    QVERIFY(m_db->deleteReceipt(recId));
}

void TestDatabaseManager::testConfigKeyValue()
{
    m_db->setConfig("tema_color", "oscuro");
    QCOMPARE(m_db->getConfig("tema_color"), "oscuro");
    QCOMPARE(m_db->getConfig("no_existe", "defecto"), "defecto");
}

// ════════════════════════════════════════════════════════════════
// Code Validation
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testValidateVariableCode()
{
    // Valid identifier names
    QVERIFY(DatabaseManager::validateVariableCode("basico").isEmpty());
    QVERIFY(DatabaseManager::validateVariableCode("horas_extras_50").isEmpty());
    QVERIFY(DatabaseManager::validateVariableCode("_var123").isEmpty());

    // Invalid identifier names
    QVERIFY(!DatabaseManager::validateVariableCode("").isEmpty());
    QVERIFY(!DatabaseManager::validateVariableCode("123var").isEmpty());
    QVERIFY(!DatabaseManager::validateVariableCode("basico con espacios").isEmpty());
    QVERIFY(!DatabaseManager::validateVariableCode("monto-$").isEmpty());
}

// ════════════════════════════════════════════════════════════════
// Single Instance Lock
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testSingleInstanceLocking()
{
    // Test lock file on disk
    QString tempDbPath = QDir::tempPath() + QString("/test_lock_%1.db").arg(++s_dbCounter);
    
    // Process 1 opens database
    DatabaseManager db1(tempDbPath);
    QVERIFY(db1.isOpen());
    QVERIFY(!db1.isLockedByOtherInstance());

    // Process 2 attempts to open same database
    DatabaseManager db2(tempDbPath);
    QVERIFY(db2.isLockedByOtherInstance());
    QVERIFY(!db2.lockError().isEmpty());

    // Cleanup
    QFile::remove(tempDbPath);
    QFile::remove(tempDbPath + ".lock");
}

// ════════════════════════════════════════════════════════════════
// Reset New Month & Backup
// ════════════════════════════════════════════════════════════════

void TestDatabaseManager::testResetNewMonth()
{
    int empId = m_db->saveEmployee(0, "L600", "Reset Emp", "jornal", "JORNAL", 0, "2020-01-01", "");
    m_db->addQuincena(empId, "Q2");

    int fId = m_db->addSchemaField("JORNAL", "horas_trabajadas", "Horas Trabajadas", "number", "0", 1);
    m_db->setEmployeeFieldValue(empId, fId, "Q1", "80");
    m_db->setEmployeeFieldValue(empId, fId, "Q2", "90");

    // Reset new month should create a backup and reset hours_trabajadas and delete extra quincenas
    QString backupPath = m_db->resetNewMonth();
    QVERIFY(!backupPath.isEmpty());

    // Q2 should be removed on new month reset
    auto quincenas = m_db->listEmployeeQuincenas(empId);
    QCOMPARE(quincenas.size(), 1);
    QCOMPARE(quincenas.first(), QString("Q1"));

    // Cleanup backup file
    QFile::remove(backupPath);
}

#include "tst_DatabaseManager.moc"

QObject *createTestDatabaseManager() { return new TestDatabaseManager(); }
