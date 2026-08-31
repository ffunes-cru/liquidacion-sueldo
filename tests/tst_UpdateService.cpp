#include <QObject>
#include <QTest>
#include "services/UpdateService.h"

class tst_UpdateService : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void testSanitizeVersion();
    void testSemVerComparison();
    void testUpdateServiceInitialProperties();
    void testAutoCheckSettings();
};

void tst_UpdateService::initTestCase()
{
    QCoreApplication::setOrganizationName("AntigravityTests");
    QCoreApplication::setApplicationName("LiquidacionSueldosTest");
}

void tst_UpdateService::testSanitizeVersion()
{
    QCOMPARE(UpdateService::sanitizeVersion("v1.0.0"), "1.0.0");
    QCOMPARE(UpdateService::sanitizeVersion("V2.1.3"), "2.1.3");
    QCOMPARE(UpdateService::sanitizeVersion("  v1.5.0  "), "1.5.0");
    QCOMPARE(UpdateService::sanitizeVersion("3.0.0"), "3.0.0");
    QCOMPARE(UpdateService::sanitizeVersion(""), "");
}

void tst_UpdateService::testSemVerComparison()
{
    // Newer patches
    QVERIFY(UpdateService::isVersionNewer("1.0.0", "1.0.1"));
    QVERIFY(UpdateService::isVersionNewer("1.0.0", "1.0.10"));
    QVERIFY(UpdateService::isVersionNewer("v1.0.0", "v1.0.1"));

    // Newer minor versions
    QVERIFY(UpdateService::isVersionNewer("1.0.9", "1.1.0"));
    QVERIFY(UpdateService::isVersionNewer("1.0.0", "1.5.0"));

    // Newer major versions
    QVERIFY(UpdateService::isVersionNewer("1.9.9", "2.0.0"));
    QVERIFY(UpdateService::isVersionNewer("0.9.0", "1.0.0"));

    // Equal versions
    QVERIFY(!UpdateService::isVersionNewer("1.0.0", "1.0.0"));
    QVERIFY(!UpdateService::isVersionNewer("v1.2.3", "1.2.3"));

    // Older versions
    QVERIFY(!UpdateService::isVersionNewer("1.0.1", "1.0.0"));
    QVERIFY(!UpdateService::isVersionNewer("2.0.0", "1.9.9"));
    QVERIFY(!UpdateService::isVersionNewer("1.2.0", "1.1.9"));

    // Pre-release tags
    QVERIFY(UpdateService::isVersionNewer("1.0.0", "1.0.1-rc1"));
    QVERIFY(!UpdateService::isVersionNewer("1.0.0", "1.0.0-beta"));

    // Empty or invalid
    QVERIFY(!UpdateService::isVersionNewer("1.0.0", ""));
}

void tst_UpdateService::testUpdateServiceInitialProperties()
{
    UpdateService service;
    QCOMPARE(service.currentVersion(), "1.0.0");
    QCOMPARE(service.isChecking(), false);
    QCOMPARE(service.isDownloading(), false);
    QCOMPARE(service.isUpdateAvailable(), false);
    QCOMPARE(service.isReadyToInstall(), false);
    QCOMPARE(service.downloadProgress(), 0.0);
}

void tst_UpdateService::testAutoCheckSettings()
{
    UpdateService service;
    bool initial = service.autoCheckOnStartup();
    service.setAutoCheckOnStartup(!initial);
    QCOMPARE(service.autoCheckOnStartup(), !initial);
    service.setAutoCheckOnStartup(initial);
    QCOMPARE(service.autoCheckOnStartup(), initial);
}

QObject *createTestUpdateService()
{
    return new tst_UpdateService();
}

#include "tst_UpdateService.moc"
