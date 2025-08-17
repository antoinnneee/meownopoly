#ifndef __QMLAPP_H
#define __QMLAPP_H

#include <QObject>
#include <QQmlApplicationEngine>
#include <QtQuick/QQuickView>
#include "game.h"
#include "QtFolderCompressor/FolderCompressor.h"

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
    
    void autoExtractAssets();
};

#endif // __QMLAPP_H
