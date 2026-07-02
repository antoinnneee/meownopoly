#include "ItemSnapable.h"
#include "ZoneParameter.h"
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include "game/case/CaseFactory.h"


ItemSnapable::ItemSnapable() {
    m_uniqueId = QUuid::createUuid();
    m_caseData = new Case();
    m_tileType = DecorationTile;
    commitCurrentState();
}

ItemSnapable::~ItemSnapable() {
    if (m_caseData)
        delete m_caseData;
    if (m_displayParameter)
        delete m_displayParameter;
    if (m_decorationParameter)
        delete m_decorationParameter;
    if (m_zoneParameter)
        delete m_zoneParameter;
    if (m_npcParameter)
        delete m_npcParameter;
    if (m_enemyParameter)
        delete m_enemyParameter;
}

void ItemSnapable::registerQml()
{
    qmlRegisterType<ItemSnapable>("ItemSnapable", 1, 0, "ItemSnapable"); // Register ItemSnapable class
    qmlRegisterType<TileType>("TileType", 1, 0, "TileType");
    qmlRegisterType<DisplayParameter>("DisplayParameter", 1, 0, "DisplayParameter"); // Register DisplayParameter class
    qmlRegisterType<DecorationParameter>("DecorationParameter", 1, 0, "DecorationParameter"); // Register DecorationParameter class
    qmlRegisterType<ZoneParameter>("ZoneParameter", 1, 0, "ZoneParameter"); // Register ZoneParameter class
    qmlRegisterType<NPCParameter>("NPCParameter", 1, 0, "NPCParameter"); // Register NPCParameter class
    qmlRegisterType<EnemyParameter>("EnemyParameter", 1, 0, "EnemyParameter"); // Register EnemyParameter class
}

ItemSnapable::ItemSnapable(Case * caseData, DisplayParameter * displayParameter, QObject *parent)
    : QObject(parent)
{
    m_caseData = caseData;
    m_displayParameter = displayParameter;
    m_uniqueId = QUuid::createUuid();
    commitCurrentState();
}

ItemSnapable::ItemSnapable(DecorationParameter * decorationParameter, DisplayParameter * displayParameter, QObject *parent)
    : QObject(parent)
{
    m_decorationParameter = decorationParameter;
    m_displayParameter = displayParameter;
    m_caseData = nullptr;
    m_uniqueId = QUuid::createUuid();
    commitCurrentState();
}

ItemSnapable::ItemSnapable(const QJsonObject &json, QObject *parent)
    : QObject(parent)
{
    m_json = json;

    // Valider et parser le tileType
    int rawTileType = m_json["tileType"].toInt(-1);
    if (rawTileType < CaseTile || rawTileType > EnemyTile) {
        qWarning() << "ITEM_SNAPABLE: tileType invalide:" << rawTileType
                    << "pour la tile" << m_json["uniqueId"].toString() << "- défaut à DecorationTile";
        m_tileType = DecorationTile;
    } else {
        m_tileType = TileType(rawTileType);
    }

    // Valider et parser l'UUID
    QUuid parsedId = QUuid(m_json["uniqueId"].toString());
    if (parsedId.isNull()) {
        qWarning() << "ITEM_SNAPABLE: uniqueId invalide ou manquant - génération d'un nouvel UUID";
        m_uniqueId = QUuid::createUuid();
    } else {
        m_uniqueId = parsedId;
    }

    // Parser les sous-objets avec validation du type JSON
    if (m_json.contains("caseData")) {
        if (m_json["caseData"].isObject()) {
            m_caseData = CaseFactory::createCase(m_json["caseData"].toObject());
            if (!m_caseData && m_tileType == CaseTile) {
                qWarning() << "ITEM_SNAPABLE: CaseFactory a retourné null pour CaseTile" << m_uniqueId.toString();
            }
        } else {
            qWarning() << "ITEM_SNAPABLE: 'caseData' n'est pas un objet JSON pour tile" << m_uniqueId.toString();
        }
    } else if (m_tileType == CaseTile) {
        qWarning() << "ITEM_SNAPABLE: CaseTile sans 'caseData' pour tile" << m_uniqueId.toString();
    }

    if (m_json.contains("displayParameter")) {
        if (m_json["displayParameter"].isObject()) {
            m_displayParameter = new DisplayParameter(m_json["displayParameter"].toObject(), this);
        } else {
            qWarning() << "ITEM_SNAPABLE: 'displayParameter' invalide pour tile" << m_uniqueId.toString();
        }
    }
    if (m_json.contains("decorationParameter")) {
        if (m_json["decorationParameter"].isObject()) {
            m_decorationParameter = new DecorationParameter(m_json["decorationParameter"].toObject(), this);
        } else {
            qWarning() << "ITEM_SNAPABLE: 'decorationParameter' invalide pour tile" << m_uniqueId.toString();
        }
    }
    if (m_json.contains("zoneParameter")) {
        if (m_json["zoneParameter"].isObject()) {
            m_zoneParameter = new ZoneParameter(m_json["zoneParameter"].toObject(), this);
        } else {
            qWarning() << "ITEM_SNAPABLE: 'zoneParameter' invalide pour tile" << m_uniqueId.toString();
        }
    }
    if (m_json.contains("npcParameter")) {
        if (m_json["npcParameter"].isObject()) {
            m_npcParameter = new NPCParameter(m_json["npcParameter"].toObject(), this);
        } else {
            qWarning() << "ITEM_SNAPABLE: 'npcParameter' invalide pour tile" << m_uniqueId.toString();
        }
    }
    if (m_json.contains("enemyParameter")) {
        if (m_json["enemyParameter"].isObject()) {
            m_enemyParameter = new EnemyParameter(m_json["enemyParameter"].toObject(), this);
        } else {
            qWarning() << "ITEM_SNAPABLE: 'enemyParameter' invalide pour tile" << m_uniqueId.toString();
        }
    }
    commitCurrentState();
}

ItemSnapable::ItemSnapable(Case::CaseType caseType, QObject *parent)
    : QObject(parent)
{
    m_caseData = CaseFactory::createCase(caseType);
    m_displayParameter = new DisplayParameter();
    m_decorationParameter = new DecorationParameter();
    m_uniqueId = QUuid::createUuid();
    m_tileType = CaseTile;
    commitCurrentState();
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

ZoneParameter *ItemSnapable::zoneParameter() const {
    return m_zoneParameter;
}

void ItemSnapable::setZoneParameter(ZoneParameter * zoneParameter) {
    if (m_zoneParameter)
        delete m_zoneParameter;
    m_zoneParameter = zoneParameter; emit zoneParameterChanged();
}

NPCParameter *ItemSnapable::npcParameter() const {
    return m_npcParameter;
}

void ItemSnapable::setNpcParameter(NPCParameter * npcParameter) {
    if (m_npcParameter)
        delete m_npcParameter;
    m_npcParameter = npcParameter; emit npcParameterChanged();
}

EnemyParameter *ItemSnapable::enemyParameter() const {
    return m_enemyParameter;
}

void ItemSnapable::setEnemyParameter(EnemyParameter * enemyParameter) {
    if (m_enemyParameter)
        delete m_enemyParameter;
    m_enemyParameter = enemyParameter; emit enemyParameterChanged();
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
    if (m_zoneParameter != nullptr && m_tileType == PhysicZoneTile) {
        json += "    \"zoneParameter\": " + m_zoneParameter->toJSON() + ",\n";
    }
    if (m_npcParameter != nullptr && m_tileType == NPCTile) {
        // toJSON() de NPCParameter est déjà un objet JSON valide (échappement
        // via QJsonDocument), la concat reste sûre ici.
        json += "    \"npcParameter\": " + m_npcParameter->toJSON() + ",\n";
    }
    if (m_enemyParameter != nullptr && m_tileType == EnemyTile) {
        // toJSON() de EnemyParameter est déjà un objet JSON valide (échappement
        // via QJsonDocument), la concat reste sûre ici.
        json += "    \"enemyParameter\": " + m_enemyParameter->toJSON() + ",\n";
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

void ItemSnapable::applyJson(const QJsonObject &json)
{
    // tileType
    if (json.contains("tileType"))
        setTileType(TileType(json["tileType"].toInt()));

    // caseData — clone via factory, libère l'ancien
    if (json.contains("caseData")) {
        QJsonObject cj = json["caseData"].toObject();
        Case *newCase = CaseFactory::createCase(cj);
        if (m_caseData)
            m_caseData->deleteLater();
        m_caseData = newCase;
        emit caseDataChanged();
    }

    if (json.contains("displayParameter"))
        m_displayParameter->applyJson(json["displayParameter"].toObject());

    if (json.contains("decorationParameter"))
        m_decorationParameter->applyJson(json["decorationParameter"].toObject());

    if (json.contains("zoneParameter"))
        m_zoneParameter->applyJson(json["zoneParameter"].toObject());

    if (json.contains("npcParameter"))
        m_npcParameter->applyJson(json["npcParameter"].toObject());

    if (json.contains("enemyParameter"))
        m_enemyParameter->applyJson(json["enemyParameter"].toObject());

    // NB: uniqueId jamais override (identité de la tile) ;
    // next/prev gérés par Map::rewireLinks après applyJson.
    Q_ASSERT(!json.contains("uniqueId") ||
             QUuid(json["uniqueId"].toString()) == m_uniqueId);
}

void ItemSnapable::copyFrom(ItemSnapable* source)
{
    if (!source) return;
    QJsonObject j = QJsonDocument::fromJson(source->toJSON().toUtf8()).object();
    applyJson(j);
}
