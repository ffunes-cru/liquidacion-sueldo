#include <QDebug>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "controllers/AppController.h"
#include "database/DatabaseManager.h"

int main(int argc, char *argv[]) {
  QGuiApplication app(argc, argv);
  app.setOrganizationName("Antigravity");
  app.setApplicationName("LiquidacionSueldosQML");

  DatabaseManager dbManager;
  if (!dbManager.isOpen()) {
    qCritical() << "No se pudo abrir la base de datos SQLite.";
    return 1;
  }

  AppController appController(&dbManager);

  QQmlApplicationEngine engine;

  // Register AppController as a modern Qt 6 Singleton Instance
  qmlRegisterSingletonInstance("LiquidacionSueldos", 1, 0, "AppController",
                               &appController);
  qmlRegisterUncreatableType<SchemaModel>(
      "LiquidacionSueldos", 1, 0, "SchemaModel",
      "El modelo se obtiene de AppController");

  const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreated, &app,
      [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
          QCoreApplication::exit(-1);
      },
      Qt::QueuedConnection);

  engine.load(url);

  return app.exec();
}
