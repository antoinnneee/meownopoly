#include "templatemanager.h"
#include "templatemodel.h"
#include <QQmlEngine>
#include <QJsonDocument>
#include <QDateTime>
#include <QDebug>

TemplateManager *TemplateManager::m_instance = nullptr;

TemplateManager::TemplateManager(QObject *parent) : QObject(parent) {}

void TemplateManager::registerQml()
{
    qmlRegisterSingletonType<TemplateManager>("TemplateManager", 1, 0, "TemplateManager", &TemplateManager::qmlInstance);
}

QObject *TemplateManager::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    return TemplateManager::instance();
}

TemplateManager *TemplateManager::instance()
{
    if (!m_instance) {
        m_instance = new TemplateManager();
    }
    return m_instance;
}

QString TemplateManager::currentTemplateName() const { return m_currentTemplateName; }

void TemplateManager::setCurrentTemplateName(const QString &name)
{
    if (m_currentTemplateName != name) {
        m_currentTemplateName = name;
        emit currentTemplateNameChanged();
        if (!name.isEmpty()) {
            selectTemplate(name);
        } else {
            m_currentTemplateData = QJsonObject();
            emit currentTemplateDataChanged();
        }
    }
}

QJsonObject TemplateManager::currentTemplateData() const { return m_currentTemplateData; }
bool TemplateManager::hasCurrentTemplate() const { return !m_currentTemplateData.isEmpty(); }

bool TemplateManager::createTemplateFromElements(const QString &templateName, QVariantList elements)
{
    if (templateName.isEmpty() || elements.isEmpty()) return false;
    QJsonArray elementsJson;
    for (const QVariant &var : elements) {
        ItemSnapable *item = qvariant_cast<ItemSnapable*>(var);
        if (item) {
            QString jsonStr = item->toJSON();
            QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
            if (!doc.isNull() && doc.isObject()) {
                elementsJson.append(doc.object());
            }
        }
    }
    return createTemplateFromJson(templateName, elementsJson);
}

bool TemplateManager::createTemplateFromJson(const QString &templateName, const QJsonArray &elementsJson)
{
    if (templateName.isEmpty() || elementsJson.isEmpty()) return false;
    BoundingBox bbox = calculateBoundingBox(elementsJson);
    if (bbox.minX == INT_MAX) return false;

    QJsonObject templateInfo;
    templateInfo["name"] = templateName;
    templateInfo["description"] = "";
    templateInfo["creationDate"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    templateInfo["author"] = "";
    templateInfo["version"] = 1;
    templateInfo["boundingBoxWidth"] = bbox.width();
    templateInfo["boundingBoxHeight"] = bbox.height();
    templateInfo["originOffsetX"] = 0;
    templateInfo["originOffsetY"] = 0;
    templateInfo["elementCount"] = elementsJson.count();
    templateInfo["thumbnailPath"] = "";
    templateInfo["isDefault"] = false;

    QJsonArray templateElements = TemplateFileManager::convertElementsToTemplateFormat(elementsJson, bbox.minX, bbox.minY);
    QJsonObject templateData;
    templateData["templateInfo"] = templateInfo;
    templateData["elements"] = templateElements;

    bool success = TemplateFileManager::saveTemplate(templateData, templateName, TemplateFileManager::USER);
    if (success) {
        TemplateModel::instance()->refresh();
        emit templateCreated(templateName);
    }
    return success;
}

bool TemplateManager::selectTemplate(const QString &templateName)
{
    if (templateName.isEmpty()) { clearSelection(); return false; }
    TemplateFileManager::TemplateType type = TemplateFileManager::instance()->getTemplateType(templateName);
    QJsonObject data = TemplateFileManager::readTemplateFile(templateName, type);
    if (data.isEmpty()) return false;
    m_currentTemplateName = templateName;
    m_currentTemplateData = data;
    emit currentTemplateNameChanged();
    emit currentTemplateDataChanged();
    emit templateSelected(templateName);
    return true;
}

void TemplateManager::clearSelection()
{
    m_currentTemplateName.clear();
    m_currentTemplateData = QJsonObject();
    emit currentTemplateNameChanged();
    emit currentTemplateDataChanged();
}

QList<ItemSnapable*> TemplateManager::generateTemplateElements(int targetGridX, int targetGridY)
{
    QList<ItemSnapable*> items;
    if (!hasCurrentTemplate()) return items;
    QJsonArray templateElements = m_currentTemplateData["elements"].toArray();
    QJsonArray mapElements = TemplateFileManager::convertTemplateElementsToMapFormat(templateElements, targetGridX, targetGridY);
    for (const QJsonValue &value : mapElements) {
        QJsonObject elementJson = value.toObject();
        ItemSnapable *item = new ItemSnapable(elementJson);
        items.append(item);
    }
    emit templatePlaced(targetGridX, targetGridY, items.count());
    return items;
}

QJsonArray TemplateManager::generateTemplateElementsJson(int targetGridX, int targetGridY)
{
    if (!hasCurrentTemplate()) return QJsonArray();
    QJsonArray templateElements = m_currentTemplateData["elements"].toArray();
    QJsonArray mapElements = TemplateFileManager::convertTemplateElementsToMapFormat(templateElements, targetGridX, targetGridY);
    emit templatePlaced(targetGridX, targetGridY, mapElements.count());
    return mapElements;
}

QVariantMap TemplateManager::getCurrentTemplateBounds() const
{
    QVariantMap bounds;
    if (!hasCurrentTemplate()) return bounds;
    QJsonObject info = m_currentTemplateData["templateInfo"].toObject();
    bounds["width"] = info["boundingBoxWidth"].toInt(0);
    bounds["height"] = info["boundingBoxHeight"].toInt(0);
    bounds["originOffsetX"] = info["originOffsetX"].toInt(0);
    bounds["originOffsetY"] = info["originOffsetY"].toInt(0);
    bounds["elementCount"] = info["elementCount"].toInt(0);
    return bounds;
}

bool TemplateManager::deleteTemplate(const QString &templateName)
{
    if (TemplateFileManager::instance()->isDefaultTemplate(templateName)) return false;
    bool success = TemplateFileManager::instance()->deleteTemplate(templateName);
    if (success) {
        if (m_currentTemplateName == templateName) clearSelection();
        TemplateModel::instance()->refresh();
        emit templateDeleted(templateName);
    }
    return success;
}

void TemplateManager::refreshTemplates() { TemplateModel::instance()->refresh(); }

TemplateManager::BoundingBox TemplateManager::calculateBoundingBox(const QJsonArray &elements) const
{
    BoundingBox bbox;
    for (const QJsonValue &value : elements) {
        QJsonObject element = value.toObject();
        QJsonObject displayParam = element["displayParameter"].toObject();
        int x = displayParam["gridRelativePositionX"].toInt(0);
        int y = displayParam["gridRelativePositionY"].toInt(0);
        int width = displayParam["unitSizeWidth"].toInt(1);
        int height = displayParam["unitSizeHeight"].toInt(1);
        bbox.minX = qMin(bbox.minX, x);
        bbox.minY = qMin(bbox.minY, y);
        bbox.maxX = qMax(bbox.maxX, x + width);
        bbox.maxY = qMax(bbox.maxY, y + height);
    }
    return bbox;
}