#include "Displayparameter.h"


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

int DisplayParameter::unitSizeWidth() const
{
    return m_unitSizeWidth;
}

void DisplayParameter::setUnitSizeWidth(int unitSizeWidth)
{
    m_unitSizeWidth = unitSizeWidth;
    emit unitSizeWidthChanged();
}

int DisplayParameter::unitSizeHeight() const
{
    return m_unitSizeHeight;
}

void DisplayParameter::setUnitSizeHeight(int unitSizeHeight)
{
    m_unitSizeHeight = unitSizeHeight;
    emit unitSizeHeightChanged();
}

int DisplayParameter::gridRelativePositionX() const
{
    return m_gridRelativePositionX;
}

void DisplayParameter::setGridRelativePositionX(int gridRelativePositionX)
{
    m_gridRelativePositionX = gridRelativePositionX;
    emit gridRelativePositionXChanged();
}

int DisplayParameter::gridRelativePositionY() const
{
    return m_gridRelativePositionY;
}

void DisplayParameter::setGridRelativePositionY(int gridRelativePositionY)
{
    m_gridRelativePositionY = gridRelativePositionY;
    emit gridRelativePositionYChanged();
}

int DisplayParameter::zLayer() const
{
    return m_zLayer;
}

void DisplayParameter::setZLayer(int zLayer)
{
    m_zLayer = zLayer;
    emit zLayerChanged();
}

