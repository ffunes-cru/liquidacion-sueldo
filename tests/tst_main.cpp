#include <QCoreApplication>
#include <QTest>
#include <QMetaObject>
#include <QMetaMethod>
#include <QString>
#include <QList>
#include <functional>

// Factory functions — return QObject* to avoid incomplete type issues.
// Defined in their respective .cpp files.
extern QObject *createTestFormulaEngine();
extern QObject *createTestQuincenaAggregator();
extern QObject *createTestLiquidationEngine();
extern QObject *createTestDatabaseManager();
extern QObject *createTestModelsAndController();

static bool shouldRunTestObject(QObject *obj, int argc, char *argv[])
{
    bool hasCustomFilter = false;
    for (int i = 1; i < argc; ++i) {
        QString arg = QString::fromLocal8Bit(argv[i]);
        if (!arg.startsWith('-')) {
            hasCustomFilter = true;
            const QMetaObject *mo = obj->metaObject();
            for (int m = 0; m < mo->methodCount(); ++m) {
                QMetaMethod method = mo->method(m);
                if (method.name() == arg.toLatin1()) {
                    return true;
                }
            }
        }
    }
    return !hasCustomFilter;
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    int status = 0;

    QList<std::function<QObject*()>> factories = {
        createTestFormulaEngine,
        createTestQuincenaAggregator,
        createTestLiquidationEngine,
        createTestDatabaseManager,
        createTestModelsAndController
    };

    for (auto &factory : factories) {
        QObject *t = factory();
        if (shouldRunTestObject(t, argc, argv)) {
            status |= QTest::qExec(t, argc, argv);
        }
        delete t;
    }

    return status;
}
