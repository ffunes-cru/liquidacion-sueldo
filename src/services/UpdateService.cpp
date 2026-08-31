#include "UpdateService.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>
#include <QDebug>
#include <QSysInfo>

static const char *SETTINGS_KEY_AUTOCHECK = "Updates/AutoCheckOnStartup";
static const char *SETTINGS_KEY_LASTCHECK = "Updates/LastCheckedTime";

UpdateService::UpdateService(QObject *parent)
    : QObject(parent),
      m_netManager(new QNetworkAccessManager(this))
{
    QSettings settings;
    m_lastCheckedTime = settings.value(SETTINGS_KEY_LASTCHECK, "").toString();
}

UpdateService::~UpdateService()
{
    cancelDownload();
}

QString UpdateService::currentVersion() const { return m_currentVersion; }
QString UpdateService::latestVersion() const { return m_latestVersion; }
QString UpdateService::releaseName() const { return m_releaseName; }
QString UpdateService::releaseNotes() const { return m_releaseNotes; }
QString UpdateService::releaseDate() const { return m_releaseDate; }
QString UpdateService::downloadUrl() const { return m_downloadUrl; }
qint64 UpdateService::assetSizeBytes() const { return m_assetSizeBytes; }

bool UpdateService::isChecking() const { return m_isChecking; }
bool UpdateService::isDownloading() const { return m_isDownloading; }
double UpdateService::downloadProgress() const { return m_downloadProgress; }
QString UpdateService::downloadSpeed() const { return m_downloadSpeed; }
qint64 UpdateService::downloadedBytes() const { return m_downloadedBytes; }
qint64 UpdateService::totalBytes() const { return m_totalBytes; }

bool UpdateService::isUpdateAvailable() const { return m_isUpdateAvailable; }
bool UpdateService::isReadyToInstall() const { return m_isReadyToInstall; }
QString UpdateService::statusMessage() const { return m_statusMessage; }
QString UpdateService::errorMessage() const { return m_errorMessage; }

bool UpdateService::autoCheckOnStartup() const
{
    QSettings settings;
    return settings.value(SETTINGS_KEY_AUTOCHECK, true).toBool();
}

void UpdateService::setAutoCheckOnStartup(bool autoCheck)
{
    QSettings settings;
    if (settings.value(SETTINGS_KEY_AUTOCHECK, true).toBool() != autoCheck) {
        settings.setValue(SETTINGS_KEY_AUTOCHECK, autoCheck);
        emit autoCheckOnStartupChanged();
    }
}

QString UpdateService::lastCheckedTime() const { return m_lastCheckedTime; }

void UpdateService::setStatus(const QString &msg)
{
    m_statusMessage = msg;
    emit statusMessageChanged();
}

void UpdateService::setError(const QString &err)
{
    m_errorMessage = err;
    emit errorMessageChanged();
}

QString UpdateService::sanitizeVersion(const QString &ver)
{
    QString cleaned = ver.trimmed();
    if (cleaned.startsWith("v", Qt::CaseInsensitive)) {
        cleaned = cleaned.mid(1).trimmed();
    }
    return cleaned;
}

bool UpdateService::isVersionNewer(const QString &currentVer, const QString &candidateVer)
{
    QString cClean = sanitizeVersion(currentVer);
    QString nClean = sanitizeVersion(candidateVer);

    if (nClean.isEmpty()) return false;
    if (cClean == nClean) return false;

    // Parse SemVer major.minor.patch
    auto parseSegments = [](const QString &vStr) -> QList<int> {
        QString mainPart = vStr.split('-').first().split('+').first();
        QStringList parts = mainPart.split('.');
        QList<int> nums;
        for (const QString &p : parts) {
            bool ok = false;
            int val = p.toInt(&ok);
            nums.append(ok ? val : 0);
        }
        while (nums.size() < 3) nums.append(0);
        return nums;
    };

    QList<int> currentNums = parseSegments(cClean);
    QList<int> candidateNums = parseSegments(nClean);

    for (int i = 0; i < 3; ++i) {
        if (candidateNums[i] > currentNums[i]) return true;
        if (candidateNums[i] < currentNums[i]) return false;
    }

    return false;
}

QString UpdateService::detectMatchingAsset(const QVariantList &assets, qint64 &outSize)
{
    outSize = 0;
#if defined(Q_OS_WIN)
    QString preferredExt = ".zip";
    QString platformTag = "win";
#elif defined(Q_OS_LINUX)
    QString preferredExt = ".AppImage";
    QString fallbackExt = ".tar.gz";
    QString platformTag = "linux";
#else
    QString preferredExt = ".zip";
    QString platformTag = "";
#endif

    QString bestUrl;
    qint64 bestSize = 0;

    for (const QVariant &aVar : assets) {
        QVariantMap aMap = aVar.toMap();
        QString name = aMap.value("name").toString().toLower();
        QString url = aMap.value("browser_download_url").toString();
        qint64 size = aMap.value("size").toLongLong();

#if defined(Q_OS_WIN)
        if (name.endsWith(preferredExt) && (name.contains(platformTag) || name.contains("windows") || assets.size() == 1)) {
            outSize = size;
            return url;
        }
        if (name.endsWith(".zip") && bestUrl.isEmpty()) {
            bestUrl = url;
            bestSize = size;
        }
#elif defined(Q_OS_LINUX)
        if (name.endsWith(preferredExt)) {
            outSize = size;
            return url;
        }
        if (name.endsWith(fallbackExt) && (name.contains(platformTag) || assets.size() == 1)) {
            bestUrl = url;
            bestSize = size;
        }
#else
        if (bestUrl.isEmpty()) {
            bestUrl = url;
            bestSize = size;
        }
#endif
    }

    if (!bestUrl.isEmpty()) {
        outSize = bestSize;
        return bestUrl;
    }

    // Fallback: take the first asset
    if (!assets.isEmpty()) {
        QVariantMap first = assets.first().toMap();
        outSize = first.value("size").toLongLong();
        return first.value("browser_download_url").toString();
    }

    return QString();
}

void UpdateService::checkForUpdates(bool silent)
{
    if (m_isChecking || m_isDownloading) return;

    m_silentCheck = silent;
    m_isChecking = true;
    m_errorMessage.clear();
    emit isCheckingChanged();
    emit errorMessageChanged();

    if (!silent) {
        setStatus("Consultando últimas versiones en GitHub...");
    }

    QString apiUrl = QString("https://api.github.com/repos/%1/%2/releases/latest")
                         .arg(GITHUB_REPO_OWNER)
                         .arg(GITHUB_REPO_NAME);

    QNetworkRequest request((QUrl(apiUrl)));
    request.setHeader(QNetworkRequest::UserAgentHeader, "LiquidacionSueldos-App/1.0 (Qt6)");
    request.setRawHeader("Accept", "application/vnd.github.v3+json");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    m_checkReply = m_netManager->get(request);
    connect(m_checkReply, &QNetworkReply::finished, this, &UpdateService::onCheckReplyFinished);
}

void UpdateService::onCheckReplyFinished()
{
    if (!m_checkReply) return;

    m_isChecking = false;
    emit isCheckingChanged();

    QByteArray responseData = m_checkReply->readAll();
    int statusCode = m_checkReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QNetworkReply::NetworkError error = m_checkReply->error();
    m_checkReply->deleteLater();
    m_checkReply = nullptr;

    QDateTime now = QDateTime::currentDateTime();
    m_lastCheckedTime = now.toString("dd/MM/yyyy HH:mm");
    QSettings settings;
    settings.setValue(SETTINGS_KEY_LASTCHECK, m_lastCheckedTime);
    emit lastCheckedTimeChanged();

    if (error != QNetworkReply::NoError && statusCode != 200) {
        if (!m_silentCheck) {
            setError(QString("Error al verificar actualizaciones (HTTP %1)").arg(statusCode));
            setStatus("No se pudo conectar con GitHub.");
        }
        emit updateCheckFinished();
        return;
    }

    QJsonParseError parseErr;
    QJsonDocument doc = QJsonDocument::fromJson(responseData, &parseErr);
    if (parseErr.error != QJsonParseError::NoError || !doc.isObject()) {
        if (!m_silentCheck) {
            setError("Respuesta no válida de GitHub.");
            setStatus("Error de formato de versión.");
        }
        emit updateCheckFinished();
        return;
    }

    QJsonObject obj = doc.object();
    QString tagName = obj.value("tag_name").toString();
    m_latestVersion = sanitizeVersion(tagName);
    m_releaseName = obj.value("name").toString();
    m_releaseNotes = obj.value("body").toString();
    m_releaseDate = obj.value("published_at").toString().left(10);

    QVariantList assets = obj.value("assets").toArray().toVariantList();
    m_downloadUrl = detectMatchingAsset(assets, m_assetSizeBytes);

    m_isUpdateAvailable = isVersionNewer(m_currentVersion, m_latestVersion);

    if (m_isUpdateAvailable) {
        setStatus(QString("¡Nueva versión %1 disponible!").arg(m_latestVersion));
        emit updateAvailablePrompt();
    } else {
        setStatus(QString("El sistema está actualizado (Versión %1).").arg(m_currentVersion));
    }

    emit updateCheckFinished();
}

void UpdateService::startDownload()
{
    if (m_downloadUrl.isEmpty() || m_isDownloading) return;

    m_isDownloading = true;
    m_downloadProgress = 0.0;
    m_downloadedBytes = 0;
    m_totalBytes = m_assetSizeBytes;
    m_isReadyToInstall = false;
    m_errorMessage.clear();

    emit isDownloadingChanged();
    emit downloadProgressChanged();
    emit isReadyToInstallChanged();
    emit errorMessageChanged();

    setStatus(QString("Descargando actualización %1...").arg(m_latestVersion));

    // Prepare temp download file
    QString fileName = QUrl(m_downloadUrl).fileName();
    if (fileName.isEmpty()) fileName = QString("LiquidacionSueldos-update-%1.pkg").arg(m_latestVersion);

    QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    m_downloadedFilePath = tempDir + "/" + fileName;

    if (QFile::exists(m_downloadedFilePath)) {
        QFile::remove(m_downloadedFilePath);
    }

    m_downloadFile = new QFile(m_downloadedFilePath, this);
    if (!m_downloadFile->open(QIODevice::WriteOnly)) {
        setError("No se pudo crear el archivo temporal de descarga.");
        m_isDownloading = false;
        emit isDownloadingChanged();
        delete m_downloadFile;
        m_downloadFile = nullptr;
        return;
    }

    QNetworkRequest request((QUrl(m_downloadUrl)));
    request.setHeader(QNetworkRequest::UserAgentHeader, "LiquidacionSueldos-App/1.0 (Qt6)");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    m_speedTimer.start();
    m_lastBytesForSpeed = 0;

    m_downloadReply = m_netManager->get(request);
    connect(m_downloadReply, &QNetworkReply::readyRead, this, &UpdateService::onDownloadDataReady);
    connect(m_downloadReply, &QNetworkReply::downloadProgress, this, &UpdateService::onDownloadProgress);
    connect(m_downloadReply, &QNetworkReply::finished, this, &UpdateService::onDownloadFinished);
}

void UpdateService::onDownloadDataReady()
{
    if (m_downloadReply && m_downloadFile && m_downloadFile->isOpen()) {
        m_downloadFile->write(m_downloadReply->readAll());
    }
}

void UpdateService::onDownloadProgress(qint64 received, qint64 total)
{
    m_downloadedBytes = received;
    if (total > 0) {
        m_totalBytes = total;
        m_downloadProgress = static_cast<double>(received) / static_cast<double>(total);
    } else if (m_totalBytes > 0) {
        m_downloadProgress = static_cast<double>(received) / static_cast<double>(m_totalBytes);
    }

    // Calculate speed every 500ms
    if (m_speedTimer.elapsed() >= 500) {
        qint64 bytesDiff = received - m_lastBytesForSpeed;
        double seconds = m_speedTimer.elapsed() / 1000.0;
        double bytesPerSec = bytesDiff / (seconds > 0 ? seconds : 1.0);
        if (bytesPerSec >= 1024 * 1024) {
            m_downloadSpeed = QString("%1 MB/s").arg(bytesPerSec / (1024.0 * 1024.0), 0, 'f', 1);
        } else {
            m_downloadSpeed = QString("%1 KB/s").arg(bytesPerSec / 1024.0, 0, 'f', 0);
        }
        m_lastBytesForSpeed = received;
        m_speedTimer.restart();
    }

    emit downloadProgressChanged();
}

void UpdateService::onDownloadFinished()
{
    if (!m_downloadReply) return;

    m_isDownloading = false;
    emit isDownloadingChanged();

    if (m_downloadFile) {
        m_downloadFile->flush();
        m_downloadFile->close();
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }

    QNetworkReply::NetworkError error = m_downloadReply->error();
    int statusCode = m_downloadReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    m_downloadReply->deleteLater();
    m_downloadReply = nullptr;

    if (error != QNetworkReply::NoError && statusCode != 200 && statusCode != 302) {
        setError(QString("Fallo en la descarga de la actualización (Error: %1)").arg(error));
        setStatus("Descarga fallida.");
        return;
    }

    m_downloadProgress = 1.0;
    emit downloadProgressChanged();

    m_isReadyToInstall = true;
    emit isReadyToInstallChanged();
    setStatus("Descarga completada. Lista para instalar.");
}

void UpdateService::cancelDownload()
{
    if (m_downloadReply) {
        m_downloadReply->abort();
        m_downloadReply->deleteLater();
        m_downloadReply = nullptr;
    }
    if (m_downloadFile) {
        m_downloadFile->close();
        m_downloadFile->remove();
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }
    if (m_isDownloading) {
        m_isDownloading = false;
        emit isDownloadingChanged();
        setStatus("Descarga cancelada.");
    }
}

void UpdateService::dismissUpdate()
{
    m_isUpdateAvailable = false;
    emit updateCheckFinished();
}

bool UpdateService::extractZip(const QString &zipPath, const QString &destinationDir)
{
    QDir().mkpath(destinationDir);

#if defined(Q_OS_WIN)
    QString psScript = QString("Expand-Archive -Path '%1' -DestinationPath '%2' -Force")
                           .arg(QDir::toNativeSeparators(zipPath))
                           .arg(QDir::toNativeSeparators(destinationDir));
    QProcess process;
    process.start("powershell.exe", {"-NoProfile", "-NonInteractive", "-Command", psScript});
    process.waitForFinished(60000);
    return (process.exitCode() == 0);
#elif defined(Q_OS_LINUX)
    if (zipPath.endsWith(".tar.gz") || zipPath.endsWith(".tgz")) {
        QProcess process;
        process.start("tar", {"-xzf", zipPath, "-C", destinationDir});
        process.waitForFinished(30000);
        return (process.exitCode() == 0);
    } else if (zipPath.endsWith(".zip")) {
        QProcess process;
        process.start("unzip", {"-o", zipPath, "-d", destinationDir});
        process.waitForFinished(30000);
        return (process.exitCode() == 0);
    }
    return false;
#else
    return false;
#endif
}

bool UpdateService::executeHotSwap(const QString &stagedPath)
{
    qint64 currentPid = QCoreApplication::applicationPid();
    QString appDir = QCoreApplication::applicationDirPath();
    QString exePath = QCoreApplication::applicationFilePath();
    QString exeName = QFileInfo(exePath).fileName();

#if defined(Q_OS_WIN)
    QString scriptPath = QDir::tempPath() + "/apply_liq_update.bat";
    QFile scriptFile(scriptPath);
    if (!scriptFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setError("No se pudo generar el script de actualización de Windows.");
        return false;
    }

    QTextStream out(&scriptFile);
    out << "@echo off\n";
    out << "chcp 65001 >nul\n";
    out << "set PID=" << currentPid << "\n";
    out << "set SRC=" << QDir::toNativeSeparators(stagedPath) << "\n";
    out << "set DST=" << QDir::toNativeSeparators(appDir) << "\n";
    out << "set EXE=" << exeName << "\n";
    out << ":wait_pid\n";
    out << "tasklist /fi \"pid eq %PID%\" 2>nul | find \"%PID%\" >nul\n";
    out << "if \"%ERRORLEVEL%\"==\"0\" (\n";
    out << "    timeout /t 1 /nobreak >nul\n";
    out << "    goto wait_pid\n";
    out << ")\n";
    out << "timeout /t 1 /nobreak >nul\n";
    out << "robocopy \"%SRC%\" \"%DST%\" /E /XF *.db *.db-wal *.db-shm *.lock /XD backups /NJH /NJS >nul\n";
    out << "start \"\" \"%DST%\\%EXE%\"\n";
    out << "(goto) 2>nul & del \"%~f0\"\n";
    scriptFile.close();

    bool started = QProcess::startDetached("cmd.exe", {"/c", QDir::toNativeSeparators(scriptPath)});
    if (started) {
        QCoreApplication::quit();
        return true;
    }
    setError("Fallo al iniciar el proceso desacoplado de actualización.");
    return false;

#elif defined(Q_OS_LINUX)
    // Check if running as AppImage
    QByteArray appImagePath = qgetenv("APPIMAGE");
    if (!appImagePath.isEmpty() && m_downloadedFilePath.endsWith(".AppImage")) {
        // AppImage self-replace
        QFile::setPermissions(m_downloadedFilePath,
                              QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner |
                              QFile::ReadGroup | QFile::ExeGroup |
                              QFile::ReadOther | QFile::ExeOther);

        QString currentAppImage = QString::fromUtf8(appImagePath);
        QString scriptPath = QDir::tempPath() + "/apply_liq_update.sh";
        QFile scriptFile(scriptPath);
        if (scriptFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&scriptFile);
            out << "#!/bin/bash\n";
            out << "while kill -0 " << currentPid << " 2>/dev/null; do sleep 0.5; done\n";
            out << "mv -f \"" << m_downloadedFilePath << "\" \"" << currentAppImage << "\"\n";
            out << "chmod +x \"" << currentAppImage << "\"\n";
            out << "\"" << currentAppImage << "\" &\n";
            out << "rm -f \"$0\"\n";
            scriptFile.close();
            QFile::setPermissions(scriptPath, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);

            bool started = QProcess::startDetached("/bin/bash", {scriptPath});
            if (started) {
                QCoreApplication::quit();
                return true;
            }
        }
    }

    // Generic Linux unpacked directory
    QString scriptPath = QDir::tempPath() + "/apply_liq_update.sh";
    QFile scriptFile(scriptPath);
    if (!scriptFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setError("No se pudo generar el script de actualización de Linux.");
        return false;
    }

    QTextStream out(&scriptFile);
    out << "#!/bin/bash\n";
    out << "while kill -0 " << currentPid << " 2>/dev/null; do sleep 0.5; done\n";
    out << "rsync -a --exclude='*.db*' --exclude='*.lock' --exclude='backups/' \"" << stagedPath << "/\" \"" << appDir << "/\"\n";
    out << "chmod +x \"" << exePath << "\"\n";
    out << "\"" << exePath << "\" &\n";
    out << "rm -f \"$0\"\n";
    scriptFile.close();
    QFile::setPermissions(scriptPath, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);

    bool started = QProcess::startDetached("/bin/bash", {scriptPath});
    if (started) {
        QCoreApplication::quit();
        return true;
    }
    setError("Fallo al iniciar el proceso desacoplado de actualización.");
    return false;
#endif
}

bool UpdateService::installAndRestart()
{
    if (!m_isReadyToInstall || m_downloadedFilePath.isEmpty() || !QFile::exists(m_downloadedFilePath)) {
        setError("No hay ninguna actualización descargada lista para instalar.");
        return false;
    }

    setStatus("Preparando archivos para la actualización caliente...");

    // Staging directory in temp
    QString stagingDir = QDir::tempPath() + QString("/LiquidacionSueldos_staging_%1").arg(m_latestVersion);
    QDir(stagingDir).removeRecursively();
    QDir().mkpath(stagingDir);

    if (m_downloadedFilePath.endsWith(".zip") || m_downloadedFilePath.endsWith(".tar.gz") || m_downloadedFilePath.endsWith(".tgz")) {
        bool ok = extractZip(m_downloadedFilePath, stagingDir);
        if (!ok) {
            setError("Fallo al descomprimir el paquete de actualización.");
            return false;
        }
        return executeHotSwap(stagingDir);
    } else {
        // Direct binary / AppImage
        return executeHotSwap(m_downloadedFilePath);
    }
}
