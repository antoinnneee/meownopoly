#include "ItemSnapable.h"
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include "game/case/CaseFactory.h"

ItemSnapable::ItemSnapable() {
    qDebug() << "New ItemSnapable created";
    m_uniqueId = QUuid::createUuid();
    m_caseData = new Case();
    m_tileType = DecorationTile;

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
    m_uniqueId = QUuid::createUuid();
}

ItemSnapable::ItemSnapable(DecorationParameter * decorationParameter, DisplayParameter * displayParameter, QObject *parent)
: QObject(parent)
{
    m_decorationParameter = decorationParameter;
    m_displayParameter = displayParameter;
    m_caseData = nullptr;
    m_uniqueId = QUuid::createUuid();
}

ItemSnapable::ItemSnapable(const QJsonObject &json, QObject *parent)
: QObject(parent)
{
    m_json = json;
    if (m_json.contains("caseData")) {
        m_caseData = CaseFactory::createCase(m_json["caseData"].toObject());
    }
    if (m_json.contains("displayParameter")) {
        m_displayParameter = new DisplayParameter(m_json["displayParameter"].toObject(), this);
    }
    if (m_json.contains("decorationParameter")) {
        m_decorationParameter = new DecorationParameter(m_json["decorationParameter"].toObject(), this);
    }
    m_uniqueId = QUuid(m_json["uniqueId"].toString());
    m_tileType = TileType(m_json["tileType"].toInt());
}

ItemSnapable::ItemSnapable(Case::CaseType caseType, QObject *parent)
    : QObject(parent)
{
    m_caseData = CaseFactory::createCase(caseType);
    m_displayParameter = new DisplayParameter();
    m_decorationParameter = new DecorationParameter();
    m_uniqueId = QUuid::createUuid();
    m_tileType = CaseTile;
}

// ItemSnapable::ItemSnapable(Case::CaseType caseType, QObject *parent)
//     : QObject(parent)
// {
//     m_caseData = CaseFactory::createCase(caseType);
//     m_displayParameter = new DisplayParameter();
//     m_decorationParameter = new DecorationParameter();
//     m_uniqueId = QUuid::createUuid();
//     m_tileType = CaseTile;
// }

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
QString ItemSnapable::toJSON()
{
    QString json;
    json += "{\n";
    json += "    \"uniqueId\": \"" + m_uniqueId.toString() + "\",\n";
    json += "    \"tileType\": " + QString::number(m_tileType) + ",\n";
    if (m_caseData != nullptr) {
        json += "    \"caseData\": " + m_caseData->toJSON() + ",\n";
    }
    if (m_decorationParameter != nullptr) {
        json += "    \"decorationParameter\": " + m_decorationParameter->toJSON() + ",\n";
    }
    json += "    \"displayParameter\": " + m_displayParameter->toJSON() + ",\n";
    json += "    \"next\": [ ";
    for (int i = 0; i < next.size(); i++) {
        json += "\"" + next.at(i)->uniqueId().toString() + "\"" + (i < next.size() - 1 ? ", " : "");
    }
    json += "],\n";
    json += "    \"prev\": [ ";
    for (int i = 0; i < prev.size(); i++) {
        json += "\"" + prev.at(i)->uniqueId().toString() + "\"" + (i < prev.size() - 1 ? ", " : "");
    }
    json += "]\n";
    json += "}";
    return json;
}



void ItemSnapable::print()
{
    qDebug().noquote() << "ItemSnapable: " << toJSON();
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

void ItemSnapable::changeCaseDataType(Case::CaseType caseType)
{
    if (m_caseData) {
        m_caseData->deleteLater();
    }
    m_caseData = CaseFactory::createCase(caseType);
    emit caseDataChanged();
}


// ---- CHAINED LIST MANIPULATION ----


void ItemSnapable::addNext(ItemSnapable *newNext)
{
    next.append(newNext);
}

bool ItemSnapable::removeNext(ItemSnapable *caseToRemove)
{
    int index = next.indexOf(caseToRemove);
    if (index != -1) {
        next.removeAt(index);
        return true;
    }
    return false;
}

bool ItemSnapable::removeNextAt(int index)
{
    if (index >= 0 && index < next.size()) {
        next.removeAt(index);
        return true;
    }
    return false;
}

void ItemSnapable::addPrev(ItemSnapable *newPrev)
{
    prev.append(newPrev);
}

bool ItemSnapable::removePrev(ItemSnapable *caseToRemove)
{
    int index = prev.indexOf(caseToRemove);
    if (index != -1) {
        prev.removeAt(index);
        return true;
    }
    return false;
}

bool ItemSnapable::removePrevAt(int index)
{
    if (index >= 0 && index < prev.size()) {
        prev.removeAt(index);
        return true;
    }
    return false;
}

ItemSnapable::TileType ItemSnapable::tileType() const
{
    return m_tileType;
}

void ItemSnapable::setTileType(const ItemSnapable::TileType &newTileType)
{
    if (m_tileType == newTileType)
        return;
    m_tileType = newTileType;
    emit tileTypeChanged();
}

void ItemSnapable::copyFrom(ItemSnapable* source)
{
    if (!source) return;
    
    // Copier le type de tile
    setTileType(source->tileType());
    
    // Copier les display parameters
    if (source->displayParameter()) {
        m_displayParameter->setGridRelativePositionX(source->displayParameter()->gridRelativePositionX());
        m_displayParameter->setGridRelativePositionY(source->displayParameter()->gridRelativePositionY());
        m_displayParameter->setUnitSizeWidth(source->displayParameter()->unitSizeWidth());
        m_displayParameter->setUnitSizeHeight(source->displayParameter()->unitSizeHeight());
        m_displayParameter->setZLayer(source->displayParameter()->zLayer());
        m_displayParameter->setZOrder(source->displayParameter()->zOrder());
        emit displayParameterChanged();
    }
    
    // Copier les case data si c'est un CaseTile
    if (source->tileType() == CaseTile && source->caseData()) {
        setCaseData(source->caseData());
    }
    
    // Copier les decoration parameters si c'est une DecorationTile
    if (source->tileType() == DecorationTile && source->decorationParameter()) {
        m_decorationParameter->setDecorationCategory(source->decorationParameter()->decorationCategory());
        m_decorationParameter->setDecorationType(source->decorationParameter()->decorationType());
        m_decorationParameter->setDecorationId(source->decorationParameter()->decorationId());
        emit decorationParameterChanged();
    }
    
    // Copier l'UUID
    setUniqueId(source->uniqueId());

    
    qDebug() << "ItemSnapable data copied from source";
}
