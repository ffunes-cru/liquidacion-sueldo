#ifndef UPDATESERVICE_H
#define UPDATESERVICE_H

#include <QObject>
#include <QString>
#include <QDateTime>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QFile>
#include <QElapsedTimer>
#include <QVariantList>

#ifndef APP_VERSION_STR
#define APP_VERSION_STR "1.0.0"
#endif

#ifndef GITHUB_REPO_OWNER
#define GITHUB_REPO_OWNER "ffunes-cru"
#endif

#ifndef GITHUB_REPO_NAME
#define GITHUB_REPO_NAME "liquidacion-sueldo"
#endif

class UpdateService : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY updateCheckFinished)
    Q_PROPERTY(QString releaseName READ releaseName NOTIFY updateCheckFinished)
    Q_PROPERTY(QString releaseNotes READ releaseNotes NOTIFY updateCheckFinished)
    Q_PROPERTY(QString releaseDate READ releaseDate NOTIFY updateCheckFinished)
    Q_PROPERTY(QString downloadUrl READ downloadUrl NOTIFY updateCheckFinished)
    Q_PROPERTY(qint64 assetSizeBytes READ assetSizeBytes NOTIFY updateCheckFinished)

    Q_PROPERTY(bool isChecking READ isChecking NOTIFY isCheckingChanged)
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)
    Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(QString downloadSpeed READ downloadSpeed NOTIFY downloadProgressChanged)
    Q_PROPERTY(qint64 downloadedBytes READ downloadedBytes NOTIFY downloadProgressChanged)
    Q_PROPERTY(qint64 totalBytes READ totalBytes NOTIFY downloadProgressChanged)

    Q_PROPERTY(bool isUpdateAvailable READ isUpdateAvailable NOTIFY updateCheckFinished)
    Q_PROPERTY(bool isReadyToInstall READ isReadyToInstall NOTIFY isReadyToInstallChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

    Q_PROPERTY(bool autoCheckOnStartup READ autoCheckOnStartup WRITE setAutoCheckOnStartup NOTIFY autoCheckOnStartupChanged)
    Q_PROPERTY(QString lastCheckedTime READ lastCheckedTime NOTIFY lastCheckedTimeChanged)

public:
    explicit UpdateService(QObject *parent = nullptr);
    ~UpdateService() override;

    QString currentVersion() const;
    QString latestVersion() const;
    QString releaseName() const;
    QString releaseNotes() const;
    QString releaseDate() const;
    QString downloadUrl() const;
    qint64 assetSizeBytes() const;

    bool isChecking() const;
    bool isDownloading() const;
    double downloadProgress() const;
    QString downloadSpeed() const;
    qint64 downloadedBytes() const;
    qint64 totalBytes() const;

    bool isUpdateAvailable() const;
    bool isReadyToInstall() const;
    QString statusMessage() const;
    QString errorMessage() const;

    bool autoCheckOnStartup() const;
    void setAutoCheckOnStartup(bool autoCheck);
    QString lastCheckedTime() const;

    Q_INVOKABLE void checkForUpdates(bool silent = false);
    Q_INVOKABLE void startDownload();
    Q_INVOKABLE void cancelDownload();
    Q_INVOKABLE bool installAndRestart();
    Q_INVOKABLE void dismissUpdate();

    static bool isVersionNewer(const QString &currentVer, const QString &candidateVer);
    static QString sanitizeVersion(const QString &ver);

signals:
    void isCheckingChanged();
    void isDownloadingChanged();
    void downloadProgressChanged();
    void updateCheckFinished();
    void isReadyToInstallChanged();
    void statusMessageChanged();
    void errorMessageChanged();
    void autoCheckOnStartupChanged();
    void lastCheckedTimeChanged();
    void updateAvailablePrompt();

private slots:
    void onCheckReplyFinished();
    void onDownloadDataReady();
    void onDownloadProgress(qint64 received, qint64 total);
    void onDownloadFinished();

private:
    void setStatus(const QString &msg);
    void setError(const QString &err);
    QString detectMatchingAsset(const QVariantList &assets, qint64 &outSize);
    bool extractZip(const QString &zipPath, const QString &destinationDir);
    bool executeHotSwap(const QString &stagedPath);

    QNetworkAccessManager *m_netManager = nullptr;
    QNetworkReply *m_checkReply = nullptr;
    QNetworkReply *m_downloadReply = nullptr;
    QFile *m_downloadFile = nullptr;

    QString m_currentVersion = APP_VERSION_STR;
    QString m_latestVersion;
    QString m_releaseName;
    QString m_releaseNotes;
    QString m_releaseDate;
    QString m_downloadUrl;
    QString m_downloadedFilePath;
    qint64 m_assetSizeBytes = 0;

    bool m_isChecking = false;
    bool m_isDownloading = false;
    bool m_isUpdateAvailable = false;
    bool m_isReadyToInstall = false;
    bool m_silentCheck = false;

    double m_downloadProgress = 0.0;
    QString m_downloadSpeed;
    qint64 m_downloadedBytes = 0;
    qint64 m_totalBytes = 0;

    QString m_statusMessage;
    QString m_errorMessage;
    QString m_lastCheckedTime;

    QElapsedTimer m_speedTimer;
    qint64 m_lastBytesForSpeed = 0;
};

#endif // UPDATESERVICE_H
