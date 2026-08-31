/*
 * Sistema de Liquidación de Sueldos
 * Copyright (C) 2026
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <QApplication>
#include <QDebug>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include <QMessageBox>

#include "controllers/AppController.h"
#include "database/DatabaseManager.h"

int main(int argc, char *argv[]) {
  QQuickStyle::setStyle("Basic");
  QApplication app(argc, argv);
  app.setOrganizationName("Antigravity");
  app.setApplicationName("LiquidacionSueldosQML");

  DatabaseManager dbManager;
  if (dbManager.isLockedByOtherInstance()) {
    QMessageBox::critical(
        nullptr, "Aplicación ya en ejecución",
        QString("La base de datos se encuentra bloqueada por otra instancia "
                "del programa en ejecución (PID: %1).\n\n"
                "No es posible abrir dos instancias al mismo tiempo para "
                "evitar la corrupción de datos.")
            .arg(dbManager.lockingPid() > 0
                     ? QString::number(dbManager.lockingPid())
                     : "desconocido"));
    return 1;
  }

  if (!dbManager.isOpen()) {
    QMessageBox::critical(
        nullptr, "Error de Base de Datos",
        "Fallo crítico: No se pudo abrir la base de datos SQLite.");
    return 1;
  }

  AppController appController(&dbManager);

  QQmlApplicationEngine engine;
  engine.addImportPath(QCoreApplication::applicationDirPath() + "/qml");
  engine.addImportPath(QCoreApplication::applicationDirPath());

  // Register AppController as a modern Qt 6 Singleton Instance
  qmlRegisterSingletonInstance("LiquidacionSueldos", 1, 0, "AppController",
                               &appController);
  qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/qml/components/Theme.qml")),
                           "LiquidacionSueldos", 1, 0, "Theme");
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
