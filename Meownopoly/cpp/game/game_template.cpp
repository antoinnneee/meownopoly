#include "game.h"
#include <QDebug>
#include <QDateTime>

#include "map/templatefilemanager.h"
#include "tools/logger.h"

// ==================== TEMPLATE SAVING/LOADING ====================

bool Game::saveTemplate(QString name, QJsonArray elementsJson)
{
    qDebug() << "Game::saveTemplate called with name:" << name << "elements count:" << elementsJson.size();
    Logger::instance()->info(QString("saveTemplate called: %1, elements: %2").arg(name).arg(elementsJson.size()), "Game");
    
    if (name.isEmpty()) {
        Logger::instance()->error("Template name is empty", Q_FUNC_INFO);
        return false;
    }
    
    if (elementsJson.isEmpty()) {
        Logger::instance()->error("No elements to save in template", Q_FUNC_INFO);
        return false;
    }
    
    // 1. Calculer la bounding box pour obtenir l'origine
    QVariantMap bounds = TemplateFileManager::calculateBoundingBox(elementsJson);
    int originX = bounds["x"].toInt();
    int originY = bounds["y"].toInt();
    
    // 2. Convertir en positions relatives
    QJsonArray relativeElements = TemplateFileManager::convertToRelativePositions(elementsJson, originX, originY);
    
    // 3. Construire l'objet JSON complet du template
    QJsonObject templateJson;
    
    // Informations du template
    QJsonObject templateInfo;
    templateInfo["name"] = name;
    templateInfo["elementCount"] = relativeElements.size();
    templateInfo["boundingBoxWidth"] = bounds["width"].toInt();
    templateInfo["boundingBoxHeight"] = bounds["height"].toInt();
    templateInfo["creationDate"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    
    templateJson["templateInfo"] = templateInfo;
    templateJson["elements"] = relativeElements;
    
    // 4. Sauvegarder via TemplateFileManager
    bool success = TemplateFileManager::writeTemplateFile(templateJson, name);
    
    if (success) {
        Logger::instance()->info(QString("Template saved successfully: %1").arg(name), "Game");
    } else {
        Logger::instance()->error(QString("Failed to save template: %1").arg(name), Q_FUNC_INFO);
    }
    
    return success;
}

bool Game::deleteTemplate(QString name)
{
    qDebug() << "Game::deleteTemplate called with name:" << name;
    Logger::instance()->info(QString("deleteTemplate called: %1").arg(name), "Game");
    
    if (name.isEmpty()) {
        Logger::instance()->error("Template name is empty", Q_FUNC_INFO);
        return false;
    }
    
    bool success = TemplateFileManager::removeTemplateFile(name);
    
    if (success) {
        Logger::instance()->info(QString("Template deleted successfully: %1").arg(name), "Game");
    } else {
        Logger::instance()->error(QString("Failed to delete template: %1").arg(name), Q_FUNC_INFO);
    }
    
    return success;
}

QJsonObject Game::loadTemplate(QString name)
{
    qDebug() << "Game::loadTemplate called with name:" << name;
    Logger::instance()->info(QString("loadTemplate called: %1").arg(name), "Game");
    
    if (name.isEmpty()) {
        Logger::instance()->error("Template name is empty", Q_FUNC_INFO);
        return QJsonObject();
    }
    
    QJsonObject templateData = TemplateFileManager::readTemplateFile(name);
    
    if (templateData.isEmpty()) {
        Logger::instance()->error(QString("Failed to load template: %1").arg(name), Q_FUNC_INFO);
    } else {
        Logger::instance()->info(QString("Template loaded successfully: %1").arg(name), "Game");
    }
    
    return templateData;
}

QJsonArray Game::getTemplateElementsForPlacement(QString name, int targetX, int targetY)
{
    qDebug() << "Game::getTemplateElementsForPlacement called:" << name << "at" << targetX << targetY;
    
    // 1. Charger le template
    QJsonObject templateData = loadTemplate(name);
    if (templateData.isEmpty()) {
        return QJsonArray();
    }
    
    // 2. Récupérer les éléments
    QJsonArray elements = templateData["elements"].toArray();
    if (elements.isEmpty()) {
        Logger::instance()->error(QString("Template has no elements: %1").arg(name), Q_FUNC_INFO);
        return QJsonArray();
    }
    
    // 3. Convertir en positions absolues
    QJsonArray absoluteElements = TemplateFileManager::convertToAbsolutePositions(elements, targetX, targetY);
    
    // 4. Régénérer les uniqueIds (et mettre à jour les liens next/prev)
    QJsonArray finalElements = TemplateFileManager::regenerateUniqueIds(absoluteElements);
    
    Logger::instance()->info(QString("Template elements prepared for placement: %1, count: %2")
                            .arg(name).arg(finalElements.size()), "Game");
    
    return finalElements;
}
