#include "maploader.h"

#include "game.h"
#include "map.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>

MapLoader *MapLoader::m_pThis = nullptr;

MapLoader::MapLoader(QObject *parent)
    : QObject(parent)
{}

void MapLoader::registerQml()
{
    qmlRegisterSingletonType<MapLoader>("MapLoader", 1, 0, "MapLoader", &MapLoader::qmlInstance);
}

MapLoader *MapLoader::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new MapLoader;
    }
    return m_pThis;
}

QObject *MapLoader::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return MapLoader::instance();
}

Map *MapLoader::loadMap(QString mapName)
{
    QJsonObject jsonObject = MapLoader::readMapFile(mapName);
    Map *map = new Map(jsonObject);
    for (ItemSnapable *is : map->caseTiles()) {
        emit foundCaseTile(is->displayParameter(), is->caseData());
    }
    emit mapLoaded(map);
    return map;
}

QJsonObject MapLoader::readMapFile(QString mapName)
{
    QString fileName = "map/" + mapName.toLower().replace(" ", "_") + "_map.json";
    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "Failed to open file for reading:" << fileName;
        return QJsonObject();
    }
    QByteArray fileData = file.readAll();
    QJsonDocument doc = QJsonDocument::fromJson(fileData);
    QJsonObject jsonObject = doc.object();
    return jsonObject;
}
