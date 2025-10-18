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

Map *MapLoader::loadMap(QString mapName, MapType mapType)
{
    qDebug() << Q_FUNC_INFO << "Loading map:" << mapName << "Type:" << mapType;
    QJsonObject jsonObject = MapLoader::readMapFile(mapName, mapType);
    MapInfo *mapInfo = new MapInfo(jsonObject["mapInfo"].toObject());
    Map *map = new Map(jsonObject);
    for (ItemSnapable *is : map->caseTiles()) {
        emit foundCaseTile(is->displayParameter(), is->caseData());
    }
    for (ItemSnapable *is : map->decorationTiles()) {
        emit foundDecorationTile(is->displayParameter(), is->decorationParameter());
    }
    map->setMapInfo(mapInfo);
    emit mapLoaded(map);
    return map;
}

QStringList MapLoader::getAvailableMaps()
{
    QStringList mapList;
    QDir mapDir("map");

    // VErifier si le dossier map existe
    if (!mapDir.exists()) {
        qDebug() << "Map directory does not exist: map/";
        return mapList;
    }

    // Filtrer les fichiers JSON qui se terminent par "_map.json"
    QStringList filters;
    filters << "*_map.json";
    QStringList jsonFiles = mapDir.entryList(filters, QDir::Files);

    // Extraire le nom de la map de chaque fichier en lisant le JSON
    for (const QString &fileName : jsonFiles) {
        QFileInfo fileInfo(fileName);
        QString baseName = fileInfo.baseName(); // Nom sans extension

        // Retirer le suffixe "_map" pour obtenir le nom de fichier normalise
        if (baseName.endsWith("_map")) {
            QString normalizedMapName = baseName.left(baseName.length() - 4); // Enlever "_map"
            if (!normalizedMapName.isEmpty()) {
                // Lire le nom reel depuis le JSON
                QJsonObject jsonObject = readMapFile(normalizedMapName, CUSTOM);
                if (!jsonObject.isEmpty() && jsonObject.contains("mapInfo")) {
                    QJsonObject mapInfo = jsonObject["mapInfo"].toObject();
                    QString realMapName = mapInfo["name"].toString();
                    if (!realMapName.isEmpty()) {
                        mapList.append(realMapName);
                    } else {
                        // Fallback au nom normalisE si le nom dans le JSON est vide
                        mapList.append(normalizedMapName);
                    }
                } else {
                    // Fallback au nom normalisE si le JSON ne peut pas être lu
                    mapList.append(normalizedMapName);
                }
            }
        }
    }

    // Trier la liste par ordre alphabEtique
    mapList.sort();

    qDebug() << "Found" << mapList.size() << "maps:" << mapList;
    return mapList;
}

QString MapLoader::findMapFileByName(const QString &displayName)
{
    QDir mapDir("map");

    // Verifier si le dossier map existe
    if (!mapDir.exists()) {
        qDebug() << "Map directory does not exist: map/";
        return "";
    }

    // Filtrer les fichiers JSON qui se terminent par "_map.json"
    QStringList filters;
    filters << "*_map.json";
    QStringList jsonFiles = mapDir.entryList(filters, QDir::Files);

    // Chercher le fichier qui contient le nom d'affichage donne
    for (const QString &fileName : jsonFiles) {
        QFileInfo fileInfo(fileName);
        QString baseName = fileInfo.baseName(); // Nom sans extension

        // Retirer le suffixe "_map" pour obtenir le nom de fichier normalisE
        if (baseName.endsWith("_map")) {
            QString normalizedMapName = baseName.left(baseName.length() - 4); // Enlever "_map"
            if (!normalizedMapName.isEmpty()) {
                // Lire le nom reel depuis le JSON
                QJsonObject jsonObject = readMapFile(normalizedMapName, CUSTOM);
                if (!jsonObject.isEmpty() && jsonObject.contains("mapInfo")) {
                    QJsonObject mapInfo = jsonObject["mapInfo"].toObject();
                    QString realMapName = mapInfo["name"].toString();
                    if (realMapName == displayName) {
                        return normalizedMapName; // Retourner le nom de fichier normalisE
                    }
                }
            }
        }
    }

    qDebug() << "No map file found for display name:" << displayName;
    return "";
}

QJsonObject MapLoader::readMapFile(QString mapName, MapType mapType)
{
    QString fileName;
    switch (mapType){
    case AUTOSAVE:
        fileName = (QString)MAP_FILE_PATH + (QString)AUTOSAVE_MAP_NAME + ".json";;
        break;
    case CUSTOM:
        fileName = (QString)MAP_FILE_PATH + mapName.toLower().replace(" ", "_").trimmed() + "_map.json";
        break;
    }


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

bool MapLoader::mapAlreadyExist(const QString &mapName, MapType mapType)
{
    bool flag = false;
    switch (mapType) {
    case AUTOSAVE:
        flag = QFile::exists((QString)MAP_FILE_PATH + (QString)AUTOSAVE_MAP_NAME + ".json");
        break;
    case CUSTOM:
        if (mapName != (QString)AUTOSAVE_MAP_NAME) // Prevent conflict with autosave map
            flag = QFile::exists(MAP_FILE_PATH + mapName.toLower().replace(" ", "_").trimmed() + "_map.json");
        break;
    }
    return flag;
}

QString MapLoader::createJsonMap(const QString &mapName, MapType mapType)
{
    switch (mapType){
    case AUTOSAVE:{
        QFile autosaveMap((QString)MAP_FILE_PATH + (QString)AUTOSAVE_MAP_NAME + ".json");
        qDebug() << "create autosave map " << " " << autosaveMap.open(QIODevice::WriteOnly);
        autosaveMap.close();
        if (!autosaveMap.exists()){
            qDebug() << "Can't create autosave map file";
            return "";
        }
        else
            return autosaveMap.fileName();
        break;
    }
    case CUSTOM:{
        QFile customMap((QString)MAP_FILE_PATH + mapName.toLower().replace(" ", "_").trimmed() + "_map.json");
        qDebug() << "Create custom map " << customMap.open(QIODevice::WriteOnly);
        customMap.close();
        if (!customMap.exists()){
            qDebug() << "Can't create custom map file";
            return "";
        }
        else
            return customMap.fileName();
        break;
    }
    }
    return "";
}

bool MapLoader::removeJsonMap(const QString &mapName, MapType mapType)
{
    bool flag = false;
    switch (mapType) {
    case AUTOSAVE:
        flag = QFile::remove((QString)MAP_FILE_PATH + (QString)AUTOSAVE_MAP_NAME + ".json");
        break;
    case CUSTOM:
        flag = QFile::remove(MAP_FILE_PATH + mapName.toLower().replace(" ", "_").trimmed() + "_map.json");
        break;
    }
    return flag;
}




