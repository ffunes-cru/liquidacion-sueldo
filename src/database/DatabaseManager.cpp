#include "DatabaseManager.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QDebug>

static const char *DB_FILENAME = "liquidacion_sueldos.db";

DatabaseManager::DatabaseManager(const QString &dbPath, QObject *parent)
    : QObject(parent)
{
    if (dbPath.isEmpty()) {
        m_dbPath = QCoreApplication::applicationDirPath() + "/" + DB_FILENAME;
    } else {
        m_dbPath = dbPath;
    }

    // Single-instance database lock check (skip for in-memory DBs used in tests)
    if (m_dbPath != ":memory:") {
        m_lockFile = new QLockFile(m_dbPath + ".lock");
        m_lockFile->setStaleLockTime(30000); // 30s stale lock threshold

        if (!m_lockFile->tryLock(100)) {
            m_isLockedByOtherInstance = true;
            m_lockFile->getLockInfo(&m_lockingPid, nullptr, nullptr);
            m_lockError = QString("La base de datos '%1' se encuentra en uso por otro proceso (PID: %2).")
                              .arg(m_dbPath)
                              .arg(m_lockingPid > 0 ? QString::number(m_lockingPid) : "desconocido");
            qWarning() << "[DatabaseManager]" << m_lockError;
            return;
        }
    }

    qDebug() << "[DatabaseManager] Abriendo base de datos SQLite en:" << m_dbPath;

    m_db = QSqlDatabase::addDatabase("QSQLITE", QString::number(reinterpret_cast<quintptr>(this)));
    m_db.setDatabaseName(m_dbPath);

    if (!m_db.open()) {
        qCritical() << "[DatabaseManager] Fallo crítico al abrir base de datos:" << m_db.lastError().text();
        return;
    }

    QSqlQuery q(m_db);
    q.exec("PRAGMA foreign_keys = ON");
    q.exec("PRAGMA journal_mode = WAL");

    createTables();
    runMigrations();

    qInfo() << "[DatabaseManager] Base de datos inicializada correctamente en:" << m_dbPath;
}

DatabaseManager::~DatabaseManager()
{
    if (m_db.isOpen()) {
        qDebug() << "[DatabaseManager] Cerrando conexión de base de datos.";
        m_db.close();
    }

    if (m_lockFile) {
        if (m_lockFile->isLocked()) {
            m_lockFile->unlock();
        }
        delete m_lockFile;
        m_lockFile = nullptr;
    }
}

bool DatabaseManager::isOpen() const
{
    return m_db.isOpen();
}

bool DatabaseManager::isLockedByOtherInstance() const
{
    return m_isLockedByOtherInstance;
}

QString DatabaseManager::lockError() const
{
    return m_lockError;
}

qint64 DatabaseManager::lockingPid() const
{
    return m_lockingPid;
}

QString DatabaseManager::databasePath() const
{
    return m_dbPath;
}

void DatabaseManager::createTables()
{
    qDebug() << "[DatabaseManager] Creando tablas del esquema si no existen...";
    QSqlQuery q(m_db);

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS esquemas_calculo (
            codigo            TEXT PRIMARY KEY,
            nombre            TEXT NOT NULL,
            tipo_liquidacion  TEXT NOT NULL DEFAULT 'mensual'
        )
    )");

    q.exec("INSERT OR IGNORE INTO esquemas_calculo (codigo, nombre, tipo_liquidacion) VALUES ('MENSUAL', 'Comercio Mensualizado', 'mensual')");
    q.exec("INSERT OR IGNORE INTO esquemas_calculo (codigo, nombre, tipo_liquidacion) VALUES ('JORNAL', 'Comercio Jornalero (Por hora)', 'jornal')");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS categorias_jornal (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre     TEXT    UNIQUE NOT NULL,
            valor_hora REAL    NOT NULL
        )
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS secciones (
            id     INTEGER PRIMARY KEY AUTOINCREMENT,
            codigo TEXT    UNIQUE NOT NULL,
            titulo TEXT    NOT NULL,
            orden  INTEGER NOT NULL DEFAULT 0
        )
    )");

    q.exec("SELECT COUNT(*) FROM secciones");
    if (q.next() && q.value(0).toInt() == 0) {
        qDebug() << "[DatabaseManager] Sembrando secciones por defecto (COMPOSICION, RECIBO, COSTO_EMP)...";
        q.exec("INSERT INTO secciones (codigo, titulo, orden) VALUES ('COMPOSICION', 'Composición Salarial', 10)");
        q.exec("INSERT INTO secciones (codigo, titulo, orden) VALUES ('RECIBO', 'Recibo de Sueldo', 20)");
        q.exec("INSERT INTO secciones (codigo, titulo, orden) VALUES ('COSTO_EMP', 'Costo Empleador', 30)");
    }

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS empleados (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            legajo              TEXT,
            nombre_completo     TEXT    NOT NULL,
            tipo_liquidacion    TEXT    NOT NULL DEFAULT 'mensual',
            esquema_codigo      TEXT    REFERENCES esquemas_calculo(codigo) DEFAULT 'MENSUAL',
            categoria_jornal_id INTEGER REFERENCES categorias_jornal(id),
            fecha_ingreso       TEXT    DEFAULT '2020-01-01',
            cuil                TEXT    DEFAULT '',
            activo              INTEGER DEFAULT 1
        )
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS schema_fields (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            esquema_codigo  TEXT    NOT NULL REFERENCES esquemas_calculo(codigo) ON DELETE CASCADE,
            field_code      TEXT    NOT NULL,
            field_label     TEXT    NOT NULL,
            field_type      TEXT    NOT NULL DEFAULT 'number',
            default_value   TEXT    NOT NULL DEFAULT '0',
            display_order   INTEGER NOT NULL DEFAULT 0,
            UNIQUE(esquema_codigo, field_code)
        )
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS employee_field_values (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            empleado_id INTEGER NOT NULL REFERENCES empleados(id) ON DELETE CASCADE,
            field_id    INTEGER NOT NULL REFERENCES schema_fields(id) ON DELETE CASCADE,
            quincena    TEXT    NOT NULL DEFAULT 'Q1',
            value       TEXT    NOT NULL DEFAULT '0',
            UNIQUE(empleado_id, field_id, quincena)
        )
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS quincenas_empleado (
            empleado_id INTEGER NOT NULL REFERENCES empleados(id) ON DELETE CASCADE,
            quincena    TEXT    NOT NULL,
            PRIMARY KEY(empleado_id, quincena)
        )
    )");

    // Seed Q1 in quincenas_empleado for any existing employees
    q.exec("INSERT OR IGNORE INTO quincenas_empleado (empleado_id, quincena) SELECT id, 'Q1' FROM empleados");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS celdas_calculo (
            id                   INTEGER PRIMARY KEY AUTOINCREMENT,
            seccion_codigo       TEXT    NOT NULL REFERENCES secciones(codigo),
            codigo_variable      TEXT    NOT NULL,
            descripcion          TEXT    NOT NULL,
            condicion            TEXT    DEFAULT '',
            formula_unidad       TEXT    DEFAULT '',
            formula_base         TEXT    DEFAULT '',
            formula_monto        TEXT    NOT NULL,
            orden                INTEGER NOT NULL DEFAULT 0,
            esquema_codigo       TEXT    REFERENCES esquemas_calculo(codigo) DEFAULT 'MENSUAL',
            tipo_calculo         TEXT    NOT NULL DEFAULT 'formula',
            simple_porcentaje    REAL,
            simple_base_variable TEXT,
            simple_monto_fijo    REAL,
            visible_recibo       INTEGER DEFAULT 1,
            color_hex            TEXT DEFAULT '',
            en_grafico           INTEGER DEFAULT 0,
            es_grafico_total     INTEGER DEFAULT 0,
            UNIQUE(esquema_codigo, codigo_variable)
        )
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS celdas_grafico (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            etiqueta        TEXT    NOT NULL,
            formula         TEXT    NOT NULL,
            orden           INTEGER NOT NULL DEFAULT 0,
            esquema_codigo  TEXT    REFERENCES esquemas_calculo(codigo) DEFAULT 'MENSUAL',
            UNIQUE(esquema_codigo, etiqueta)
        )
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS variables_globales (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            codigo      TEXT    UNIQUE NOT NULL,
            valor       TEXT    NOT NULL,
            descripcion TEXT    DEFAULT ''
        )
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS empresa (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            razon_social   TEXT    NOT NULL DEFAULT '',
            direccion      TEXT    DEFAULT '',
            cuit           TEXT    DEFAULT '',
            lugar_de_pago  TEXT    DEFAULT ''
        )
    )");
    q.exec("SELECT COUNT(*) FROM empresa");
    if (q.next() && q.value(0).toInt() == 0) {
        q.exec("INSERT INTO empresa (razon_social) VALUES ('')");
    }

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS recibos (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            empleado_id    INTEGER NOT NULL REFERENCES empleados(id),
            esquema_codigo TEXT    NOT NULL,
            mes            INTEGER NOT NULL,
            anio           INTEGER NOT NULL,
            periodo        TEXT    NOT NULL DEFAULT 'M',
            datos_json     TEXT    NOT NULL,
            fecha_emision  TEXT    NOT NULL,
            UNIQUE(empleado_id, esquema_codigo, mes, anio, periodo)
        )
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS configuraciones (
            clave TEXT PRIMARY KEY,
            valor TEXT NOT NULL
        )
    )");

    q.exec(R"(
        CREATE TABLE IF NOT EXISTS custom_functions (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            name            TEXT UNIQUE NOT NULL,
            params          TEXT NOT NULL DEFAULT '',
            body            TEXT NOT NULL,
            description     TEXT DEFAULT '',
            esquema_codigo  TEXT DEFAULT ''
        )
    )");
}

void DatabaseManager::runMigrations()
{
    QSqlQuery q(m_db);
    q.exec("ALTER TABLE empleados ADD COLUMN activo INTEGER DEFAULT 1");
    q.exec("ALTER TABLE celdas_calculo ADD COLUMN color_hex TEXT DEFAULT ''");
    q.exec("ALTER TABLE celdas_calculo ADD COLUMN en_grafico INTEGER DEFAULT 0");
    q.exec("ALTER TABLE celdas_calculo ADD COLUMN es_grafico_total INTEGER DEFAULT 0");

    // Sembrar funciones de historial estándar si no existen
    auto seedFunc = [this](const QString &name, const QString &params, const QString &body, const QString &desc) {
        QSqlQuery sf(m_db);
        sf.prepare("INSERT OR IGNORE INTO custom_functions (name, params, body, description, esquema_codigo) VALUES (?, ?, ?, ?, '')");
        sf.addBindValue(name);
        sf.addBindValue(params);
        sf.addBindValue(body);
        sf.addBindValue(desc);
        sf.exec();
    };

    seedFunc("mejor_sueldo", "varName, cantMeses",
             "var maxVal = 0;\n"
             "var list = (typeof env !== 'undefined' && env && env.historial) ? env.historial : [];\n"
             "var limit = cantMeses || list.length;\n"
             "for (var i = 0; i < Math.min(list.length, limit); i++) {\n"
             "    var val = Number(list[i][varName]) || 0;\n"
             "    if (val > maxVal) maxVal = val;\n"
             "}\n"
             "return maxVal;",
             "Calcula el mejor valor histórico de una variable (ej. SAC / Aguinaldo) en los últimos N meses del historial.");

    seedFunc("promedio_historial", "varName, cantMeses",
             "var total = 0;\n"
             "var count = 0;\n"
             "var list = (typeof env !== 'undefined' && env && env.historial) ? env.historial : [];\n"
             "var limit = cantMeses || list.length;\n"
             "for (var i = 0; i < Math.min(list.length, limit); i++) {\n"
             "    total += Number(list[i][varName]) || 0;\n"
             "    count++;\n"
             "}\n"
             "return count > 0 ? (total / count) : 0;",
             "Calcula el promedio de una variable histórica en los últimos N meses (ej. promedio de horas extras para vacaciones).");

    seedFunc("sumar_historial", "varName, cantMeses",
             "var total = 0;\n"
             "var list = (typeof env !== 'undefined' && env && env.historial) ? env.historial : [];\n"
             "var limit = cantMeses || list.length;\n"
             "for (var i = 0; i < Math.min(list.length, limit); i++) {\n"
             "    total += Number(list[i][varName]) || 0;\n"
             "}\n"
             "return total;",
             "Suma acumulada de una variable en los últimos N meses del historial.");
}

QVariantList DatabaseManager::listSchemas() const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.exec("SELECT codigo, nombre, tipo_liquidacion FROM esquemas_calculo ORDER BY codigo");
    while (q.next()) {
        result.append(QVariantMap{
            {"codigo", q.value("codigo")},
            {"nombre", q.value("nombre")},
            {"tipo_liquidacion", q.value("tipo_liquidacion")},
        });
    }
    return result;
}

QVariantMap DatabaseManager::getSchema(const QString &code) const
{
    QSqlQuery q(m_db);
    q.prepare("SELECT codigo, nombre, tipo_liquidacion FROM esquemas_calculo WHERE codigo = ?");
    q.addBindValue(code);
    q.exec();
    if (q.next()) {
        return {
            {"codigo", q.value("codigo")},
            {"nombre", q.value("nombre")},
            {"tipo_liquidacion", q.value("tipo_liquidacion")},
        };
    }
    return {};
}

bool DatabaseManager::saveSchema(const QString &originalCode, const QString &newCode,
                                  const QString &name, const QString &tipoLiquidacion)
{
    qInfo() << "[DatabaseManager] Guardando esquema de cálculo:" << newCode << "Nombre:" << name;
    QSqlQuery q(m_db);
    if (!originalCode.isEmpty()) {
        q.prepare("UPDATE esquemas_calculo SET codigo=?, nombre=?, tipo_liquidacion=? WHERE codigo=?");
        q.addBindValue(newCode);
        q.addBindValue(name);
        q.addBindValue(tipoLiquidacion);
        q.addBindValue(originalCode);
    } else {
        q.prepare("INSERT INTO esquemas_calculo (codigo, nombre, tipo_liquidacion) VALUES (?, ?, ?)");
        q.addBindValue(newCode);
        q.addBindValue(name);
        q.addBindValue(tipoLiquidacion);
    }
    return q.exec();
}

bool DatabaseManager::deleteSchema(const QString &code)
{
    qInfo() << "[DatabaseManager] Intentando eliminar esquema de cálculo:" << code;
    QSqlQuery check(m_db);
    check.prepare("SELECT COUNT(*) FROM empleados WHERE esquema_codigo = ?");
    check.addBindValue(code);
    check.exec();
    if (check.next() && check.value(0).toInt() > 0) {
        qWarning() << "[DatabaseManager] No se puede eliminar el esquema" << code << "porque posee empleados asignados.";
        return false;
    }

    QSqlQuery q(m_db);
    q.prepare("DELETE FROM celdas_calculo WHERE esquema_codigo = ?");
    q.addBindValue(code);
    q.exec();

    q.prepare("DELETE FROM celdas_grafico WHERE esquema_codigo = ?");
    q.addBindValue(code);
    q.exec();

    q.prepare("DELETE FROM schema_fields WHERE esquema_codigo = ?");
    q.addBindValue(code);
    q.exec();

    q.prepare("DELETE FROM esquemas_calculo WHERE codigo = ?");
    q.addBindValue(code);
    return q.exec();
}

QVariantList DatabaseManager::listCategories() const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.exec("SELECT id, nombre, valor_hora FROM categorias_jornal ORDER BY nombre");
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"nombre", q.value("nombre")},
            {"valor_hora", q.value("valor_hora")},
        });
    }
    return result;
}

QVariantMap DatabaseManager::getCategory(int id) const
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, nombre, valor_hora FROM categorias_jornal WHERE id = ?");
    q.addBindValue(id);
    q.exec();
    if (q.next()) {
        return {
            {"id", q.value("id")},
            {"nombre", q.value("nombre")},
            {"valor_hora", q.value("valor_hora")},
        };
    }
    return {};
}

int DatabaseManager::saveCategory(int id, const QString &name, double valorHora)
{
    qInfo() << "[DatabaseManager] Guardando categoría jornalera ID:" << id << "Nombre:" << name << "Valor/hora:" << valorHora;
    QSqlQuery q(m_db);
    if (id > 0) {
        q.prepare("UPDATE categorias_jornal SET nombre=?, valor_hora=? WHERE id=?");
        q.addBindValue(name);
        q.addBindValue(valorHora);
        q.addBindValue(id);
        q.exec();
        return id;
    } else {
        q.prepare("INSERT INTO categorias_jornal (nombre, valor_hora) VALUES (?, ?)");
        q.addBindValue(name);
        q.addBindValue(valorHora);
        q.exec();
        return q.lastInsertId().toInt();
    }
}

bool DatabaseManager::deleteCategory(int id)
{
    qInfo() << "[DatabaseManager] Eliminando categoría jornalera ID:" << id;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM categorias_jornal WHERE id = ?");
    q.addBindValue(id);
    return q.exec();
}

QVariantList DatabaseManager::listSections() const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.exec("SELECT id, codigo, titulo, orden FROM secciones ORDER BY orden, id");
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"codigo", q.value("codigo")},
            {"titulo", q.value("titulo")},
            {"orden", q.value("orden")},
        });
    }
    return result;
}

QVariantList DatabaseManager::listEmployees() const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.exec(R"(
        SELECT e.*, c.nombre AS categoria_nombre
        FROM empleados e
        LEFT JOIN categorias_jornal c ON c.id = e.categoria_jornal_id
        WHERE e.activo = 1 OR e.activo IS NULL
        ORDER BY e.legajo
    )");
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"legajo", q.value("legajo")},
            {"nombre_completo", q.value("nombre_completo")},
            {"tipo_liquidacion", q.value("tipo_liquidacion")},
            {"esquema_codigo", q.value("esquema_codigo")},
            {"categoria_jornal_id", q.value("categoria_jornal_id")},
            {"fecha_ingreso", q.value("fecha_ingreso")},
            {"cuil", q.value("cuil")},
            {"categoria_nombre", q.value("categoria_nombre")},
        });
    }
    return result;
}

QVariantMap DatabaseManager::getEmployee(int id) const
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT e.*, c.nombre AS categoria_nombre
        FROM empleados e
        LEFT JOIN categorias_jornal c ON c.id = e.categoria_jornal_id
        WHERE e.id = ?
    )");
    q.addBindValue(id);
    q.exec();
    if (q.next()) {
        return {
            {"id", q.value("id")},
            {"legajo", q.value("legajo")},
            {"nombre_completo", q.value("nombre_completo")},
            {"tipo_liquidacion", q.value("tipo_liquidacion")},
            {"esquema_codigo", q.value("esquema_codigo")},
            {"categoria_jornal_id", q.value("categoria_jornal_id")},
            {"fecha_ingreso", q.value("fecha_ingreso")},
            {"cuil", q.value("cuil")},
            {"categoria_nombre", q.value("categoria_nombre")},
        };
    }
    return {};
}

int DatabaseManager::saveEmployee(int id, const QString &legajo, const QString &nombre,
                                   const QString &tipoLiq, const QString &esquemaCodigo,
                                   int categoriaJornalId, const QString &fechaIngreso,
                                   const QString &cuil)
{
    // Ensure scheme code exists in esquemas_calculo to prevent foreign key errors
    QString safeEsquema = esquemaCodigo.trimmed().isEmpty() ? "MENSUAL" : esquemaCodigo.trimmed().toUpper();
    QSqlQuery checkEsq(m_db);
    checkEsq.prepare("SELECT codigo FROM esquemas_calculo WHERE codigo = ?");
    checkEsq.addBindValue(safeEsquema);
    checkEsq.exec();
    if (!checkEsq.next()) {
        QSqlQuery insEsq(m_db);
        insEsq.prepare("INSERT OR IGNORE INTO esquemas_calculo (codigo, nombre, tipo_liquidacion) VALUES (?, ?, ?)");
        insEsq.addBindValue(safeEsquema);
        insEsq.addBindValue(safeEsquema);
        insEsq.addBindValue(tipoLiq);
        insEsq.exec();
    }

    bool exists = false;
    if (id > 0) {
        QSqlQuery chk(m_db);
        chk.prepare("SELECT id FROM empleados WHERE id = ?");
        chk.addBindValue(id);
        chk.exec();
        exists = chk.next();
    }

    QSqlQuery q(m_db);
    if (exists) {
        q.prepare("UPDATE empleados SET legajo=?, nombre_completo=?, tipo_liquidacion=?, esquema_codigo=?, categoria_jornal_id=?, fecha_ingreso=?, cuil=? WHERE id=?");
        q.bindValue(0, legajo);
        q.bindValue(1, nombre);
        q.bindValue(2, tipoLiq);
        q.bindValue(3, safeEsquema);
        q.bindValue(4, categoriaJornalId > 0 ? QVariant(categoriaJornalId) : QVariant(QMetaType(QMetaType::Int)));
        q.bindValue(5, fechaIngreso);
        q.bindValue(6, cuil);
        q.bindValue(7, id);
        if (!q.exec()) {
            qCritical() << "[DatabaseManager] Error al actualizar empleado ID" << id << ":" << q.lastError().text();
            return -1;
        }
        return id;
    } else {
        if (id > 0) {
            q.prepare("INSERT INTO empleados (id, legajo, nombre_completo, tipo_liquidacion, esquema_codigo, categoria_jornal_id, fecha_ingreso, cuil) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
            q.bindValue(0, id);
            q.bindValue(1, legajo);
            q.bindValue(2, nombre);
            q.bindValue(3, tipoLiq);
            q.bindValue(4, safeEsquema);
            q.bindValue(5, categoriaJornalId > 0 ? QVariant(categoriaJornalId) : QVariant(QMetaType(QMetaType::Int)));
            q.bindValue(6, fechaIngreso);
            q.bindValue(7, cuil);
        } else {
            q.prepare("INSERT INTO empleados (legajo, nombre_completo, tipo_liquidacion, esquema_codigo, categoria_jornal_id, fecha_ingreso, cuil) VALUES (?, ?, ?, ?, ?, ?, ?)");
            q.bindValue(0, legajo);
            q.bindValue(1, nombre);
            q.bindValue(2, tipoLiq);
            q.bindValue(3, safeEsquema);
            q.bindValue(4, categoriaJornalId > 0 ? QVariant(categoriaJornalId) : QVariant(QMetaType(QMetaType::Int)));
            q.bindValue(5, fechaIngreso);
            q.bindValue(6, cuil);
        }
        if (!q.exec()) {
            qCritical() << "[DatabaseManager] Error al insertar nuevo empleado:" << q.lastError().text();
            return -1;
        }
        int newId = (id > 0) ? id : q.lastInsertId().toInt();

        QSqlQuery insQ(m_db);
        insQ.prepare("INSERT OR IGNORE INTO quincenas_empleado (empleado_id, quincena) VALUES (?, 'Q1')");
        insQ.bindValue(0, newId);
        insQ.exec();

        syncEmployeeFieldsForSchema(safeEsquema);

        return newId;
    }
}

bool DatabaseManager::deleteEmployee(int id)
{
    qInfo() << "[DatabaseManager] Eliminando registro de empleado ID:" << id;

    // Si el empleado tiene recibos históricos asociados, realizamos un soft-delete
    // para preservar la integridad referencial y jurídica de los recibos emitidos.
    QSqlQuery check(m_db);
    check.prepare("SELECT COUNT(*) FROM recibos WHERE empleado_id = ?");
    check.addBindValue(id);
    check.exec();
    if (check.next() && check.value(0).toInt() > 0) {
        qInfo() << "[DatabaseManager] Empleado ID" << id << "posee recibos históricos. Marcando como inactivo (soft-delete).";
        QSqlQuery softDel(m_db);
        softDel.prepare("UPDATE empleados SET activo = 0 WHERE id = ?");
        softDel.addBindValue(id);
        return softDel.exec();
    }

    QSqlQuery q(m_db);
    q.prepare("DELETE FROM empleados WHERE id = ?");
    q.bindValue(0, id);
    return q.exec();
}

int DatabaseManager::duplicateEmployee(int sourceId)
{
    qInfo() << "[DatabaseManager] Duplicando datos de empleado origen ID:" << sourceId;
    auto emp = getEmployee(sourceId);
    if (emp.isEmpty()) return -1;

    int newId = saveEmployee(
        0,
        emp["legajo"].toString() + "_copia",
        emp["nombre_completo"].toString() + " (Copia)",
        emp["tipo_liquidacion"].toString(),
        emp["esquema_codigo"].toString(),
        emp["categoria_jornal_id"].toInt(),
        emp["fecha_ingreso"].toString(),
        emp["cuil"].toString()
    );

    if (newId <= 0) return -1;

    // Copy quincenas list
    QSqlQuery qQn(m_db);
    qQn.prepare(R"(
        INSERT OR IGNORE INTO quincenas_empleado (empleado_id, quincena)
        SELECT ?, quincena
        FROM quincenas_empleado
        WHERE empleado_id = ?
    )");
    qQn.bindValue(0, newId);
    qQn.bindValue(1, sourceId);
    qQn.exec();

    // Upsert field values
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO employee_field_values (empleado_id, field_id, quincena, value)
        SELECT ?, field_id, quincena, value
        FROM employee_field_values
        WHERE empleado_id = ?
        ON CONFLICT(empleado_id, field_id, quincena)
        DO UPDATE SET value = excluded.value
    )");
    q.bindValue(0, newId);
    q.bindValue(1, sourceId);
    q.exec();

    return newId;
}

QVariantList DatabaseManager::listSchemaFields(const QString &esquemaCodigo) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT * FROM schema_fields WHERE esquema_codigo = ? ORDER BY display_order, id");
    q.bindValue(0, esquemaCodigo);
    q.exec();
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"esquema_codigo", q.value("esquema_codigo")},
            {"field_code", q.value("field_code")},
            {"field_label", q.value("field_label")},
            {"field_type", q.value("field_type")},
            {"default_value", q.value("default_value")},
            {"display_order", q.value("display_order")},
        });
    }
    return result;
}

int DatabaseManager::addSchemaField(const QString &esquemaCodigo, const QString &fieldCode,
                                     const QString &fieldLabel, const QString &fieldType,
                                     const QString &defaultValue, int displayOrder)
{
    qInfo() << "[DatabaseManager] Agregando variable de entrada al esquema" << esquemaCodigo << ":" << fieldCode;
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO schema_fields (esquema_codigo, field_code, field_label, field_type, default_value, display_order) VALUES (?, ?, ?, ?, ?, ?)");
    q.bindValue(0, esquemaCodigo);
    q.bindValue(1, fieldCode);
    q.bindValue(2, fieldLabel);
    q.bindValue(3, fieldType);
    q.bindValue(4, defaultValue);
    q.bindValue(5, displayOrder);

    if (!q.exec()) {
        qWarning() << "[DatabaseManager] Error al agregar campo de esquema:" << q.lastError().text();
        return -1;
    }

    int fieldId = q.lastInsertId().toInt();
    syncEmployeeFieldsForSchema(esquemaCodigo);

    return fieldId;
}

QString DatabaseManager::validateVariableCode(const QString &code)
{
    if (code.trimmed().isEmpty()) {
        return "El código de variable no puede estar vacío.";
    }
    static const QRegularExpression validIdent(R"(^[A-Za-z_][A-Za-z0-9_]*$)");
    if (!validIdent.match(code.trimmed()).hasMatch()) {
        return "El código '" + code + "' no es válido. Solo se permiten letras, números y guión bajo (_). No puede contener espacios ni caracteres especiales.";
    }
    return "";
}

bool DatabaseManager::removeSchemaField(int fieldId)
{
    qInfo() << "[DatabaseManager] Eliminando campo de esquema ID:" << fieldId;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM schema_fields WHERE id = ?");
    q.addBindValue(fieldId);
    return q.exec();
}

bool DatabaseManager::renameSchemaField(int fieldId, const QString &newCode, const QString &newLabel)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE schema_fields SET field_code = ?, field_label = ? WHERE id = ?");
    q.addBindValue(newCode);
    q.addBindValue(newLabel);
    q.addBindValue(fieldId);
    return q.exec();
}

bool DatabaseManager::updateSchemaField(int fieldId, const QString &fieldCode, const QString &fieldLabel,
                                        const QString &fieldType, const QString &defaultValue)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE schema_fields SET field_code = ?, field_label = ?, field_type = ?, default_value = ? WHERE id = ?");
    q.addBindValue(fieldCode);
    q.addBindValue(fieldLabel);
    q.addBindValue(fieldType);
    q.addBindValue(defaultValue);
    q.addBindValue(fieldId);
    return q.exec();
}

QVariantList DatabaseManager::listAllSchemaFields() const
{
    QVariantList list;
    QSqlQuery q("SELECT id, esquema_codigo, field_code, field_label, field_type, default_value, display_order FROM schema_fields ORDER BY id", m_db);
    while (q.next()) {
        list.append(QVariantMap{
            {"id", q.value("id").toInt()},
            {"esquema_codigo", q.value("esquema_codigo").toString()},
            {"field_code", q.value("field_code").toString()},
            {"field_label", q.value("field_label").toString()},
            {"field_type", q.value("field_type").toString()},
            {"default_value", q.value("default_value").toString()},
            {"display_order", q.value("display_order").toInt()}
        });
    }
    return list;
}

QVariantList DatabaseManager::listAllEmployeeFieldValues() const
{
    QVariantList list;
    QSqlQuery q("SELECT id, empleado_id, field_id, quincena, value FROM employee_field_values ORDER BY id", m_db);
    while (q.next()) {
        list.append(QVariantMap{
            {"id", q.value("id").toInt()},
            {"empleado_id", q.value("empleado_id").toInt()},
            {"field_id", q.value("field_id").toInt()},
            {"quincena", q.value("quincena").toString()},
            {"value", q.value("value").toString()}
        });
    }
    return list;
}

QVariantList DatabaseManager::listAllEmployeeQuincenas() const
{
    QVariantList list;
    QSqlQuery q("SELECT empleado_id, quincena FROM quincenas_empleado", m_db);
    while (q.next()) {
        list.append(QVariantMap{
            {"empleado_id", q.value("empleado_id").toInt()},
            {"quincena", q.value("quincena").toString()}
        });
    }
    return list;
}

QVariantList DatabaseManager::getEmployeeFieldValues(int employeeId, const QString &quincena) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT sf.id AS field_id, sf.field_code, sf.field_label, sf.field_type,
               sf.default_value, sf.display_order,
               COALESCE(efv.value, sf.default_value) AS value
        FROM schema_fields sf
        JOIN empleados e ON e.esquema_codigo = sf.esquema_codigo
        LEFT JOIN employee_field_values efv
            ON efv.field_id = sf.id AND efv.empleado_id = e.id AND efv.quincena = ?
        WHERE e.id = ?
        ORDER BY sf.display_order, sf.id
    )");
    q.addBindValue(quincena);
    q.addBindValue(employeeId);
    q.exec();
    while (q.next()) {
        result.append(QVariantMap{
            {"field_id", q.value("field_id")},
            {"field_code", q.value("field_code")},
            {"field_label", q.value("field_label")},
            {"field_type", q.value("field_type")},
            {"default_value", q.value("default_value")},
            {"display_order", q.value("display_order")},
            {"value", q.value("value")},
        });
    }
    return result;
}

bool DatabaseManager::setEmployeeFieldValue(int employeeId, int fieldId,
                                              const QString &quincena, const QString &value)
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO employee_field_values (empleado_id, field_id, quincena, value)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(empleado_id, field_id, quincena)
        DO UPDATE SET value = excluded.value
    )");
    q.addBindValue(employeeId);
    q.addBindValue(fieldId);
    q.addBindValue(quincena);
    q.addBindValue(value);
    return q.exec();
}

bool DatabaseManager::setEmployeeFieldValues(int employeeId, const QString &quincena,
                                               const QVariantMap &values)
{
    m_db.transaction();
    for (auto it = values.begin(); it != values.end(); ++it) {
        QSqlQuery lookup(m_db);
        lookup.prepare(R"(
            SELECT sf.id FROM schema_fields sf
            JOIN empleados e ON e.esquema_codigo = sf.esquema_codigo
            WHERE e.id = ? AND sf.field_code = ?
        )");
        lookup.addBindValue(employeeId);
        lookup.addBindValue(it.key());
        lookup.exec();
        if (lookup.next()) {
            int fieldId = lookup.value(0).toInt();
            setEmployeeFieldValue(employeeId, fieldId, quincena, it.value().toString());
        }
    }
    return m_db.commit();
}

void DatabaseManager::syncEmployeeFieldsForSchema(const QString &esquemaCodigo)
{
    qDebug() << "[DatabaseManager] Sincronizando modelo de campos del esquema:" << esquemaCodigo << "con todos los empleados asignados.";
    QSqlQuery empQ(m_db);
    empQ.prepare("SELECT id, tipo_liquidacion FROM empleados WHERE esquema_codigo = ?");
    empQ.addBindValue(esquemaCodigo);
    empQ.exec();

    QList<QPair<int, QString>> employees;
    while (empQ.next()) {
        employees.append({empQ.value("id").toInt(), empQ.value("tipo_liquidacion").toString()});
    }

    QSqlQuery fieldQ(m_db);
    fieldQ.prepare("SELECT id, default_value FROM schema_fields WHERE esquema_codigo = ?");
    fieldQ.addBindValue(esquemaCodigo);
    fieldQ.exec();

    QList<QPair<int, QString>> fields;
    while (fieldQ.next()) {
        fields.append({fieldQ.value("id").toInt(), fieldQ.value("default_value").toString()});
    }

    m_db.transaction();
    for (const auto &[empId, tipoLiq] : employees) {
        QStringList quincenas = listEmployeeQuincenas(empId);
        if (quincenas.isEmpty()) {
            quincenas = {"Q1"};
        }

        if (tipoLiq != "jornal") {
            quincenas = {"Q1"};
        }

        for (const auto &qn : quincenas) {
            for (const auto &[fieldId, defaultVal] : fields) {
                QSqlQuery ins(m_db);
                ins.prepare(R"(
                    INSERT OR IGNORE INTO employee_field_values (empleado_id, field_id, quincena, value)
                    VALUES (?, ?, ?, ?)
                )");
                ins.addBindValue(empId);
                ins.addBindValue(fieldId);
                ins.addBindValue(qn);
                ins.addBindValue(defaultVal);
                ins.exec();
            }
        }
    }
    m_db.commit();
}

QStringList DatabaseManager::listEmployeeQuincenas(int employeeId) const
{
    QStringList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT quincena FROM quincenas_empleado WHERE empleado_id = ? ORDER BY quincena");
    q.addBindValue(employeeId);
    q.exec();
    while (q.next()) {
        result.append(q.value(0).toString());
    }
    if (result.isEmpty()) {
        QSqlQuery q2(m_db);
        q2.prepare("SELECT DISTINCT quincena FROM employee_field_values WHERE empleado_id = ? ORDER BY quincena");
        q2.addBindValue(employeeId);
        q2.exec();
        while (q2.next()) {
            result.append(q2.value(0).toString());
        }
    }
    if (result.isEmpty()) {
        result.append("Q1");
    }
    return result;
}

bool DatabaseManager::addQuincena(int employeeId, const QString &quincenaCode)
{
    qInfo() << "[DatabaseManager] Añadiendo quincena" << quincenaCode << "a empleado ID:" << employeeId;
    auto emp = getEmployee(employeeId);
    if (emp.isEmpty()) return false;

    QSqlQuery qIns(m_db);
    qIns.prepare("INSERT OR IGNORE INTO quincenas_empleado (empleado_id, quincena) VALUES (?, ?)");
    qIns.addBindValue(employeeId);
    qIns.addBindValue(quincenaCode);
    qIns.exec();

    QString esquema = emp["esquema_codigo"].toString();

    QSqlQuery fieldQ(m_db);
    fieldQ.prepare("SELECT id, default_value FROM schema_fields WHERE esquema_codigo = ?");
    fieldQ.addBindValue(esquema);
    fieldQ.exec();

    m_db.transaction();
    while (fieldQ.next()) {
        QSqlQuery ins(m_db);
        ins.prepare(R"(
            INSERT OR IGNORE INTO employee_field_values (empleado_id, field_id, quincena, value)
            VALUES (?, ?, ?, ?)
        )");
        ins.addBindValue(employeeId);
        ins.addBindValue(fieldQ.value("id"));
        ins.addBindValue(quincenaCode);
        ins.addBindValue(fieldQ.value("default_value"));
        ins.exec();
    }
    return m_db.commit();
}

bool DatabaseManager::removeQuincena(int employeeId, const QString &quincenaCode)
{
    qInfo() << "[DatabaseManager] Removiendo quincena" << quincenaCode << "de empleado ID:" << employeeId;
    if (quincenaCode == "Q1") return false;

    QSqlQuery q1(m_db);
    q1.prepare("DELETE FROM quincenas_empleado WHERE empleado_id = ? AND quincena = ?");
    q1.addBindValue(employeeId);
    q1.addBindValue(quincenaCode);
    q1.exec();

    QSqlQuery q2(m_db);
    q2.prepare("DELETE FROM employee_field_values WHERE empleado_id = ? AND quincena = ?");
    q2.addBindValue(employeeId);
    q2.addBindValue(quincenaCode);
    return q2.exec();
}

QVariantList DatabaseManager::listCellsBySchema(const QString &esquemaCodigo) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT * FROM celdas_calculo WHERE esquema_codigo = ? ORDER BY orden");
    q.addBindValue(esquemaCodigo);
    q.exec();
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"seccion_codigo", q.value("seccion_codigo")},
            {"codigo_variable", q.value("codigo_variable")},
            {"descripcion", q.value("descripcion")},
            {"condicion", q.value("condicion")},
            {"formula_unidad", q.value("formula_unidad")},
            {"formula_base", q.value("formula_base")},
            {"formula_monto", q.value("formula_monto")},
            {"orden", q.value("orden")},
            {"esquema_codigo", q.value("esquema_codigo")},
            {"tipo_calculo", q.value("tipo_calculo")},
            {"simple_porcentaje", q.value("simple_porcentaje")},
            {"simple_base_variable", q.value("simple_base_variable")},
            {"simple_monto_fijo", q.value("simple_monto_fijo")},
            {"visible_recibo", q.value("visible_recibo")},
            {"color_hex", q.value("color_hex")},
            {"en_grafico", q.value("en_grafico")},
            {"es_grafico_total", q.value("es_grafico_total")},
        });
    }
    return result;
}

QVariantList DatabaseManager::listAllCells() const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.exec(R"(
        SELECT c.*, COALESCE(s.titulo, c.seccion_codigo) AS seccion_titulo
        FROM celdas_calculo c
        LEFT JOIN secciones s ON s.codigo = c.seccion_codigo
        ORDER BY c.esquema_codigo, c.orden
    )");
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"seccion_codigo", q.value("seccion_codigo")},
            {"seccion_titulo", q.value("seccion_titulo")},
            {"codigo_variable", q.value("codigo_variable")},
            {"descripcion", q.value("descripcion")},
            {"condicion", q.value("condicion")},
            {"formula_unidad", q.value("formula_unidad")},
            {"formula_base", q.value("formula_base")},
            {"formula_monto", q.value("formula_monto")},
            {"orden", q.value("orden")},
            {"esquema_codigo", q.value("esquema_codigo")},
            {"tipo_calculo", q.value("tipo_calculo")},
            {"simple_porcentaje", q.value("simple_porcentaje")},
            {"simple_base_variable", q.value("simple_base_variable")},
            {"simple_monto_fijo", q.value("simple_monto_fijo")},
            {"visible_recibo", q.value("visible_recibo")},
            {"color_hex", q.value("color_hex")},
            {"en_grafico", q.value("en_grafico")},
            {"es_grafico_total", q.value("es_grafico_total")},
        });
    }
    return result;
}

int DatabaseManager::saveCell(int id, const QString &seccionCodigo, const QString &codigoVariable,
                               const QString &descripcion, const QString &condicion,
                               const QString &formulaUnidad, const QString &formulaBase,
                               const QString &formulaMonto, int orden, const QString &esquemaCodigo,
                               const QString &tipoCalculo, double simplePorcentaje,
                               const QString &simpleBaseVariable, double simpleMontoFijo,
                               bool visibleRecibo, const QString &colorHex,
                               bool enGrafico, bool esGraficoTotal)
{
    qInfo() << "[DatabaseManager] Guardando celda de cálculo:" << codigoVariable << "Esquema:" << esquemaCodigo;

    // Enforce unique total per schema: if esGraficoTotal is true, reset any previous total for this schema
    if (esGraficoTotal) {
        QSqlQuery resetTotal(m_db);
        resetTotal.prepare("UPDATE celdas_calculo SET es_grafico_total = 0 WHERE esquema_codigo = ?");
        resetTotal.addBindValue(esquemaCodigo);
        resetTotal.exec();
    }

    QSqlQuery q(m_db);
    if (id > 0) {
        q.prepare(R"(
            UPDATE celdas_calculo
            SET seccion_codigo=?, codigo_variable=?, descripcion=?, condicion=?,
                formula_unidad=?, formula_base=?, formula_monto=?, orden=?,
                esquema_codigo=?, tipo_calculo=?, simple_porcentaje=?,
                simple_base_variable=?, simple_monto_fijo=?, visible_recibo=?, color_hex=?,
                en_grafico=?, es_grafico_total=?
            WHERE id=?
        )");
        q.addBindValue(seccionCodigo);
        q.addBindValue(codigoVariable);
        q.addBindValue(descripcion);
        q.addBindValue(condicion);
        q.addBindValue(formulaUnidad);
        q.addBindValue(formulaBase);
        q.addBindValue(formulaMonto);
        q.addBindValue(orden);
        q.addBindValue(esquemaCodigo);
        q.addBindValue(tipoCalculo);
        q.addBindValue(simplePorcentaje);
        q.addBindValue(simpleBaseVariable);
        q.addBindValue(simpleMontoFijo);
        q.addBindValue(visibleRecibo ? 1 : 0);
        q.addBindValue(colorHex);
        q.addBindValue(enGrafico ? 1 : 0);
        q.addBindValue(esGraficoTotal ? 1 : 0);
        q.addBindValue(id);
        q.exec();
        return id;
    } else {
        q.prepare(R"(
            INSERT INTO celdas_calculo
            (seccion_codigo, codigo_variable, descripcion, condicion,
             formula_unidad, formula_base, formula_monto, orden, esquema_codigo,
             tipo_calculo, simple_porcentaje, simple_base_variable, simple_monto_fijo, visible_recibo, color_hex,
             en_grafico, es_grafico_total)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        )");
        q.addBindValue(seccionCodigo);
        q.addBindValue(codigoVariable);
        q.addBindValue(descripcion);
        q.addBindValue(condicion);
        q.addBindValue(formulaUnidad);
        q.addBindValue(formulaBase);
        q.addBindValue(formulaMonto);
        q.addBindValue(orden);
        q.addBindValue(esquemaCodigo);
        q.addBindValue(tipoCalculo);
        q.addBindValue(simplePorcentaje);
        q.addBindValue(simpleBaseVariable);
        q.addBindValue(simpleMontoFijo);
        q.addBindValue(visibleRecibo ? 1 : 0);
        q.addBindValue(colorHex);
        q.addBindValue(enGrafico ? 1 : 0);
        q.addBindValue(esGraficoTotal ? 1 : 0);
        q.exec();
        return q.lastInsertId().toInt();
    }
}

bool DatabaseManager::updateCellColor(int id, const QString &colorHex)
{
    qInfo() << "[DatabaseManager] Actualizando color de celda ID:" << id << "a" << colorHex;
    QSqlQuery q(m_db);
    q.prepare("UPDATE celdas_calculo SET color_hex = ? WHERE id = ?");
    q.addBindValue(colorHex);
    q.addBindValue(id);
    return q.exec();
}

bool DatabaseManager::deleteCell(int id)
{
    qInfo() << "[DatabaseManager] Eliminando celda de cálculo ID:" << id;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM celdas_calculo WHERE id = ?");
    q.addBindValue(id);
    return q.exec();
}

QVariantList DatabaseManager::listChartCellsBySchema(const QString &esquemaCodigo) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT * FROM celdas_grafico WHERE esquema_codigo = ? ORDER BY orden");
    q.addBindValue(esquemaCodigo);
    q.exec();
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"etiqueta", q.value("etiqueta")},
            {"formula", q.value("formula")},
            {"orden", q.value("orden")},
            {"esquema_codigo", q.value("esquema_codigo")},
        });
    }
    return result;
}

int DatabaseManager::saveChartCell(int id, const QString &etiqueta, const QString &formula,
                                    int orden, const QString &esquemaCodigo)
{
    qInfo() << "[DatabaseManager] Guardando celda de gráfico:" << etiqueta << "Esquema:" << esquemaCodigo;
    QSqlQuery q(m_db);
    if (id > 0) {
        q.prepare("UPDATE celdas_grafico SET etiqueta=?, formula=?, orden=?, esquema_codigo=? WHERE id=?");
        q.addBindValue(etiqueta);
        q.addBindValue(formula);
        q.addBindValue(orden);
        q.addBindValue(esquemaCodigo);
        q.addBindValue(id);
        q.exec();
        return id;
    } else {
        q.prepare("INSERT INTO celdas_grafico (etiqueta, formula, orden, esquema_codigo) VALUES (?, ?, ?, ?)");
        q.addBindValue(etiqueta);
        q.addBindValue(formula);
        q.addBindValue(orden);
        q.addBindValue(esquemaCodigo);
        q.exec();
        return q.lastInsertId().toInt();
    }
}

bool DatabaseManager::deleteChartCell(int id)
{
    qInfo() << "[DatabaseManager] Eliminando celda de gráfico ID:" << id;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM celdas_grafico WHERE id = ?");
    q.addBindValue(id);
    return q.exec();
}

QVariantList DatabaseManager::listGlobalVariables() const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.exec("SELECT * FROM variables_globales ORDER BY codigo");
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"codigo", q.value("codigo")},
            {"valor", q.value("valor")},
            {"descripcion", q.value("descripcion")},
        });
    }
    return result;
}

int DatabaseManager::saveGlobalVariable(int id, const QString &code, const QString &value,
                                          const QString &description)
{
    // Validate code
    QString validationError = validateVariableCode(code);
    if (!validationError.isEmpty()) {
        qWarning() << "[DatabaseManager] Código de variable global inválido:" << code << "-" << validationError;
        return -1;
    }

    qInfo() << "[DatabaseManager] Guardando variable global:" << code << "=" << value;
    QSqlQuery q(m_db);
    if (id > 0) {
        q.prepare("UPDATE variables_globales SET codigo=?, valor=?, descripcion=? WHERE id=?");
        q.addBindValue(code);
        q.addBindValue(value);
        q.addBindValue(description);
        q.addBindValue(id);
        q.exec();
        return id;
    } else {
        q.prepare("INSERT INTO variables_globales (codigo, valor, descripcion) VALUES (?, ?, ?)");
        q.addBindValue(code);
        q.addBindValue(value);
        q.addBindValue(description);
        q.exec();
        return q.lastInsertId().toInt();
    }
}

bool DatabaseManager::deleteGlobalVariable(int id)
{
    qInfo() << "[DatabaseManager] Eliminando variable global ID:" << id;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM variables_globales WHERE id = ?");
    q.addBindValue(id);
    return q.exec();
}

// ── Custom Functions CRUD ─────────────────────────────────────

QVariantList DatabaseManager::listCustomFunctions(const QString &esquemaCodigo) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    if (esquemaCodigo.isEmpty()) {
        q.exec("SELECT * FROM custom_functions ORDER BY name");
    } else {
        q.prepare("SELECT * FROM custom_functions WHERE esquema_codigo = '' OR esquema_codigo = ? ORDER BY name");
        q.addBindValue(esquemaCodigo);
        q.exec();
    }
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"name", q.value("name")},
            {"params", q.value("params")},
            {"body", q.value("body")},
            {"description", q.value("description")},
            {"esquema_codigo", q.value("esquema_codigo")},
        });
    }
    return result;
}

int DatabaseManager::saveCustomFunction(int id, const QString &name, const QString &params,
                                         const QString &body, const QString &description,
                                         const QString &esquemaCodigo)
{
    // Validate name
    QString validationError = validateVariableCode(name);
    if (!validationError.isEmpty()) {
        qWarning() << "[DatabaseManager] Nombre de función inválido:" << name << "-" << validationError;
        return -1;
    }

    qInfo() << "[DatabaseManager] Guardando función custom:" << name;
    QSqlQuery q(m_db);
    if (id > 0) {
        q.prepare("UPDATE custom_functions SET name=?, params=?, body=?, description=?, esquema_codigo=? WHERE id=?");
        q.addBindValue(name);
        q.addBindValue(params);
        q.addBindValue(body);
        q.addBindValue(description);
        q.addBindValue(esquemaCodigo);
        q.addBindValue(id);
        if (!q.exec()) {
            qWarning() << "[DatabaseManager] Error al actualizar función:" << q.lastError().text();
            return -1;
        }
        return id;
    } else {
        q.prepare("INSERT INTO custom_functions (name, params, body, description, esquema_codigo) VALUES (?, ?, ?, ?, ?)");
        q.addBindValue(name);
        q.addBindValue(params);
        q.addBindValue(body);
        q.addBindValue(description);
        q.addBindValue(esquemaCodigo);
        if (!q.exec()) {
            qWarning() << "[DatabaseManager] Error al insertar función:" << q.lastError().text();
            return -1;
        }
        return q.lastInsertId().toInt();
    }
}

bool DatabaseManager::deleteCustomFunction(int id)
{
    qInfo() << "[DatabaseManager] Eliminando función custom ID:" << id;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM custom_functions WHERE id = ?");
    q.addBindValue(id);
    return q.exec();
}

QVariantMap DatabaseManager::getCompany() const
{
    QSqlQuery q(m_db);
    q.exec("SELECT * FROM empresa LIMIT 1");
    if (q.next()) {
        return {
            {"id", q.value("id")},
            {"razon_social", q.value("razon_social")},
            {"direccion", q.value("direccion")},
            {"cuit", q.value("cuit")},
            {"lugar_de_pago", q.value("lugar_de_pago")},
        };
    }
    return {{"id", QVariant()}, {"razon_social", ""}, {"direccion", ""}, {"cuit", ""}, {"lugar_de_pago", ""}};
}

bool DatabaseManager::saveCompany(const QString &razonSocial, const QString &direccion,
                                   const QString &cuit, const QString &lugarDePago)
{
    qInfo() << "[DatabaseManager] Guardando empresa:" << razonSocial << "CUIT:" << cuit;
    auto company = getCompany();
    QSqlQuery q(m_db);
    if (company["id"].isValid()) {
        q.prepare("UPDATE empresa SET razon_social=?, direccion=?, cuit=?, lugar_de_pago=? WHERE id=?");
        q.addBindValue(razonSocial);
        q.addBindValue(direccion);
        q.addBindValue(cuit);
        q.addBindValue(lugarDePago);
        q.addBindValue(company["id"]);
    } else {
        q.prepare("INSERT INTO empresa (razon_social, direccion, cuit, lugar_de_pago) VALUES (?, ?, ?, ?)");
        q.addBindValue(razonSocial);
        q.addBindValue(direccion);
        q.addBindValue(cuit);
        q.addBindValue(lugarDePago);
    }
    return q.exec();
}

QVariantList DatabaseManager::listReceiptsByEmployee(int employeeId) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT r.*, e.nombre_completo, e.legajo
        FROM recibos r
        JOIN empleados e ON e.id = r.empleado_id
        WHERE r.empleado_id = ?
        ORDER BY r.anio DESC, r.mes DESC, r.periodo
    )");
    q.addBindValue(employeeId);
    q.exec();
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"empleado_id", q.value("empleado_id")},
            {"esquema_codigo", q.value("esquema_codigo")},
            {"mes", q.value("mes")},
            {"anio", q.value("anio")},
            {"periodo", q.value("periodo")},
            {"datos_json", q.value("datos_json")},
            {"fecha_emision", q.value("fecha_emision")},
            {"nombre_completo", q.value("nombre_completo")},
            {"legajo", q.value("legajo")},
        });
    }
    return result;
}

QVariantMap DatabaseManager::getReceipt(int id) const
{
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT r.*, e.nombre_completo, e.legajo
        FROM recibos r
        LEFT JOIN empleados e ON e.id = r.empleado_id
        WHERE r.id = ?
    )");
    q.addBindValue(id);
    q.exec();
    if (q.next()) {
        return {
            {"id", q.value("id")},
            {"empleado_id", q.value("empleado_id")},
            {"esquema_codigo", q.value("esquema_codigo")},
            {"mes", q.value("mes")},
            {"anio", q.value("anio")},
            {"periodo", q.value("periodo")},
            {"datos_json", q.value("datos_json")},
            {"fecha_emision", q.value("fecha_emision")},
            {"nombre_completo", q.value("nombre_completo")},
            {"legajo", q.value("legajo")},
        };
    }
    return {};
}

int DatabaseManager::saveReceipt(int employeeId, const QString &esquemaCodigo,
                                  int mes, int anio, const QString &periodo,
                                  const QString &datosJson)
{
    qInfo() << "[DatabaseManager] Guardando recibo snapshot para empleado ID:" << employeeId << "Mes:" << mes << "Año:" << anio << "Periodo:" << periodo;
    QString fecha = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");

    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO recibos (empleado_id, esquema_codigo, mes, anio, periodo, datos_json, fecha_emision)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(empleado_id, esquema_codigo, mes, anio, periodo)
        DO UPDATE SET datos_json=excluded.datos_json, fecha_emision=excluded.fecha_emision
        RETURNING id
    )");
    q.addBindValue(employeeId);
    q.addBindValue(esquemaCodigo);
    q.addBindValue(mes);
    q.addBindValue(anio);
    q.addBindValue(periodo);
    q.addBindValue(datosJson);
    q.addBindValue(fecha);

    if (q.exec() && q.next()) {
        return q.value(0).toInt();
    }

    // Fallback if RETURNING clause is not supported on older SQLite engines
    QSqlQuery fb(m_db);
    fb.prepare("SELECT id FROM recibos WHERE empleado_id=? AND esquema_codigo=? AND mes=? AND anio=? AND periodo=?");
    fb.addBindValue(employeeId);
    fb.addBindValue(esquemaCodigo);
    fb.addBindValue(mes);
    fb.addBindValue(anio);
    fb.addBindValue(periodo);
    if (fb.exec() && fb.next()) {
        return fb.value(0).toInt();
    }

    return -1;
}

bool DatabaseManager::deleteReceipt(int id)
{
    qInfo() << "[DatabaseManager] Eliminando recibo histórico ID:" << id;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM recibos WHERE id = ?");
    q.addBindValue(id);
    return q.exec();
}

QVariantList DatabaseManager::searchReceipts(int employeeId, int mes, int anio) const
{
    QVariantList result;
    QSqlQuery q(m_db);
    q.prepare("SELECT * FROM recibos WHERE empleado_id=? AND mes=? AND anio=? ORDER BY periodo");
    q.addBindValue(employeeId);
    q.addBindValue(mes);
    q.addBindValue(anio);
    q.exec();
    while (q.next()) {
        result.append(QVariantMap{
            {"id", q.value("id")},
            {"empleado_id", q.value("empleado_id")},
            {"esquema_codigo", q.value("esquema_codigo")},
            {"mes", q.value("mes")},
            {"anio", q.value("anio")},
            {"periodo", q.value("periodo")},
            {"datos_json", q.value("datos_json")},
            {"fecha_emision", q.value("fecha_emision")},
        });
    }
    return result;
}

QString DatabaseManager::getConfig(const QString &key, const QString &defaultValue) const
{
    QSqlQuery q(m_db);
    q.prepare("SELECT valor FROM configuraciones WHERE clave = ?");
    q.addBindValue(key);
    q.exec();
    if (q.next()) {
        return q.value(0).toString();
    }
    return defaultValue;
}

void DatabaseManager::setConfig(const QString &key, const QString &value)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT OR REPLACE INTO configuraciones (clave, valor) VALUES (?, ?)");
    q.addBindValue(key);
    q.addBindValue(value);
    q.exec();
}

QString DatabaseManager::createBackup()
{
    QFileInfo fi(m_dbPath);
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString backupPath = fi.absolutePath() + "/" + fi.completeBaseName()
                         + "_backup_" + timestamp + "." + fi.suffix();

    qInfo() << "[DatabaseManager] Creando copia de seguridad de BD:" << backupPath;

    m_db.close();
    QFile::copy(m_dbPath, backupPath);
    m_db.open();
    QSqlQuery q(m_db);
    q.exec("PRAGMA foreign_keys = ON");

    return backupPath;
}

QString DatabaseManager::resetNewMonth()
{
    qInfo() << "[DatabaseManager] Ejecutando reinicio de Nuevo Mes...";
    QString backupPath = createBackup();

    QSqlQuery q(m_db);

    q.exec(R"(
        SELECT sf.id FROM schema_fields sf
        WHERE sf.field_code IN ('horas_trabajadas', 'horas_extras_50', 'horas_extras_100', 'dias_vacaciones')
    )");

    QList<int> fieldsToReset;
    while (q.next()) {
        fieldsToReset.append(q.value(0).toInt());
    }

    m_db.transaction();
    for (int fieldId : fieldsToReset) {
        QSqlQuery update(m_db);
        update.prepare("UPDATE employee_field_values SET value = '0' WHERE field_id = ?");
        update.addBindValue(fieldId);
        update.exec();
    }

    q.exec("DELETE FROM employee_field_values WHERE quincena != 'Q1'");

    m_db.commit();
    qInfo() << "[DatabaseManager] Reinicio de nuevo mes completado exitosamente.";

    return backupPath;
}
