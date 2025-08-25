#include "ItemSnapable.h"

ItemSnapable::ItemSnapable() {}

void ItemSnapable::registerQml()
{
    qmlRegisterType<ItemSnapable>("ItemSnapable", 1, 0, "ItemSnapable"); // Register ItemSnapable class

}

ItemSnapable::ItemSnapable(Case * caseData, DisplayParameter * displayParameter, QObject *parent)
: QObject(parent)
{
    m_caseData = caseData;
    m_displayParameter = displayParameter;
}

DisplayParameter::DisplayParameter(int unitSizeWidth, int unitSizeHeight, int gridRelativePosition, int gridRelativePositionY, int zLayer, QObject *parent)
: QObject(parent)
{
    m_unitSizeWidth = unitSizeWidth;
    m_unitSizeHeight = unitSizeHeight;
    m_gridRelativePosition = gridRelativePosition;
    m_gridRelativePositionY = gridRelativePositionY;
    m_zLayer = zLayer;
}

DisplayParameter::DisplayParameter(const QJsonDocument &json, QObject *parent): QObject(parent)
{
    m_json = json;
    m_unitSizeWidth = m_json["unitSizeWidth"].toInt();
    m_unitSizeHeight = m_json["unitSizeHeight"].toInt();
    m_gridRelativePosition = m_json["gridRelativePosition"].toInt();
    m_gridRelativePositionY = m_json["gridRelativePositionY"].toInt();
    m_zLayer = m_json["zLayer"].toInt();
}



ItemSnapable::ItemSnapable(const QJsonDocument &json)
{
    m_json = json;
    m_caseData = new Case(m_json["caseData"]);
    m_displayParameter = new DisplayParameter(m_json["displayParameter"], this);
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
    json += "    \"gridRelativePosition\": " + QString::number(m_gridRelativePosition) + ",\n";
    json += "    \"gridRelativePositionY\": " + QString::number(m_gridRelativePositionY) + ",\n";
    json += "    \"zLayer\": " + QString::number(m_zLayer) + "\n";
    json += "}";
    return json;
}

