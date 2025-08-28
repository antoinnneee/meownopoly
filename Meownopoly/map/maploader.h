#ifndef MAPLOADER_H
#define MAPLOADER_H

#include <QObject>
#include <QQmlEngine>
#include <map/map.h>
#include <map/mapinfo.h>

class MapLoader : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static MapLoader *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE Map *loadMap(QString mapName);
    Q_INVOKABLE QStringList getAvailableMaps();
    static QJsonObject readMapFile(QString mapName);

public slots:

signals:
    void mapLoaded(Map *map, MapInfo *mapInfo);
    void foundCaseTile(DisplayParameter *dp, Case *caseData);

private slots:

private:
    explicit MapLoader(QObject *parent = nullptr);
    static MapLoader *m_pThis;
};

#endif // MAPLOADER_H
