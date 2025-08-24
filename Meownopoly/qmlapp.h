#ifndef __QMLAPP_H
#define __QMLAPP_H

#include <QObject>
#include <QQmlApplicationEngine>
#include <QtQuick/QQuickView>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QHttpMultiPart>
#include <QUrl>
#include <QFile>
#include <QJsonObject>
#include <QJsonDocument>
#include <QTimer>
#include <QStandardPaths>
#include "game.h"
#include "QtFolderCompressor/FolderCompressor.h"
#include "asset_manager.h"

#define FORCE_DOWNLOAD 0
#define ASSET_URL "https://drive.google.com/file/d/1UMldDp99unwsFFOYCNF0M3b3eXkVlAJu/view?usp=sharing"

class QmlApp : public QQmlApplicationEngine
{
    Q_OBJECT
    Q_PROPERTY(QString assetsPath READ assetsPath NOTIFY assetsPathChanged)

public:
    explicit QmlApp(QWindow *parent = nullptr);
    bool event(QEvent *event) override;
    ~QmlApp() override;
    
    // Getter for assets path
    QString assetsPath() const;
    
    // Utility method to build asset paths from QML
    Q_INVOKABLE QString getAssetPath(const QString &relativePath) const;
    


signals:
    void assetsPathChanged();

public slots:

private slots:
    // void onDownloadFinished();
    // void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);

private:
    Game *game = nullptr;
    FolderCompressor *folderCompressor = nullptr;
    AssetManager *assetManager = nullptr;
    QNetworkAccessManager *networkManager = nullptr;
    QNetworkReply *currentDownload = nullptr;
    QFile *downloadFile = nullptr;
    QString m_assetsPath;
    
    void autoExtractAssets();
    void downloadAssetsFile();
    QString getDirectDownloadUrl(const QString &shareableUrl);
    void setAssetsPath(const QString &path);
};

#endif // __QMLAPP_H
