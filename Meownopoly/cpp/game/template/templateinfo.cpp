#include "templateinfo.h"
#include <QQmlEngine>
#include <QJsonDocument>
#include <QDateTime>

TemplateInfo::TemplateInfo(QObject *parent) 
    : QObject(parent)
{
}

TemplateInfo::TemplateInfo(const QJsonObject &json, QObject *parent)
    : QObject(parent)
{
    m_templateName = json["name"].toString();
    m_templateDescription = json["description"].toString();
    m_templateCreationDate = json["creationDate"].toString();
    m_templateAuthor = json["author"].toString();
    m_version = json["version"].toInt(1);
    m_boundingBoxWidth = json["boundingBoxWidth"].toInt(0);
    m_boundingBoxHeight = json["boundingBoxHeight"].toInt(0);
    m_originOffsetX = json["originOffsetX"].toInt(0);
    m_originOffsetY = json["originOffsetY"].toInt(0);
    m_elementCount = json["elementCount"].toInt(0);
    m_thumbnailPath = json["thumbnailPath"].toString();
    m_isDefault = json["isDefault"].toBool(false);
}

void TemplateInfo::registerQml()
{
    qmlRegisterType<TemplateInfo>("TemplateInfo", 1, 0, "TemplateInfo");
}

QJsonObject TemplateInfo::toJsonObject() const
{
    QJsonObject json;
    json["name"] = m_templateName;
    json["description"] = m_templateDescription;
    json["creationDate"] = m_templateCreationDate;
    json["author"] = m_templateAuthor;
    json["version"] = m_version;
    json["boundingBoxWidth"] = m_boundingBoxWidth;
    json["boundingBoxHeight"] = m_boundingBoxHeight;
    json["originOffsetX"] = m_originOffsetX;
    json["originOffsetY"] = m_originOffsetY;
    json["elementCount"] = m_elementCount;
    json["thumbnailPath"] = m_thumbnailPath;
    json["isDefault"] = m_isDefault;
    return json;
}

QString TemplateInfo::toJSON() const
{
    return QString::fromUtf8(QJsonDocument(toJsonObject()).toJson(QJsonDocument::Indented));
}

// Getters
QString TemplateInfo::templateName() const { return m_templateName; }
QString TemplateInfo::templateDescription() const { return m_templateDescription; }
QString TemplateInfo::templateCreationDate() const { return m_templateCreationDate; }
QString TemplateInfo::templateAuthor() const { return m_templateAuthor; }
int TemplateInfo::version() const { return m_version; }
int TemplateInfo::boundingBoxWidth() const { return m_boundingBoxWidth; }
int TemplateInfo::boundingBoxHeight() const { return m_boundingBoxHeight; }
int TemplateInfo::originOffsetX() const { return m_originOffsetX; }
int TemplateInfo::originOffsetY() const { return m_originOffsetY; }
int TemplateInfo::elementCount() const { return m_elementCount; }
QString TemplateInfo::thumbnailPath() const { return m_thumbnailPath; }
bool TemplateInfo::isDefault() const { return m_isDefault; }

// Setters
void TemplateInfo::setTemplateName(const QString &name)
{
    if (m_templateName != name) {
        m_templateName = name;
        emit templateNameChanged();
    }
}

void TemplateInfo::setTemplateDescription(const QString &description)
{
    if (m_templateDescription != description) {
        m_templateDescription = description;
        emit templateDescriptionChanged();
    }
}

void TemplateInfo::setTemplateCreationDate(const QString &date)
{
    if (m_templateCreationDate != date) {
        m_templateCreationDate = date;
        emit templateCreationDateChanged();
    }
}

void TemplateInfo::setTemplateAuthor(const QString &author)
{
    if (m_templateAuthor != author) {
        m_templateAuthor = author;
        emit templateAuthorChanged();
    }
}

void TemplateInfo::setVersion(int version)
{
    if (m_version != version) {
        m_version = version;
        emit versionChanged();
    }
}

void TemplateInfo::setBoundingBoxWidth(int width)
{
    if (m_boundingBoxWidth != width) {
        m_boundingBoxWidth = width;
        emit boundingBoxWidthChanged();
    }
}

void TemplateInfo::setBoundingBoxHeight(int height)
{
    if (m_boundingBoxHeight != height) {
        m_boundingBoxHeight = height;
        emit boundingBoxHeightChanged();
    }
}

void TemplateInfo::setOriginOffsetX(int offsetX)
{
    if (m_originOffsetX != offsetX) {
        m_originOffsetX = offsetX;
        emit originOffsetXChanged();
    }
}

void TemplateInfo::setOriginOffsetY(int offsetY)
{
    if (m_originOffsetY != offsetY) {
        m_originOffsetY = offsetY;
        emit originOffsetYChanged();
    }
}

void TemplateInfo::setElementCount(int count)
{
    if (m_elementCount != count) {
        m_elementCount = count;
        emit elementCountChanged();
    }
}

void TemplateInfo::setThumbnailPath(const QString &path)
{
    if (m_thumbnailPath != path) {
        m_thumbnailPath = path;
        emit thumbnailPathChanged();
    }
}

void TemplateInfo::setIsDefault(bool isDefault)
{
    if (m_isDefault != isDefault) {
        m_isDefault = isDefault;
        emit isDefaultChanged();
    }
}

