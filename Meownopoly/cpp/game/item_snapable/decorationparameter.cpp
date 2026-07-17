#include "decorationparameter.h"
#include <QJsonObject>
#include <QJsonDocument>
#include <QFile>
#include "tools/logger.h"
#include "assetManager/asset_manager.h"


// bool DecorationParameter::operator==(const DecorationParameter &other) const {
//     return m_decorationCategory == other.m_decorationCategory
//            && m_decorationType    == other.m_decorationType
//            && m_decorationId      == other.m_decorationId;
// }

DecorationParameter::DecorationParameter(QObject *parent)
    : QObject{parent}
{
    m_decorationCategory = "decoration";
    m_decorationType = "grass";
    m_decorationId = "0";
}

DecorationParameter::DecorationParameter(const QJsonObject &json, QObject *parent): QObject(parent)
{
    m_decorationCategory = json["decorationCategory"].toString();
    m_decorationType = json["decorationType"].toString();
    m_decorationId = json["decorationId"].toString();
}

QString DecorationParameter::getAnimePath(QString imagePath)
{
    QString animePath = AssetManager::instance()->getAnimatedGifPath(m_decorationCategory, m_decorationType, m_decorationId);
    qDebug() << "animePath " << animePath;
    if (QFile::exists(animePath.remove("file:///"))){
        return animePath.prepend("file:///");
    }
    else {
        Logger::instance()->error(QString("Error, no animated gif found for : ") + animePath, "DECORATION_PARAMETER");
        return imagePath;
    }
}

void DecorationParameter::applyJson(const QJsonObject &json)
{
    setDecorationCategory(json["decorationCategory"].toString());
    setDecorationType(json["decorationType"].toString());
    setDecorationId(json["decorationId"].toString());
}

QJsonObject DecorationParameter::toJsonObject() const
{
    return QJsonObject{
        { "decorationCategory", m_decorationCategory },
        { "decorationType",     m_decorationType },
        { "decorationId",       m_decorationId },
    };
}

QString DecorationParameter::toJSON()
{
    return QString::fromUtf8(
        QJsonDocument(toJsonObject()).toJson(QJsonDocument::Compact));
}

QString DecorationParameter::decorationCategory() const
{
    return m_decorationCategory;
}

void DecorationParameter::setDecorationCategory(const QString &decorationCategory)
{
    m_decorationCategory = decorationCategory;
    emit decorationCategoryChanged();
}

QString DecorationParameter::decorationType() const
{
    return m_decorationType;
}

void DecorationParameter::setDecorationType(const QString &decorationType)
{
    m_decorationType = decorationType;
    emit decorationTypeChanged();
}

QString DecorationParameter::decorationId() const
{
    return m_decorationId;
}

void DecorationParameter::setDecorationId(const QString &decorationId)
{
    m_decorationId = decorationId;
    emit decorationIdChanged();
}

