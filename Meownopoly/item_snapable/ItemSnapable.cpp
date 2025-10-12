#include "ItemSnapable.h"
#include <QQmlApplicationEngine>
#include <QQmlEngine>

// Include all case types
#include "../case/CaseRestArea.h"
#include "../case/CaseCardBoardBox.h"
#include "../case/CaseCatNip.h"
#include "../case/CaseJail.h"
#include "../case/CaseToJail.h"
#include "../case/CaseCatDoor.h"
#include "../case/CaseFreeNap.h"
#include "../case/CaseCatDevice.h"
#include "../case/CaseKibbleDispenser.h"

ItemSnapable::ItemSnapable() {
    qDebug() << "New ItemSnapable created";
    m_uniqueId = QUuid::createUuid();

}

void ItemSnapable::registerQml()
{
    qmlRegisterType<ItemSnapable>("ItemSnapable", 1, 0, "ItemSnapable"); // Register ItemSnapable class
    qmlRegisterType<TileType>("TileType", 1, 0, "TileType");
    qmlRegisterType<DisplayParameter>("DisplayParameter", 1, 0, "DisplayParameter"); // Register DisplayParameter class
    qmlRegisterType<DecorationParameter>("DecorationParameter", 1, 0, "DecorationParameter"); // Register DecorationParameter class
}

ItemSnapable::ItemSnapable(Case * caseData, DisplayParameter * displayParameter, QObject *parent)
: QObject(parent)
{
    m_caseData = caseData;
    m_displayParameter = displayParameter;
}

ItemSnapable::ItemSnapable(DecorationParameter * decorationParameter, DisplayParameter * displayParameter, QObject *parent)
: QObject(parent)
{
    m_decorationParameter = decorationParameter;
    m_displayParameter = displayParameter;
    m_caseData = nullptr;
}

ItemSnapable::ItemSnapable(const QJsonObject &json, QObject *parent)
: QObject(parent)
{
    m_json = json;
    if (m_json.contains("caseData")) {
        m_caseData = getNewCaseFromJSON(m_json["caseData"].toObject(), this);
    }
    if (m_json.contains("displayParameter")) {
        m_displayParameter = new DisplayParameter(m_json["displayParameter"].toObject(), this);
    }
    if (m_json.contains("decorationParameter")) {
        m_decorationParameter = new DecorationParameter(m_json["decorationParameter"].toObject(), this);
    }
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
    qDebug() << "set display settings";
    if (m_displayParameter)
        delete m_displayParameter;
    m_displayParameter = displayParameter; emit displayParameterChanged();
}

DecorationParameter *ItemSnapable::decorationParameter() const {
    return m_decorationParameter;
}

void ItemSnapable::setDecorationParameter(DecorationParameter * decorationParameter) {
    if (m_decorationParameter)
        delete m_decorationParameter;
    m_decorationParameter = decorationParameter; emit decorationParameterChanged();
}

Case* ItemSnapable::getNewCaseFromJSON(const QJsonObject &caseJson, QObject *parent)
{
    Case* newCase = nullptr;
    
    // Extract type from JSON and convert to enum
    Case::CaseType type = Case::intToCaseType(caseJson["type"].toInt());
    switch (type) {
    case Case::CS_RestArea:
        newCase = new CaseRestArea(caseJson);
        break;
    case Case::CS_KibbleDispenser:
        newCase = new CaseKibbleDispenser(caseJson); // Default kibble amount
        break;
    case Case::CS_CardBoardBox:
        newCase = new CaseCardBoardBox(caseJson);
        break;
    case Case::CS_CatNip:
        newCase = new CaseCatNip(caseJson);
        break;
    case Case::CS_Jail:
        newCase = new CaseJail(caseJson);
        break;
    case Case::CS_ToJail:
        newCase = new CaseToJail(caseJson);
        break;
    case Case::CS_CatDoor:
        newCase = new CaseCatDoor(caseJson);
        break;
    case Case::CS_FreeNap:
        newCase = new CaseFreeNap(caseJson);
        break;
    case Case::CS_Device:
        newCase = new CaseCatDevice(caseJson);
        break;
    case Case::CS_Taxe:
        newCase = new CaseKibbleDispenser(caseJson); // Tax case as KibbleDispenser
        break;
    default:
        qDebug() << "Unknown case type:" << type << "creating base Case";
        newCase = new Case(caseJson, parent);
        break;
    }

    return newCase;
}

QString ItemSnapable::toJSON()
{
    QString json;
    json += "{\n";
    if (m_caseData != nullptr) {
        json += "    \"caseData\": " + m_caseData->toJSON() + ",\n";
    }
    if (m_decorationParameter != nullptr) {
        json += "    \"decorationParameter\": " + m_decorationParameter->toJSON() + ",\n";
    }
    json += "    \"displayParameter\": " + m_displayParameter->toJSON() + "\n";

    json += "}";
    return json;
}



void ItemSnapable::print()
{
    qDebug() << "ItemSnapable: " << m_caseData->toJSON() << " " << m_displayParameter->toJSON();
}

QUuid ItemSnapable::uniqueId() const
{
    return m_uniqueId;
}

void ItemSnapable::setUniqueId(const QUuid &newUniqueId)
{
    if (m_uniqueId == newUniqueId)
        return;
    m_uniqueId = newUniqueId;
    emit uniqueIdChanged();
}
