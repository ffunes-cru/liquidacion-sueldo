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

#include <QDebug>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "controllers/AppController.h"
#include "database/DatabaseManager.h"

int main(int argc, char *argv[]) {
  QQuickStyle::setStyle("Basic");
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
