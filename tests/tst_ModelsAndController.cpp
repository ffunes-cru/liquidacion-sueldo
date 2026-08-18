/**
 * Tests for Qt Item Models & AppController — UI models, filtering, dynamic formula variable autocomplete,
 * role management, quincena switching, and controller delegation.
 */

#include <QTest>
#include "database/DatabaseManager.h"
#include "controllers/AppController.h"
#include "models/EmployeeModel.h"
#include "models/EmployeeVarsModel.h"
#include "models/GlobalVarsModel.h"
#include "models/SchemaModel.h"
#include "models/CategoryModel.h"
#include "models/CellModel.h"
#include "models/ChartCellModel.h"
#include "models/CustomFunctionModel.h"

class TestModelsAndController : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void cleanup();

    // ── EmployeeModel ─────────────────────────────────────────
    void testEmployeeModelFilter();
    void testEmployeeModelSelection();

    // ── EmployeeVarsModel ─────────────────────────────────────
    void testEmployeeVarsModelQuincenaSwitching();
    void testEmployeeVarsModelSetValue();

    // ── CellModel ─────────────────────────────────────────────
    void testCellModelSchemaFilter();

    // ── AppController ─────────────────────────────────────────
    void testAppControllerProperties();
    void testAppControllerFormulaVariablesHelper();
    void testAppControllerCompanyShortcuts();

private:
    DatabaseManager *m_db = nullptr;
    AppController *m_controller = nullptr;
    static int s_dbCounter;
};

int TestModelsAndController::s_dbCounter = 200;

void TestModelsAndController::init()
{
    m_db = new DatabaseManager(":memory:");
    m_controller = new AppController(m_db);
}

void TestModelsAndController::cleanup()
{
    delete m_controller;
    m_controller = nullptr;
    delete m_db;
    m_db = nullptr;
}

// ════════════════════════════════════════════════════════════════
// EmployeeModel
// ════════════════════════════════════════════════════════════════

void TestModelsAndController::testEmployeeModelFilter()
{
    m_db->saveEmployee(0, "101", "Gomez Ana", "mensual", "MENSUAL", 0, "2020-01-01", "");
    m_db->saveEmployee(0, "102", "Lopez Carlos", "mensual", "MENSUAL", 0, "2020-01-01", "");
    m_db->saveEmployee(0, "103", "Perez Maria", "mensual", "MENSUAL", 0, "2020-01-01", "");

    auto model = m_controller->employeeModel();
    model->refresh();
    QCOMPARE(model->rowCount(), 3);

    // Filter by text "Lopez"
    model->setFilterText("Lopez");
    QCOMPARE(model->rowCount(), 1);
    QModelIndex idx = model->index(0, 0);
    QCOMPARE(model->data(idx, EmployeeModel::NombreRole).toString(), "Lopez Carlos");

    // Clear filter
    model->setFilterText("");
    QCOMPARE(model->rowCount(), 3);
}

void TestModelsAndController::testEmployeeModelSelection()
{
    int id1 = m_db->saveEmployee(0, "201", "Emp One", "mensual", "MENSUAL", 0, "2020-01-01", "");
    auto model = m_controller->employeeModel();
    model->refresh();

    QCOMPARE(model->idAtRow(0), id1);
}

// ════════════════════════════════════════════════════════════════
// EmployeeVarsModel
// ════════════════════════════════════════════════════════════════

void TestModelsAndController::testEmployeeVarsModelQuincenaSwitching()
{
    m_db->saveSchema("", "JORNAL", "Comercio Jornalero", "jornal");
    int fId = m_db->addSchemaField("JORNAL", "horas_trabajadas", "Horas Trabajadas", "number", "0", 1);

    int empId = m_db->saveEmployee(0, "301", "Jornalero Model", "jornal", "JORNAL", 0, "2020-01-01", "");
    m_db->addQuincena(empId, "Q2");

    m_db->setEmployeeFieldValue(empId, fId, "Q1", "80");
    m_db->setEmployeeFieldValue(empId, fId, "Q2", "90");

    auto varsModel = m_controller->employeeVarsModel();
    varsModel->setEmployeeId(empId);
    varsModel->setQuincena("Q1");

    QCOMPARE(varsModel->rowCount(), 1);
    QModelIndex idxQ1 = varsModel->index(0, 0);
    QCOMPARE(varsModel->data(idxQ1, EmployeeVarsModel::ValueRole).toString(), "80");

    // Switch to Q2
    varsModel->setQuincena("Q2");
    QModelIndex idxQ2 = varsModel->index(0, 0);
    QCOMPARE(varsModel->data(idxQ2, EmployeeVarsModel::ValueRole).toString(), "90");
}

void TestModelsAndController::testEmployeeVarsModelSetValue()
{
    m_db->saveSchema("", "MENSUAL", "Comercio Mensual", "mensual");
    int fId = m_db->addSchemaField("MENSUAL", "sueldo_fijo", "Sueldo Fijo", "number", "0", 1);

    int empId = m_db->saveEmployee(0, "401", "Val Model Emp", "mensual", "MENSUAL", 0, "2020-01-01", "");

    auto varsModel = m_controller->employeeVarsModel();
    varsModel->setEmployeeId(empId);
    varsModel->setQuincena("Q1");

    // Set value via model method
    varsModel->setValue(0, "95000");

    QModelIndex idx = varsModel->index(0, 0);
    QCOMPARE(varsModel->data(idx, EmployeeVarsModel::ValueRole).toString(), "95000");

    // Check value saved in DB
    auto fVals = m_db->getEmployeeFieldValues(empId, "Q1");
    QCOMPARE(fVals.first().toMap()["value"].toString(), "95000");
}

// ════════════════════════════════════════════════════════════════
// CellModel
// ════════════════════════════════════════════════════════════════

void TestModelsAndController::testCellModelSchemaFilter()
{
    m_db->saveSchema("", "ESQ_A", "Esquema A", "mensual");
    m_db->saveSchema("", "ESQ_B", "Esquema B", "mensual");

    m_db->saveCell(0, "RECIBO", "c1", "Celda 1", "", "", "", "100", 10, "ESQ_A", "formula", 0, "", 0, true);
    m_db->saveCell(0, "RECIBO", "c2", "Celda 2", "", "", "", "200", 20, "ESQ_B", "formula", 0, "", 0, true);

    auto cellModel = m_controller->cellModel();
    cellModel->setEsquemaCodigo("ESQ_A");
    cellModel->refresh();
    QCOMPARE(cellModel->rowCount(), 1);
    QModelIndex idx = cellModel->index(0, 0);
    QCOMPARE(cellModel->data(idx, CellModel::CodigoVariableRole).toString(), "c1");

    cellModel->setEsquemaCodigo("ESQ_B");
    cellModel->refresh();
    QCOMPARE(cellModel->rowCount(), 1);
    QModelIndex idxB = cellModel->index(0, 0);
    QCOMPARE(cellModel->data(idxB, CellModel::CodigoVariableRole).toString(), "c2");
}

// ════════════════════════════════════════════════════════════════
// AppController
// ════════════════════════════════════════════════════════════════

void TestModelsAndController::testAppControllerProperties()
{
    QCOMPARE(m_controller->currentRole(), "admin");
    m_controller->setCurrentRole("user");
    QCOMPARE(m_controller->currentRole(), "user");

    m_controller->setDarkMode(true);
    QCOMPARE(m_controller->darkMode(), true);
}

void TestModelsAndController::testAppControllerFormulaVariablesHelper()
{
    m_db->saveSchema("", "MENSUAL", "Comercio Mensual", "mensual");

    // Populate schema fields, global vars, categories
    m_db->addSchemaField("MENSUAL", "basico_input", "Básico Input", "number", "0", 1);
    m_db->saveGlobalVariable(0, "tope_global", "100000", "Tope Global");
    m_db->saveCell(0, "RECIBO", "remunerativo_total", "Total Remunerativo", "", "", "", "100", 10, "MENSUAL", "formula", 0, "", 0, true);

    QVariantList vars = m_controller->getAvailableFormulaVariables("MENSUAL");
    QVERIFY(!vars.isEmpty());

    bool foundInput = false, foundGlobal = false, foundCell = false;
    for (const auto &v : vars) {
        auto m = v.toMap();
        QString code = m["code"].toString();
        if (code == "basico_input") foundInput = true;
        if (code == "tope_global") foundGlobal = true;
        if (code == "remunerativo_total") foundCell = true;
    }

    QVERIFY(foundInput);
    QVERIFY(foundGlobal);
    QVERIFY(foundCell);
}

void TestModelsAndController::testAppControllerCompanyShortcuts()
{
    QVERIFY(m_controller->saveCompany("Compañía Test S.R.L.", "Calle Falsa 123", "30-99999999-7", "Mendoza"));

    auto company = m_controller->getCompany();
    QCOMPARE(company["razon_social"].toString(), "Compañía Test S.R.L.");
    QCOMPARE(company["cuit"].toString(), "30-99999999-7");
}

#include "tst_ModelsAndController.moc"

QObject *createTestModelsAndController() { return new TestModelsAndController(); }
