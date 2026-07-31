#ifndef EXPORTSERVICE_H
#define EXPORTSERVICE_H

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>

class DatabaseManager;

/**
 * @brief Handles import/export of data (Excel, CSV, PDF).
 *
 * Excel: Uses QXlsx library for .xlsx read/write, maintaining compatibility
 * with the Python version's datos_liquidacion_sueldos.xlsx format.
 *
 * CSV: Uses QTextStream for plain text export/import of each table.
 *
 * PDF: Uses QPdfWriter + QPainter for receipt generation.
 */
class ExportService : public QObject
{
    Q_OBJECT

public:
    explicit ExportService(DatabaseManager *db, QObject *parent = nullptr);

    // ── Excel (.xlsx) ────────────────────────────────────────────
    QString exportDataXlsx(const QString &path);
    bool    importDataXlsx(const QString &path);

    // ── CSV ──────────────────────────────────────────────────────
    QString exportDataCsv(const QString &directoryPath);
    bool    importDataCsv(const QString &directoryPath);

    // ── PDF ──────────────────────────────────────────────────────
    QString exportReceiptPdf(const QVariantMap &liquidationResult,
                             const QVariantMap &companyData,
                             const QVariantMap &employeeData,
                             const QString &path);

private:
    DatabaseManager *m_db;

    // Helper: generate default path if empty
    QString ensureXlsxPath(const QString &path) const;
    QString ensureCsvDir(const QString &path) const;
    QString ensurePdfPath(const QString &path) const;
};

#endif // EXPORTSERVICE_H
