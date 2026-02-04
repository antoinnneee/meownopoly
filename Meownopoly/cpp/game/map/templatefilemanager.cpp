#include "templatefilemanager.h"

#include <QFile>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QUuid>

#include "tools/logger.h"

// Static member initialization
TemplateFileManager *TemplateFileManager::m_instance = nullptr;

void TemplateFileManager::registerQml()
{
    qmlRegisterSingletonType<TemplateFileManager>("TemplateFileManager", 1, 0, "TemplateFileManager", &TemplateFileManager::qmlInstance);
}

QObject *TemplateFileManager::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    return TemplateFileManager::instance();
}

TemplateFileManager *TemplateFileManager::instance()
{
    if (!m_instance) {
        m_instance = new TemplateFileManager();
    }
    return m_instance;
}

TemplateFileManager::TemplateFileManager(QObject *parent) : QObject(parent)
{
    ensureTemplateDirectoryExists();
}

// ==================== MÉTHODES QML (INSTANCE) ====================

bool TemplateFileManager::templateExists(const QString &templateName)
{
    QString filePath = getTemplateFilePath(templateName);
    return QFile::exists(filePath);
}

QStringList TemplateFileManager::getAvailableTemplates()
{
    QStringList templates;
    QDir templateDir(TEMPLATE_FILE_PATH);
    
    if (!templateDir.exists()) {
        qDebug() << "Template directory does not exist:" << TEMPLATE_FILE_PATH;
        return templates;
    }
    
    QStringList filters;
    filters << "*.json";
    QFileInfoList fileList = templateDir.entryInfoList(filters, QDir::Files);
    
    for (const QFileInfo &fileInfo : fileList) {
        QString fileName = fileInfo.baseName();
        
        // Remove "_template" suffix if present
        if (fileName.endsWith("_template")) {
            fileName = fileName.left(fileName.length() - 9);
        }
        
        templates.append(fileName);
    }
    
    return templates;
}

QString TemplateFileManager::getTemplatePath(const QString &templateName)
{
    return getTemplateFilePath(templateName);
}

// ==================== MÉTHODES C++ INTERNES (STATIC) ====================

QJsonObject TemplateFileManager::readTemplateFile(const QString &templateName)
{
    QString filePath = getTemplateFilePath(templateName);
    QFile file(filePath);
    
    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "Failed to open template file for reading:" << filePath;
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

bool TemplateFileManager::writeTemplateFile(const QJsonObject &templateData, const QString &templateName)
{
    ensureTemplateDirectoryExists();
    
    QString filePath = getTemplateFilePath(templateName);
    
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qDebug() << "Failed to open file for writing:" << filePath;
        return false;
    }
    
    QJsonDocument doc(templateData);
    QByteArray jsonData = doc.toJson(QJsonDocument::Indented);
    
    qint64 bytesWritten = file.write(jsonData);
    file.close();
    
    if (bytesWritten == -1) {
        qDebug() << "Failed to write to file:" << filePath;
        return false;
    }
    
    qDebug() << "Template saved successfully to:" << filePath;
    return true;
}

bool TemplateFileManager::removeTemplateFile(const QString &templateName)
{
    QString filePath = getTemplateFilePath(templateName);
    
    if (!QFile::exists(filePath)) {
        qDebug() << "Template file does not exist:" << filePath;
        return false;
    }
    
    if (!QFile::remove(filePath)) {
        qDebug() << "Failed to remove template file:" << filePath;
        return false;
    }
    
    qDebug() << "Template file removed successfully:" << filePath;
    return true;
}

// ==================== UTILITY METHODS (STATIC) ====================

QString TemplateFileManager::normalizeTemplateName(const QString &templateName)
{
    QString normalized = templateName.toLower();
    normalized = normalized.replace(" ", "_");
    normalized = normalized.trimmed();
    return normalized;
}

QVariantMap TemplateFileManager::calculateBoundingBox(const QJsonArray &elementsArray)
{
    QVariantMap bounds;
    
    if (elementsArray.isEmpty()) {
        bounds["x"] = 0;
        bounds["y"] = 0;
        bounds["width"] = 0;
        bounds["height"] = 0;
        return bounds;
    }
    
    int minX = INT_MAX, minY = INT_MAX;
    int maxX = INT_MIN, maxY = INT_MIN;
    
    for (const QJsonValue &value : elementsArray) {
        QJsonObject element = value.toObject();
        
        // Récupérer la position (gridRelativePositionX/Y sont les positions sur la grille)
        int posX = element["gridRelativePositionX"].toInt(0);
        int posY = element["gridRelativePositionY"].toInt(0);
        
        // Récupérer les dimensions (approximation via les paramètres)
        int width = 1;  // Par défaut 1 unité de grille
        int height = 1;
        
        // Essayer de récupérer les vraies dimensions depuis displayParameter
        if (element.contains("displayParameter")) {
            QJsonObject displayParam = element["displayParameter"].toObject();
            width = displayParam["width"].toInt(1);
            height = displayParam["height"].toInt(1);
        }
        
        minX = qMin(minX, posX);
        minY = qMin(minY, posY);
        maxX = qMax(maxX, posX + width);
        maxY = qMax(maxY, posY + height);
    }
    
    bounds["x"] = minX;
    bounds["y"] = minY;
    bounds["width"] = maxX - minX;
    bounds["height"] = maxY - minY;
    
    return bounds;
}

QJsonArray TemplateFileManager::convertToRelativePositions(const QJsonArray &elementsArray, int originX, int originY)
{
    QJsonArray relativeArray;
    
    for (const QJsonValue &value : elementsArray) {
        QJsonObject element = value.toObject();
        
        // Convertir les positions absolues en relatives
        int absX = element["gridRelativePositionX"].toInt(0);
        int absY = element["gridRelativePositionY"].toInt(0);
        
        // Stocker la position relative (par rapport à l'origine du template)
        element["relativePositionX"] = absX - originX;
        element["relativePositionY"] = absY - originY;
        
        // Supprimer les propriétés absolues et l'uniqueId (sera régénéré au placement)
        element.remove("gridRelativePositionX");
        element.remove("gridRelativePositionY");
        element.remove("uniqueId");
        
        // IMPORTANT : Supprimer aussi les positions dans displayParameter pour éviter pollution
        if (element.contains("displayParameter")) {
            QJsonObject displayParam = element["displayParameter"].toObject();
            displayParam.remove("gridRelativePositionX");
            displayParam.remove("gridRelativePositionY");
            element["displayParameter"] = displayParam;
        }
        
        // Note: on garde next/prev pour la structure, mais ils seront remappés au placement
        
        relativeArray.append(element);
    }
    
    return relativeArray;
}

QJsonArray TemplateFileManager::convertToAbsolutePositions(const QJsonArray &elementsArray, int targetX, int targetY)
{
    QJsonArray absoluteArray;
    
    for (const QJsonValue &value : elementsArray) {
        QJsonObject element = value.toObject();
        
        // Convertir les positions relatives en absolues
        int relX = element["relativePositionX"].toInt(0);
        int relY = element["relativePositionY"].toInt(0);
        
        int newAbsX = targetX + relX;
        int newAbsY = targetY + relY;
        
        element["gridRelativePositionX"] = newAbsX;
        element["gridRelativePositionY"] = newAbsY;
        
        // CRITIQUE : Mettre à jour AUSSI les positions dans displayParameter
        // Car ItemSnapable lit les positions depuis displayParameter, pas du top-level !
        if (element.contains("displayParameter")) {
            QJsonObject displayParam = element["displayParameter"].toObject();
            displayParam["gridRelativePositionX"] = newAbsX;
            displayParam["gridRelativePositionY"] = newAbsY;
            element["displayParameter"] = displayParam;
        }
        
        // Supprimer les propriétés relatives
        element.remove("relativePositionX");
        element.remove("relativePositionY");
        
        absoluteArray.append(element);
    }
    
    return absoluteArray;
}

QJsonArray TemplateFileManager::regenerateUniqueIds(const QJsonArray &elementsArray)
{
    QJsonArray newArray;
    QMap<QString, QString> idMapping; // oldId -> newId
    
    // Première passe : générer les nouveaux IDs et créer le mapping
    for (const QJsonValue &value : elementsArray) {
        QJsonObject element = value.toObject();
        
        QString oldId = element["uniqueId"].toString();
        QString newId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        
        if (!oldId.isEmpty()) {
            idMapping[oldId] = newId;
        }
        
        element["uniqueId"] = newId;
        newArray.append(element);
    }
    
    // Deuxième passe : mettre à jour les références next/prev
    QJsonArray finalArray;
    for (const QJsonValue &value : newArray) {
        QJsonObject element = value.toObject();
        
        // Mettre à jour les références next
        if (element.contains("next")) {
            QJsonArray nextArray = element["next"].toArray();
            QJsonArray newNextArray;
            for (const QJsonValue &nextVal : nextArray) {
                QString oldNextId = nextVal.toString();
                if (idMapping.contains(oldNextId)) {
                    newNextArray.append(idMapping[oldNextId]);
                }
                // Si l'ID n'est pas dans le mapping, c'est une référence externe - on la supprime
            }
            element["next"] = newNextArray;
        }
        
        // Mettre à jour les références prev
        if (element.contains("prev")) {
            QJsonArray prevArray = element["prev"].toArray();
            QJsonArray newPrevArray;
            for (const QJsonValue &prevVal : prevArray) {
                QString oldPrevId = prevVal.toString();
                if (idMapping.contains(oldPrevId)) {
                    newPrevArray.append(idMapping[oldPrevId]);
                }
                // Si l'ID n'est pas dans le mapping, c'est une référence externe - on la supprime
            }
            element["prev"] = newPrevArray;
        }
        
        finalArray.append(element);
    }
    
    return finalArray;
}

// ==================== HELPERS INTERNES ====================

QString TemplateFileManager::getTemplateFilePath(const QString &templateName)
{
    QString normalizedName = normalizeTemplateName(templateName);
    return QString(TEMPLATE_FILE_PATH) + normalizedName + "_template.json";
}

void TemplateFileManager::ensureTemplateDirectoryExists()
{
    QDir dir(TEMPLATE_FILE_PATH);
    if (!dir.exists()) {
        if (dir.mkpath(".")) {
            qDebug() << "Created template directory:" << TEMPLATE_FILE_PATH;
        } else {
            qWarning() << "Failed to create template directory:" << TEMPLATE_FILE_PATH;
        }
    }
}
