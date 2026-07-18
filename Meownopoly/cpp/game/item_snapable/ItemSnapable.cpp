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
    if (m_physicalObjectParameter)
        delete m_physicalObjectParameter;
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
    qmlRegisterType<PhysicalObjectParameter>("PhysicalObjectParameter", 1, 0, "PhysicalObjectParameter");
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
    if (rawTileType < CaseTile || rawTileType > PhysicalObjectTile) {
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
    if (m_json.contains("physicalObjectParameter")) {
        if (m_json["physicalObjectParameter"].isObject()) {
            m_physicalObjectParameter = new PhysicalObjectParameter(m_json["physicalObjectParameter"].toObject(), this);
        } else {
            qWarning() << "ITEM_SNAPABLE: 'physicalObjectParameter' invalide pour tile" << m_uniqueId.toString();
        }
    }

    // Espace mémoire (doc v3/05 Étape A). Aucun schéma de clés imposé : le blob
    // est chargé tel quel depuis le disque. Le QML génératif référencé ne doit
    // jamais être instancié sans le sandbox (doc 04) — le blob n'est pas de
    // confiance.
    if (m_json.contains("memory")) {
        if (m_json["memory"].isObject()) {
            m_userMemory = m_json["memory"].toObject().toVariantMap();
        } else {
            qWarning() << "ITEM_SNAPABLE: 'memory' n'est pas un objet JSON pour tile" << m_uniqueId.toString();
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

PhysicalObjectParameter *ItemSnapable::physicalObjectParameter() const {
    return m_physicalObjectParameter;
}

void ItemSnapable::setPhysicalObjectParameter(PhysicalObjectParameter * physicalObjectParameter) {
    if (m_physicalObjectParameter)
        delete m_physicalObjectParameter;
    m_physicalObjectParameter = physicalObjectParameter; emit physicalObjectParameterChanged();
}

QString ItemSnapable::toJSON()
{
    // R4 (plan V3 P0-2) : sérialisation intégralement via QJsonObject /
    // QJsonDocument. L'ancienne concaténation manuelle de chaînes cassait le
    // round-trip fromJson(toJSON()) dès qu'un champ texte libre (zoneName,
    // rewardItemName, dialogueLines…) contenait un guillemet, un backslash ou
    // un saut de ligne. Chaque sous-paramètre expose maintenant toJsonObject().
    QJsonObject root;
    root["uniqueId"] = m_uniqueId.toString();
    root["tileType"] = int(m_tileType);

    if (m_caseData != nullptr) {
        // Case (hors périmètre P0-2) sérialise encore en chaîne : on la reparse
        // pour l'insérer comme objet. En cas d'échec, on préserve la donnée en
        // journalisant plutôt que de produire un tile globalement invalide.
        QJsonParseError caseErr;
        const QJsonDocument caseDoc =
            QJsonDocument::fromJson(m_caseData->toJSON().toUtf8(), &caseErr);
        if (caseErr.error == QJsonParseError::NoError && caseDoc.isObject()) {
            root["caseData"] = caseDoc.object();
        } else {
            qWarning() << "ITEM_SNAPABLE: caseData->toJSON() illisible pour tile"
                       << m_uniqueId.toString() << "-" << caseErr.errorString();
        }
    }
    if (m_decorationParameter != nullptr) {
        root["decorationParameter"] = m_decorationParameter->toJsonObject();
    }
    if (m_zoneParameter != nullptr && m_tileType == PhysicZoneTile) {
        root["zoneParameter"] = m_zoneParameter->toJsonObject();
    }
    if (m_npcParameter != nullptr && m_tileType == NPCTile) {
        root["npcParameter"] = m_npcParameter->toJsonObject();
    }
    if (m_enemyParameter != nullptr && m_tileType == EnemyTile) {
        root["enemyParameter"] = m_enemyParameter->toJsonObject();
    }
    if (m_physicalObjectParameter != nullptr && m_tileType == PhysicalObjectTile) {
        root["physicalObjectParameter"] = m_physicalObjectParameter->toJsonObject();
    }
    if (m_displayParameter != nullptr) {
        root["displayParameter"] = m_displayParameter->toJsonObject();
    }

    // Espace mémoire (doc v3/05 Étape A). Piège n°1 : sérialiser via
    // QJsonObject::fromVariantMap plutôt que par concaténation manuelle — sinon
    // une valeur texte avec guillemets/backslash/newline casse l'échappement.
    // N'insérer que si non vide pour garder un round-trip stable sur les tiles
    // sans mémoire. Le blob voyage gratuitement dans EditDelta.before/after
    // (persistance disque + inverse de configuration undoable).
    if (!m_userMemory.isEmpty()) {
        root["memory"] = QJsonObject::fromVariantMap(m_userMemory);
    }

    // Références d'artefacts (doc v3 D16/D36, plan T4-1/M8). N'insérer que si non
    // vide pour préserver un round-trip stable sur les tuiles sans artefact. On
    // ne sérialise que les 3 champs de la référence — jamais le contenu, qui vit
    // dans le store par hash (ArtifactStore).
    if (!m_artifactRefs.isEmpty()) {
        QJsonArray artifactsArray;
        for (const QVariant &v : std::as_const(m_artifactRefs)) {
            const QVariantMap ref = v.toMap();
            QJsonObject entry;
            entry["instanceId"] = ref.value("instanceId").toString();
            entry["contentHash"] = ref.value("contentHash").toString();
            entry["manifestVersion"] = ref.value("manifestVersion").toInt();
            artifactsArray.append(entry);
        }
        root["artifacts"] = artifactsArray;
    }

    QJsonArray nextArray;
    for (ItemSnapable *n : std::as_const(next)) {
        if (n) nextArray.append(n->uniqueId().toString());
    }
    root["next"] = nextArray;

    QJsonArray prevArray;
    for (ItemSnapable *p : std::as_const(prev)) {
        if (p) prevArray.append(p->uniqueId().toString());
    }
    root["prev"] = prevArray;

    return QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact));
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

void ItemSnapable::setUserMemory(const QVariantMap &memory)
{
    // Garde anti-boucle : pas de ré-émission si la map est identique. QVariant
    // supporte operator== pour les primitives, listes et maps imbriquées.
    if (m_userMemory == memory)
        return;
    m_userMemory = memory;
    ++m_memoryVersion;
    emit userMemoryChanged();
}

void ItemSnapable::setMemoryValue(const QString &key, const QVariant &value)
{
    // Garde anti-boucle (D15) : pas d'émission si la valeur n'a pas réellement
    // changé — c'est ce qui casse la cascade écriture→signal→ré-écriture d'une
    // règle qui écrirait la même valeur en réaction.
    if (m_userMemory.contains(key) && m_userMemory.value(key) == value)
        return;

    // Garde de réentrance : plafonne les cascades légitimes mais non
    // convergentes (règle A écrit X → règle B écrit Y → règle A écrit X…).
    if (m_memoryWriteDepth >= kMaxMemoryCascadeDepth) {
        qWarning() << "ITEM_SNAPABLE: cascade mémoire trop profonde ("
                   << m_memoryWriteDepth << ") sur la clé" << key
                   << "pour la tile" << m_uniqueId.toString()
                   << "- écriture ignorée pour éviter la boucle";
        return;
    }

    ++m_memoryWriteDepth;
    m_userMemory.insert(key, value);
    ++m_memoryVersion;
    // Réveil ciblé d'abord (les abonnés fins), puis réveil global (bindings QML
    // sur la Q_PROPERTY userMemory). Le namespace reste vide à l'Étape A : la
    // distinction config/state est portée par la convention IA (doc v3/05 §5),
    // pas encore par le cœur.
    emit memoryValueChanged(QString(), key, value, int(m_memoryVersion));
    emit userMemoryChanged();
    --m_memoryWriteDepth;
}

void ItemSnapable::setArtifactRefs(const QVariantList &refs)
{
    // Garde anti-boucle (même motif que setUserMemory) : pas de ré-émission si
    // la liste est identique.
    if (m_artifactRefs == refs)
        return;
    m_artifactRefs = refs;
    emit artifactRefsChanged();
}

void ItemSnapable::addArtifactRef(const QVariantMap &ref)
{
    const QString hash = ref.value("contentHash").toString();
    if (hash.isEmpty())
        return;
    QVariantList updated = m_artifactRefs;
    // Remplacement LWW grossier : une seule référence par contentHash.
    for (int i = 0; i < updated.size(); ++i) {
        if (updated.at(i).toMap().value("contentHash").toString() == hash) {
            updated.replace(i, ref);
            setArtifactRefs(updated);
            return;
        }
    }
    updated.append(ref);
    setArtifactRefs(updated);
}

bool ItemSnapable::removeArtifactRef(const QString &contentHash)
{
    QVariantList updated;
    bool removed = false;
    for (const QVariant &v : std::as_const(m_artifactRefs)) {
        if (v.toMap().value("contentHash").toString() == contentHash) {
            removed = true;
            continue;
        }
        updated.append(v);
    }
    if (removed)
        setArtifactRefs(updated);
    return removed;
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
    if (json.contains("physicalObjectParameter"))
        m_physicalObjectParameter->applyJson(json["physicalObjectParameter"].toObject());

    // Espace mémoire (doc v3/05 Étape A). Sert au chargement disque et à
    // l'application d'un inverse de configuration undoable (Étape C). Passe par
    // setUserMemory qui émet userMemoryChanged → la restauration réveille aussi
    // les comportements abonnés (usage 3).
    if (json.contains("memory"))
        setUserMemory(json["memory"].toObject().toVariantMap());

    // Références d'artefacts (doc v3 D16/D36). Chargement disque + application
    // d'un inverse de configuration undoable (le blob n'est pas rechargé ici :
    // seule la référence voyage, le contenu se résout via ArtifactRegistry).
    if (json.contains("artifacts")) {
        QVariantList refs;
        const QJsonArray arr = json["artifacts"].toArray();
        for (const QJsonValue &v : arr) {
            const QJsonObject entry = v.toObject();
            QVariantMap ref;
            ref["instanceId"] = entry.value("instanceId").toString();
            ref["contentHash"] = entry.value("contentHash").toString();
            ref["manifestVersion"] = entry.value("manifestVersion").toInt();
            refs.append(ref);
        }
        setArtifactRefs(refs);
    }

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
