#include "ItemSnapable.h"
#include <QQmlApplicationEngine>
#include <QQmlEngine>

ItemSnapable::ItemSnapable() {
    qDebug() << "New ItemSnapable created";
}

void ItemSnapable::registerQml()
{
    qmlRegisterType<ItemSnapable>("ItemSnapable", 1, 0, "ItemSnapable"); // Register ItemSnapable class
    qmlRegisterType<TileType>("TileType", 1, 0, "TileType"); // Register ItemSnapable class
    qmlRegisterType<DisplayParameter>("DisplayParameter", 1, 0, "DisplayParameter"); // Register DisplayParameter class
}

ItemSnapable::ItemSnapable(Case * caseData, DisplayParameter * displayParameter, QObject *parent)
: QObject(parent)
{
    m_caseData = caseData;
    m_displayParameter = displayParameter;
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

Case *ItemSnapable::caseData() const {
    return m_caseData;
}

void ItemSnapable::setCaseData(Case * caseData){
    m_caseData = caseData; emit caseDataChanged();
}

DisplayParameter *ItemSnapable::displayParameter() const {
    return m_displayParameter;
}

void ItemSnapable::setDisplayParameter(DisplayParameter * displayParameter) {
    m_displayParameter = displayParameter; emit displayParameterChanged();
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



