#include "maploader.h"

#include "game.h"
#include "map.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QDir>
#include <QFileInfo>

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

QStringList MapLoader::getAvailableMaps()
{
    QStringList mapList;
    QDir mapDir("map");
    
    // Vérifier si le dossier map existe
    if (!mapDir.exists()) {
        qDebug() << "Map directory does not exist: map/";
        return mapList;
    }
    
    // Filtrer les fichiers JSON qui se terminent par "_map.json"
    QStringList filters;
    filters << "*_map.json";
    QStringList jsonFiles = mapDir.entryList(filters, QDir::Files);
    
    // Extraire le nom de la map de chaque fichier
    for (const QString &fileName : jsonFiles) {
        QFileInfo fileInfo(fileName);
        QString baseName = fileInfo.baseName(); // Nom sans extension
        
        // Retirer le suffixe "_map" pour obtenir le nom de la map
        if (baseName.endsWith("_map")) {
            QString mapName = baseName.left(baseName.length() - 4); // Enlever "_map"
            if (!mapName.isEmpty()) {
                mapList.append(mapName);
            }
        }
    }
    
    // Trier la liste par ordre alphabétique
    mapList.sort();
    
    qDebug() << "Found" << mapList.size() << "maps:" << mapList;
    return mapList;
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
