#include "displayparameter.h"


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

