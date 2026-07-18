#ifndef ITEMSNAPABLE_H
#define ITEMSNAPABLE_H

#include <QObject>
#include <QQmlEngine>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include "game/case/Case.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QJsonValueRef>

#include "Displayparameter.h"
#include "decorationparameter.h"
#include "ZoneParameter.h"
#include "npcparameter.h"
#include "enemyparameter.h"
#include "physicalobjectparameter.h"

class ItemSnapable : public QObject
{
    Q_OBJECT

    
    Q_PROPERTY(Case* caseData READ caseData WRITE setCaseData NOTIFY caseDataChanged FINAL)
    Q_PROPERTY(DisplayParameter * displayParameter READ displayParameter WRITE setDisplayParameter NOTIFY displayParameterChanged FINAL)
    Q_PROPERTY(DecorationParameter * decorationParameter READ decorationParameter WRITE setDecorationParameter NOTIFY decorationParameterChanged FINAL)
    Q_PROPERTY(ZoneParameter * zoneParameter READ zoneParameter WRITE setZoneParameter NOTIFY zoneParameterChanged FINAL)
    Q_PROPERTY(NPCParameter * npcParameter READ npcParameter WRITE setNpcParameter NOTIFY npcParameterChanged FINAL)
    Q_PROPERTY(EnemyParameter * enemyParameter READ enemyParameter WRITE setEnemyParameter NOTIFY enemyParameterChanged FINAL)
    Q_PROPERTY(PhysicalObjectParameter * physicalObjectParameter READ physicalObjectParameter WRITE setPhysicalObjectParameter NOTIFY physicalObjectParameterChanged FINAL)
    Q_PROPERTY(QUuid uniqueId READ uniqueId WRITE setUniqueId NOTIFY uniqueIdChanged FINAL)
    Q_PROPERTY(TileType tileType READ tileType WRITE setTileType NOTIFY tileTypeChanged FINAL)
    // Espace mémoire par élément (doc v3/05, D15, Étape A). Blob de valeurs
    // sérialisables opaques côté cœur ; le sens des clés est une convention IA.
    Q_PROPERTY(QVariantMap userMemory READ userMemory WRITE setUserMemory NOTIFY userMemoryChanged FINAL)
    // Références d'artefacts portées par la tuile (doc v3, D16/D36, plan T4-1/M8).
    // Chaque entrée est un QVariantMap `{instanceId, contentHash, manifestVersion}`.
    // La tuile ne porte QUE la référence ; le contenu vit dans le store par hash
    // (ArtifactStore/ArtifactRegistry). Voyage dans EditDelta.before/after →
    // persistance + undo de configuration, comme userMemory.
    Q_PROPERTY(QVariantList artifactRefs READ artifactRefs WRITE setArtifactRefs NOTIFY artifactRefsChanged FINAL)


public:


    ItemSnapable();
    ~ItemSnapable();
    ItemSnapable(Case * caseData, DisplayParameter * displayParameter, QObject *parent = nullptr);
    ItemSnapable(DecorationParameter * decorationParameter, DisplayParameter * displayParameter, QObject *parent = nullptr);
    ItemSnapable(const QJsonObject &json, QObject *parent = nullptr);
    ItemSnapable(Case::CaseType caseType, QObject *parent = nullptr);
    enum TileType {
        CaseTile,
        DecorationTile,
        PhysicZoneTile,
        NPCTile,
        EnemyTile,
        PhysicalObjectTile,   // toute nouvelle valeur DOIT rester la plus
                              // haute (borne de validation du ctor JSON)
    };
    Q_ENUM(TileType)

    Case * caseData() const;
    void setCaseData(Case * caseData);
    DisplayParameter * displayParameter() const;
    void setDisplayParameter(DisplayParameter * displayParameter);
    DecorationParameter * decorationParameter() const;
    void setDecorationParameter(DecorationParameter * decorationParameter);
    ZoneParameter * zoneParameter() const;
    void setZoneParameter(ZoneParameter * zoneParameter);
    NPCParameter * npcParameter() const;
    void setNpcParameter(NPCParameter * npcParameter);
    EnemyParameter * enemyParameter() const;
    void setEnemyParameter(EnemyParameter * enemyParameter);
    PhysicalObjectParameter * physicalObjectParameter() const;
    void setPhysicalObjectParameter(PhysicalObjectParameter * physicalObjectParameter);
    static void registerQml();
    Q_INVOKABLE virtual QString toJSON();
    void applyJson(const QJsonObject &json);

    Q_INVOKABLE void print();

    QJsonObject getOriginalJson() const { return m_json; }

    // Shadow copy — état connu au dernier commitCurrentState()
    QString lastKnownJson() const { return m_lastKnownJson; }
    void commitCurrentState() { m_lastKnownJson = toJSON(); }

    QUuid uniqueId() const;
    void setUniqueId(const QUuid &newUniqueId);

    // ---- Espace mémoire (doc v3/05 Étape A, D15) ----
    // Conteneur typé QVariantMap (préserve int/real/string/bool côté QML).
    QVariantMap userMemory() const { return m_userMemory; }
    void setUserMemory(const QVariantMap &memory);
    // Setter fin : écrit une clé et émet un réveil ciblé memoryValueChanged.
    // Garde anti-boucle : aucune émission si la valeur est inchangée.
    Q_INVOKABLE void setMemoryValue(const QString &key, const QVariant &value);
    Q_INVOKABLE QVariant memoryValue(const QString &key) const { return m_userMemory.value(key); }

    // ---- Références d'artefacts (doc v3 D16/D36, plan T4-1/M8) ----
    QVariantList artifactRefs() const { return m_artifactRefs; }
    void setArtifactRefs(const QVariantList &refs);
    // Ajoute/remplace une référence par contentHash (LWW grossier sur le hash).
    Q_INVOKABLE void addArtifactRef(const QVariantMap &ref);
    // Retire toute référence dont le contentHash correspond. Vrai si retiré.
    Q_INVOKABLE bool removeArtifactRef(const QString &contentHash);

    Q_INVOKABLE void changeCaseDataType(Case::CaseType caseType);

    Q_INVOKABLE void addNext(ItemSnapable *newNext);
    Q_INVOKABLE bool removeNext(ItemSnapable *caseToRemove); // Nouvelle fonction
    Q_INVOKABLE  bool removeNextAt(int index); // Nouvelle fonction

    Q_INVOKABLE void addPrev(ItemSnapable *newPrev);
    Q_INVOKABLE bool removePrev(ItemSnapable *caseToRemove); // Nouvelle fonction
    Q_INVOKABLE bool removePrevAt(int index); // Nouvelle fonction

    Q_INVOKABLE QList<ItemSnapable*> getNextList() {return next;}
    Q_INVOKABLE QList<ItemSnapable*> getPrevList() {return prev;}
    QList<ItemSnapable*> next = QList<ItemSnapable*>();
    QList<ItemSnapable*> prev = QList<ItemSnapable*>();
    ItemSnapable::TileType tileType() const;
    void setTileType(const ItemSnapable::TileType &newTileType);

    // Copie les données d'un autre ItemSnapable
    Q_INVOKABLE void copyFrom(ItemSnapable* source);

    bool operator==(const ItemSnapable &other) const {
        qDebug() << "Comparing ItemSnapable with uniqueId:" << uniqueId() << "to ItemSnapable with uniqueId:" << other.uniqueId();
        if (m_tileType != other.m_tileType)
            return false;
        // L'espace mémoire fait partie de l'état de l'élément : sans ça, un
        // no-op (before==after) qui ne diffère que par la mémoire passerait
        // inaperçu dans la détection de changement.
        if (m_userMemory != other.m_userMemory)
            return false;
        // Les références d'artefacts font partie de l'état de la tuile (D16/D36) :
        // un no-op qui ne diffère que par une référence doit être détecté.
        if (m_artifactRefs != other.m_artifactRefs)
            return false;
        if (m_displayParameter && other.m_displayParameter) {
            if (!(*m_displayParameter == *other.m_displayParameter))
                return false;
        }
        switch (m_tileType) {
        case DecorationTile:
            if (m_decorationParameter && other.m_decorationParameter)
                if (!(*m_decorationParameter == *other.m_decorationParameter))
                    return false;
            break;
        case PhysicZoneTile:
            if (m_zoneParameter && other.m_zoneParameter)
                if (!(*m_zoneParameter == *other.m_zoneParameter))
                    return false;
            break;
        case NPCTile:
            if (m_npcParameter && other.m_npcParameter)
                if (!(*m_npcParameter == *other.m_npcParameter))
                    return false;
            // Le visuel sprite d'un PNJ passe par decorationParameter.
            if (m_decorationParameter && other.m_decorationParameter)
                if (!(*m_decorationParameter == *other.m_decorationParameter))
                    return false;
            break;
        case EnemyTile:
            if (m_enemyParameter && other.m_enemyParameter)
                if (!(*m_enemyParameter == *other.m_enemyParameter))
                    return false;
            break;
        case PhysicalObjectTile:
            if (m_physicalObjectParameter && other.m_physicalObjectParameter)
                if (!(*m_physicalObjectParameter == *other.m_physicalObjectParameter))
                    return false;
            break;
        case CaseTile:
            if (m_caseData && other.m_caseData)
                if (m_caseData->toJSON() != other.m_caseData->toJSON())
                    return false;
            break;
        }
        if (next.size() != other.next.size() || prev.size() != other.prev.size())
            return false;
        for (int i = 0; i < next.size(); i++)
            if (next[i]->uniqueId() != other.next[i]->uniqueId())
                return false;
        for (int i = 0; i < prev.size(); i++)
            if (prev[i]->uniqueId() != other.prev[i]->uniqueId())
                return false;
        return true;
    }

signals:
    void caseDataChanged();
    void displayParameterChanged();
    void decorationParameterChanged();
    void zoneParameterChanged();
    void npcParameterChanged();
    void enemyParameterChanged();
    void physicalObjectParameterChanged();

    void uniqueIdChanged();

    void tileTypeChanged();

    // Réveil global (toute la map a changé) — support de l'usage 3 (doc v3/05
    // §1) : règles custom et comportements générés s'y abonnent.
    void userMemoryChanged();
    // Réveil ciblé sur une clé sans re-scanner la map. `version` est un compteur
    // d'écriture monotone qui aide à ignorer les états obsolètes.
    void memoryValueChanged(const QString &ns, const QString &key,
                            const QVariant &value, int version);

    // Réveil sur changement de l'ensemble des références d'artefacts.
    void artifactRefsChanged();

private :
    Case * m_caseData = nullptr;
    DisplayParameter * m_displayParameter = new DisplayParameter;
    DecorationParameter * m_decorationParameter = new DecorationParameter;
    ZoneParameter * m_zoneParameter = new ZoneParameter;
    NPCParameter * m_npcParameter = new NPCParameter;
    EnemyParameter * m_enemyParameter = new EnemyParameter;
    PhysicalObjectParameter * m_physicalObjectParameter = new PhysicalObjectParameter;
    QJsonObject m_json;
    QString m_lastKnownJson;
    QUuid m_uniqueId;
    TileType m_tileType;

    // Espace mémoire (doc v3/05 Étape A). QVariantMap pour préserver les types
    // natifs et se convertir dans les deux sens avec QJsonObject.
    QVariantMap m_userMemory;
    // Références d'artefacts (doc v3 D16/D36). Liste de QVariantMap
    // `{instanceId, contentHash, manifestVersion}`.
    QVariantList m_artifactRefs;
    // Compteur d'écriture monotone porté par memoryValueChanged.
    quint32 m_memoryVersion = 0;
    // Garde de réentrance : plafonne la cascade écriture→signal→écriture d'une
    // règle qui, en réaction, ré-écrit la mémoire (doc v3/05 §4).
    int m_memoryWriteDepth = 0;
    static constexpr int kMaxMemoryCascadeDepth = 16;
};

#endif // ITEMSNAPABLE_H
