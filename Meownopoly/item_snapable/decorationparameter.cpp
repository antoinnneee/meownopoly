#include "decorationparameter.h"
#include <QJsonObject>

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

QString DecorationParameter::toJSON()
{
    QString json;
    json += "{\n";
    json += "    \"decorationCategory\": \"" + m_decorationCategory + "\",\n";
    json += "    \"decorationType\": \"" + m_decorationType + "\",\n";
    json += "    \"decorationId\": \"" + m_decorationId + "\"\n";
    json += "}";
    return json;
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

