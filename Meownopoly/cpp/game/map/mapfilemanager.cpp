#include "mapfilemanager.h"
#include "maptypes.h"

#include <QFile>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QStandardPaths>
#include <QCoreApplication>

// Static member initialization
MapFileManager *MapFileManager::m_instance = nullptr;

void MapFileManager::registerQml()
{
    qmlRegisterSingletonType<MapFileManager>("MapFileManager", 1, 0, "MapFileManager", &MapFileManager::qmlInstance);
    qmlRegisterType<MapTypes::MapType>("MapTypes", 1, 0, "MapTypes");

}

QObject *MapFileManager::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    return MapFileManager::instance();
}

MapFileManager *MapFileManager::instance()
{
    if (!m_instance) {
        m_instance = new MapFileManager();
    }
    return m_instance;
}

MapFileManager::MapFileManager(QObject *parent) : QObject(parent)
{
}

QJsonObject MapFileManager::readMapFile(const QString &mapName, MapTypes::MapType mapType)
{
    QString filePath = getMapFilePath(mapName, mapType);
    QFile file(filePath);
    
    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "Failed to open map file for reading:" << filePath;
        return QJsonObject();
    }
    
    QByteArray data = file.readAll();
    file.close();
    
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    
    if (parseError.error != QJsonParseError::NoError) {
        qDebug() << "JSON parse error in" << filePath << ":" << parseError.errorString();
        return QJsonObject();
    }
    
    if (!doc.isObject()) {
        qDebug() << "Invalid JSON format in" << filePath << "- expected object";
        return QJsonObject();
    }
    
    return doc.object();
}

QStringList MapFileManager::getAvailableMaps()
{
    QStringList maps;
    QDir mapDir(MAP_FILE_PATH);
    
    if (!mapDir.exists()) {
        qDebug() << "Map directory does not exist:" << MAP_FILE_PATH;
        return maps;
    }
    
    QStringList filters;
    filters << "*.json";
    QFileInfoList fileList = mapDir.entryInfoList(filters, QDir::Files);
    
    for (const QFileInfo &fileInfo : fileList) {
        QString fileName = fileInfo.baseName();
        
        // Skip autosave files
        if (fileName == AUTOSAVE_MAP_NAME) {
            continue;
        }
        
        // Remove "_map" suffix if present
        if (fileName.endsWith("_map")) {
            fileName = fileName.left(fileName.length() - 4);
        }
        
        maps.append(fileName);
    }
    
    return maps;
}

QString MapFileManager::findMapFileByName(const QString &displayName)
{
    QString normalizedName = normalizeMapName(displayName);
    QString filePath = getMapFilePath(normalizedName, MapTypes::CUSTOM);
    
    if (QFile::exists(filePath)) {
        return normalizedName;  // Retourner le nom normalisé, pas le chemin complet
    }
    
    return QString();
}

bool MapFileManager::mapExists(const QString &mapName, MapTypes::MapType mapType)
{
    QString filePath = getMapFilePath(mapName, mapType);
    return QFile::exists(filePath);
}

bool MapFileManager::saveMap(const QJsonObject &mapData, const QString &mapName, MapTypes::MapType mapType)
{
    QString filePath = getMapFilePath(mapName, mapType);
    
    // Ensure directory exists
    QDir dir = QFileInfo(filePath).dir();
    if (!dir.exists()) {
        if (!dir.mkpath(".")) {
            qDebug() << "Failed to create map directory:" << dir.path();
            return false;
        }
    }
    
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qDebug() << "Failed to open file for writing:" << filePath;
        return false;
    }
    
    QJsonDocument doc(mapData);
    QByteArray jsonData = doc.toJson(QJsonDocument::Indented);
    
    qint64 bytesWritten = file.write(jsonData);
    file.close();
    
    if (bytesWritten == -1) {
        qDebug() << "Failed to write to file:" << filePath;
        return false;
    }
    
    qDebug() << "Map saved successfully to:" << filePath;
    qDebug().noquote() << QString::fromUtf8(jsonData);
    return true;
}

QString MapFileManager::createMapFile(const QString &mapName, MapTypes::MapType mapType)
{
    QString normalizedName = normalizeMapName(mapName);
    QString filePath = getMapFilePath(normalizedName, mapType);
    qDebug() << Q_FUNC_INFO << "Creating map file at:" << filePath;
    // Create empty JSON object
    QJsonObject emptyMap;
    QJsonObject emptyMapInfo;
    emptyMapInfo["mapName"] = mapName;
    emptyMapInfo["description"] = "";
    emptyMapInfo["author"] = "";
    emptyMap["mapInfo"] = emptyMapInfo;
    emptyMap["snapableTiles"] = QJsonArray();
    
    if (saveMap(emptyMap, normalizedName, mapType)) {
        return filePath;
    }
    
    return QString();
}

bool MapFileManager::removeMapFile(const QString &mapName, MapTypes::MapType mapType)
{
    QString filePath = getMapFilePath(mapName, mapType);
    
    if (!QFile::exists(filePath)) {
        qDebug() << "Map file does not exist:" << filePath;
        return false;
    }
    
    if (!QFile::remove(filePath)) {
        qDebug() << "Failed to remove map file:" << filePath;
        return false;
    }
    
    qDebug() << "Map file removed successfully:" << filePath;
    return true;
}

QString MapFileManager::normalizeMapName(const QString &mapName)
{
    QString normalized = mapName.toLower();
    normalized = normalized.replace(" ", "_");
    normalized = normalized.trimmed();
    return normalized;
}

QString MapFileManager::getMapFilePath(const QString &mapName, MapTypes::MapType mapType)
{
    QString fileName;
    QString normalizedName = normalizeMapName(mapName);
    
    switch (mapType) {
    case MapTypes::AUTOSAVE:
        fileName = (QString)AUTOSAVE_MAP_NAME + ".json";
        break;
    case MapTypes::CUSTOM:
        fileName = normalizedName + "_map.json";
        break;
    // UNDO REDO NOT USED
    case MapTypes::UNDOREDO:
        qWarning() << Q_FUNC_INFO << "  - SHOULD NOT BEEN SEEN WITH UNDOREDO TYPE";
        fileName = normalizedName + "_undo.json";
        break;
    default:
        qDebug() << "Unknown map type:" << static_cast<int>(mapType);
        fileName = normalizedName + ".json";
        break;
    }
    
    return MAP_FILE_PATH + fileName;
}
