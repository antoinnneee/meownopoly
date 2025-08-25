#include "ItemSnapable.h"
#include <QQmlApplicationEngine>
#include <QQmlEngine>

ItemSnapable::ItemSnapable() {}

void ItemSnapable::registerQml()
{
    qmlRegisterType<ItemSnapable>("ItemSnapable", 1, 0, "ItemSnapable"); // Register ItemSnapable class
    qmlRegisterType<DisplayParameter>("DisplayParameter", 1, 0, "DisplayParameter"); // Register DisplayParameter class
}

ItemSnapable::ItemSnapable(Case * caseData, DisplayParameter * displayParameter, QObject *parent)
: QObject(parent)
{
    m_caseData = caseData;
    m_displayParameter = displayParameter;
}

DisplayParameter::DisplayParameter(int unitSizeWidth, int unitSizeHeight, int gridRelativePositionX, int gridRelativePositionY, int zLayer, QObject *parent)
: QObject(parent)
{
    m_unitSizeWidth = unitSizeWidth;
    m_unitSizeHeight = unitSizeHeight;
    m_gridRelativePositionX = gridRelativePositionX;
    m_gridRelativePositionY = gridRelativePositionY;
    m_zLayer = zLayer;
}

DisplayParameter::DisplayParameter(const QJsonObject &json, QObject *parent): QObject(parent)
{
    m_unitSizeWidth = json["unitSizeWidth"].toInt();
    m_unitSizeHeight = json["unitSizeHeight"].toInt();
    m_gridRelativePositionX = json["gridRelativePositionX"].toInt();
    m_gridRelativePositionY = json["gridRelativePositionY"].toInt();
    m_zLayer = json["zLayer"].toInt();
}



ItemSnapable::ItemSnapable(const QJsonDocument &json, QObject *parent)
: QObject(parent)
{
    m_json = json.object();
    m_caseData = new Case(m_json["caseData"].toObject(), this);
    m_displayParameter = new DisplayParameter(m_json["displayParameter"].toObject(), this);
    emit caseDataChanged();
    emit displayParameterChanged();
}

QString ItemSnapable::toJSON()
{
    QString json;
    json += "{\n";
    json += "    \"caseData\": " + m_caseData->toJSON() + ",\n";
    json += "    \"displayParameter\": " + m_displayParameter->toJSON() + "\n";
    json += "}";
    return json;
}

QString DisplayParameter::toJSON()
{
    QString json;
    json += "{\n";
    json += "    \"unitSizeWidth\": " + QString::number(m_unitSizeWidth) + ",\n";
    json += "    \"unitSizeHeight\": " + QString::number(m_unitSizeHeight) + ",\n";
    json += "    \"gridRelativePositionX\": " + QString::number(m_gridRelativePositionX) + ",\n";
    json += "    \"gridRelativePositionY\": " + QString::number(m_gridRelativePositionY) + ",\n";
    json += "    \"zLayer\": " + QString::number(m_zLayer) + "\n";
    json += "}";
    return json;
}

