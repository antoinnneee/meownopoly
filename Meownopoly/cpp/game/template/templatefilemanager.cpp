#include "templatefilemanager.h"
#include "templateinfo.h"
#include <QFile>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QDateTime>
#include <QUuid>
#include "tools/logger.h"

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
    ensureDirectoriesExist();
}

void TemplateFileManager::ensureDirectoriesExist()
{
    QDir defaultDir(DEFAULT_TEMPLATE_PATH);
    if (!defaultDir.exists()) {
        defaultDir.mkpath(".");
    }
    QDir userDir(USER_TEMPLATE_PATH);
    if (!userDir.exists()) {
        userDir.mkpath(".");
    }
}

bool TemplateFileManager::templateExists(const QString &templateName, TemplateType type)
{
    QString filePath = getTemplateFilePath(templateName, type);
    return QFile::exists(filePath);
}

QStringList TemplateFileManager::getAvailableTemplates(TemplateType type)
{
    QStringList templates;
    QString path = (type == DEFAULT) ? DEFAULT_TEMPLATE_PATH : USER_TEMPLATE_PATH;
    QDir templateDir(path);
    if (!templateDir.exists()) return templates;
    QStringList filters;
    filters << "*.json";
    QFileInfoList fileList = templateDir.entryInfoList(filters, QDir::Files);
    for (const QFileInfo &fileInfo : fileList) {
        QString fileName = fileInfo.baseName();
        if (fileName.endsWith("_template")) {
            fileName = fileName.left(fileName.length() - 9);
        }
        templates.append(fileName);
    }
    return templates;
}

QStringList TemplateFileManager::getAllTemplates()
{
    QStringList allTemplates;
    QStringList defaultTemplates = getAvailableTemplates(DEFAULT);
    for (const QString &t : defaultTemplates) {
        allTemplates.append("[Default] " + t);
    }
    QStringList userTemplates = getAvailableTemplates(USER);
    for (const QString &t : userTemplates) {
        allTemplates.append(t);
    }
    return allTemplates;
}

QString TemplateFileManager::findTemplateByName(const QString &displayName)
{
    QString normalizedName = normalizeTemplateName(displayName);
    if (templateExists(normalizedName, USER)) return normalizedName;
    if (templateExists(normalizedName, DEFAULT)) return normalizedName;
    return QString();
}

QString TemplateFileManager::createTemplateFile(const QString &templateName)
{
    QString normalizedName = normalizeTemplateName(templateName);
    QString filePath = getTemplateFilePath(normalizedName, USER);
    QJsonObject emptyTemplate;
    QJsonObject templateInfo;
    templateInfo["name"] = templateName;
    templateInfo["description"] = "";
    templateInfo["creationDate"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    templateInfo["author"] = "";
    templateInfo["version"] = 1;
    templateInfo["boundingBoxWidth"] = 0;
    templateInfo["boundingBoxHeight"] = 0;
    templateInfo["originOffsetX"] = 0;
    templateInfo["originOffsetY"] = 0;
    templateInfo["elementCount"] = 0;
    templateInfo["thumbnailPath"] = "";
    templateInfo["isDefault"] = false;
    emptyTemplate["templateInfo"] = templateInfo;
    emptyTemplate["elements"] = QJsonArray();
    if (saveTemplate(emptyTemplate, normalizedName, USER)) {
        return filePath;
    }
    return QString();
}

bool TemplateFileManager::deleteTemplate(const QString &templateName)
{
    if (isDefaultTemplate(templateName)) {
        Logger::instance()->error("Cannot delete default template: " + templateName, Q_FUNC_INFO);
        return false;
    }
    return removeTemplateFile(templateName, USER);
}

bool TemplateFileManager::renameTemplate(const QString &oldName, const QString &newName)
{
    if (isDefaultTemplate(oldName)) return false;
    if (!templateExists(oldName, USER)) return false;
    if (templateExists(newName, USER)) return false;
    QString oldPath = getTemplateFilePath(oldName, USER);
    QString newPath = getTemplateFilePath(newName, USER);
    QFile file(oldPath);
    return file.rename(newPath);
}

QJsonObject TemplateFileManager::getTemplateInfo(const QString &templateName)
{
    TemplateType type = getTemplateType(templateName);
    QJsonObject templateData = readTemplateFile(templateName, type);
    if (templateData.isEmpty()) return QJsonObject();
    return templateData["templateInfo"].toObject();
}

TemplateFileManager::TemplateType TemplateFileManager::getTemplateType(const QString &templateName)
{
    if (templateExists(templateName, DEFAULT)) return DEFAULT;
    return USER;
}

bool TemplateFileManager::isDefaultTemplate(const QString &templateName)
{
    return templateExists(templateName, DEFAULT);
}

QJsonObject TemplateFileManager::readTemplateFile(const QString &templateName, TemplateType type)
{
    QString filePath = getTemplateFilePath(templateName, type);
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) return QJsonObject();
    QByteArray data = file.readAll();
    file.close();
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError) return QJsonObject();
    if (!doc.isObject()) return QJsonObject();
    return doc.object();
}

bool TemplateFileManager::saveTemplate(const QJsonObject &templateData, const QString &templateName, TemplateType type)
{
    if (type == DEFAULT) return false;
    QString filePath = getTemplateFilePath(templateName, type);
    QDir dir = QFileInfo(filePath).dir();
    if (!dir.exists()) dir.mkpath(".");
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    QJsonDocument doc(templateData);
    QByteArray jsonData = doc.toJson(QJsonDocument::Indented);
    qint64 bytesWritten = file.write(jsonData);
    file.close();
    return bytesWritten != -1;
}

bool TemplateFileManager::removeTemplateFile(const QString &templateName, TemplateType type)
{
    if (type == DEFAULT) return false;
    QString filePath = getTemplateFilePath(templateName, type);
    if (!QFile::exists(filePath)) return false;
    return QFile::remove(filePath);
}

QString TemplateFileManager::normalizeTemplateName(const QString &templateName)
{
    QString normalized = templateName.toLower();
    normalized = normalized.replace(" ", "_");
    normalized = normalized.trimmed();
    if (normalized.startsWith("[default] ")) {
        normalized = normalized.mid(10);
    }
    return normalized;
}

QString TemplateFileManager::getTemplateFilePath(const QString &templateName, TemplateType type)
{
    QString basePath = (type == DEFAULT) ? DEFAULT_TEMPLATE_PATH : USER_TEMPLATE_PATH;
    QString normalizedName = normalizeTemplateName(templateName);
    return basePath + normalizedName + "_template.json";
}

QJsonArray TemplateFileManager::convertElementsToTemplateFormat(const QJsonArray &elements, int originX, int originY)
{
    QJsonArray templateElements;
    for (const QJsonValue &value : elements) {
        QJsonObject element = value.toObject();
        QJsonObject newElement;
        if (element.contains("caseData")) newElement["caseData"] = element["caseData"];
        if (element.contains("decorationParameter")) newElement["decorationParameter"] = element["decorationParameter"];
        if (element.contains("tileType")) newElement["tileType"] = element["tileType"];
        if (element.contains("polygonParameter")) newElement["polygonParameter"] = element["polygonParameter"];
        if (element.contains("displayParameter")) {
            QJsonObject displayParam = element["displayParameter"].toObject();
            QJsonObject newDisplayParam = displayParam;
            int absX = displayParam["gridRelativePositionX"].toInt();
            int absY = displayParam["gridRelativePositionY"].toInt();
            newElement["relativePositionX"] = absX - originX;
            newElement["relativePositionY"] = absY - originY;
            newDisplayParam.remove("gridRelativePositionX");
            newDisplayParam.remove("gridRelativePositionY");
            newElement["displayParameter"] = newDisplayParam;
        }
        templateElements.append(newElement);
    }
    return templateElements;
}

QJsonArray TemplateFileManager::convertTemplateElementsToMapFormat(const QJsonArray &templateElements, int targetX, int targetY)
{
    QJsonArray mapElements;
    for (const QJsonValue &value : templateElements) {
        QJsonObject element = value.toObject();
        QJsonObject newElement;
        if (element.contains("caseData")) newElement["caseData"] = element["caseData"];
        if (element.contains("decorationParameter")) newElement["decorationParameter"] = element["decorationParameter"];
        if (element.contains("tileType")) newElement["tileType"] = element["tileType"];
        if (element.contains("polygonParameter")) newElement["polygonParameter"] = element["polygonParameter"];
        if (element.contains("displayParameter")) {
            QJsonObject displayParam = element["displayParameter"].toObject();
            int relX = element["relativePositionX"].toInt(0);
            int relY = element["relativePositionY"].toInt(0);
            displayParam["gridRelativePositionX"] = targetX + relX;
            displayParam["gridRelativePositionY"] = targetY + relY;
            newElement["displayParameter"] = displayParam;
        }
        newElement["next"] = QJsonArray();
        newElement["prev"] = QJsonArray();
        newElement["uniqueId"] = QUuid::createUuid().toString();
        mapElements.append(newElement);
    }
    return mapElements;
}