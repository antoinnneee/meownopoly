#ifndef LAUNCHER_MANAGER_H
#define LAUNCHER_MANAGER_H

#include <QObject>
#include <QQmlEngine>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QHttpMultiPart>
#include <QTimer>
#include <QFile>
#include <QJsonObject>
#include <QJsonDocument>
#include <QDateTime>
#include "QtFolderCompressor/FolderCompressor.h"

class LauncherManager : public QObject
{
    Q_OBJECT
    
    Q_PROPERTY(QString currentVersion READ currentVersion NOTIFY currentVersionChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY latestVersionChanged)
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)
    Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(QString downloadStatus READ downloadStatus NOTIFY downloadStatusChanged)
    Q_PROPERTY(bool packageCreated READ packageCreated NOTIFY packageCreatedChanged)

public:
    static void registerQml();
    static LauncherManager *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    
    // Getters for properties
    QString currentVersion() const { return m_currentVersion; }
    QString latestVersion() const { return m_latestVersion; }
    bool isDownloading() const { return m_isDownloading; }
    double downloadProgress() const { return m_downloadProgress; }
    QString downloadStatus() const { return m_downloadStatus; }
    bool packageCreated() const { return m_packageCreated; }
    
    // Launcher methods invokable from QML
    Q_INVOKABLE void testServerConnection(const QString &serverUrl);
    Q_INVOKABLE void checkForUpdates(const QString &serverUrl);
    Q_INVOKABLE void downloadResources(const QString &serverUrl, const QString &version);
    Q_INVOKABLE void forceDownloadResources(const QString &serverUrl);
    Q_INVOKABLE void createResourcePackage(const QString &folderPath, const QString &version);
    Q_INVOKABLE void uploadPackageToServer(const QString &serverUrl);
    Q_INVOKABLE void resetDownloadState();

signals:
    void currentVersionChanged();
    void latestVersionChanged();
    void isDownloadingChanged();
    void downloadProgressChanged();
    void downloadStatusChanged();
    void packageCreatedChanged();
    void connectionTestResult(bool success, const QString &message);
    void logMessage(const QString &message);

private slots:
    void onDownloadFinished();
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onVersionCheckFinished();
    void onConnectionTestFinished();

private:
    explicit LauncherManager(QObject *parent = nullptr);
    static LauncherManager *m_instance;
    
    // Network components
    QNetworkAccessManager *m_networkManager = nullptr;
    QNetworkReply *m_currentDownload = nullptr;
    QNetworkReply *m_versionCheckReply = nullptr;
    QNetworkReply *m_connectionTestReply = nullptr;
    QFile *m_downloadFile = nullptr;
    
    // FolderCompressor instance
    FolderCompressor *m_folderCompressor = nullptr;
    
    // Properties
    QString m_currentVersion = "0.0.0";
    QString m_latestVersion = "0.0.0";
    bool m_isDownloading = false;
    double m_downloadProgress = 0.0;
    QString m_downloadStatus = "Prêt";
    bool m_packageCreated = false;
    QString m_lastCreatedPackage;
    
    // Helper methods
    QString getCurrentVersionFromFile();
    void saveVersionInfo(const QString &version);
    QJsonObject createVersionManifest(const QString &version);
    bool parseVersionInfo(const QJsonObject &versionInfo);
    void setCurrentVersion(const QString &version);
    void setLatestVersion(const QString &version);
    void setIsDownloading(bool downloading);
    void setDownloadProgress(double progress);
    void setDownloadStatus(const QString &status);
    void setPackageCreated(bool created);
};

#endif // LAUNCHER_MANAGER_H
