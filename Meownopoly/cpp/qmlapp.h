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
#include "game/physics/physics_world.h"
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
    // Instance globale du moteur physique partagée par toutes les scènes QML
    // (éditeur, CatwayTest, futurs World3D). Décision actée Phase 4 : un
    // PhysicsWorld par scène — cette instance unique est transitoire le temps
    // que le World3D arrive et que chaque scène en instancie le sien.
    PhysicsWorld *physicsWorld = nullptr;
    static void registerQml();
};

#endif // __QMLAPP_H
