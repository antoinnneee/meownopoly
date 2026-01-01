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
#include "game/game.h"
#include "tools/QtFolderCompressor/FolderCompressor.h"
#include "assetManager/asset_manager.h"


class QmlApp : public QQmlApplicationEngine
{
    Q_OBJECT

public:
    explicit QmlApp(QWindow *parent = nullptr);
    bool event(QEvent *event) override;
    ~QmlApp() override;


signals:

public slots:

private slots:

private:
    Game *game = nullptr;
    FolderCompressor *folderCompressor = nullptr;
    AssetManager *assetManager = nullptr;
    QNetworkAccessManager *networkManager = nullptr;
    static void registerQml();
};

#endif // __QMLAPP_H
