/**
 * Test runner main. Each test class is self-contained; we run them all from a
 * single executable via QTest::qExec dispatching.
 *
 * QCoreApplication is required for QJSEngine and QSqlDatabase.
 */

#include <QCoreApplication>
#include <QTest>

// Factory functions — return QObject* to avoid incomplete type issues.
// Defined in their respective .cpp files.
extern QObject *createTestFormulaEngine();
extern QObject *createTestQuincenaAggregator();
extern QObject *createTestLiquidationEngine();
extern QObject *createTestDatabaseManager();
extern QObject *createTestModelsAndController();

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    int status = 0;

    {
        QObject *t = createTestFormulaEngine();
        status |= QTest::qExec(t, argc, argv);
        delete t;
    }
    {
        QObject *t = createTestQuincenaAggregator();
        status |= QTest::qExec(t, argc, argv);
        delete t;
    }
    {
        QObject *t = createTestLiquidationEngine();
        status |= QTest::qExec(t, argc, argv);
        delete t;
    }
    {
        QObject *t = createTestDatabaseManager();
        status |= QTest::qExec(t, argc, argv);
        delete t;
    }
    {
        QObject *t = createTestModelsAndController();
        status |= QTest::qExec(t, argc, argv);
        delete t;
    }

    return status;
}
