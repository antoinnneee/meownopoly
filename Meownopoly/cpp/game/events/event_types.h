/*
 *      V3 / M5 — Journal d'événements métier (D1)
 *
 * Types partagés du GameplayEventBus. Un « événement de gameplay » est une
 * observation typée et horodatée logiquement de la vie de la partie/carte :
 * mutation d'éditeur, cycle de vie d'une tuile, événement de combat, etc.
 *
 * Champs D1 (registre) : { id, auteur, source, ts logique, causalité, version }.
 *  - id        : UUID unique de l'événement (chaîne sans accolades) ;
 *  - author    : auteur métier (playerId, "local", "remote" ou "system") ;
 *  - source    : brique émettrice (Game, EditorOpBus, tuiles, physique) ;
 *  - logicalTs : horloge de Lamport (compteur logique monotone — même
 *                principe que game_lamport.cpp, cf. GameplayEventBus) ;
 *  - causeId   : id de l'événement causal (causalité), vide si racine ;
 *  - version   : version de schéma (kGameplayEventSchemaVersion).
 *
 * NB : la numérotation des enums est PERSISTÉE dans l'audit (D2/D19) — ne
 * jamais réutiliser une valeur retirée, seulement en ajouter.
 */
#ifndef GAMEPLAY_EVENT_TYPES_H
#define GAMEPLAY_EVENT_TYPES_H

#include <QMetaType>
#include <QString>
#include <QVariantMap>
#include <QtGlobal>

namespace meow {

// Version du schéma d'événement. Incrémenter à toute évolution du format
// (champ `version` de chaque GameplayEvent).
inline constexpr quint32 kGameplayEventSchemaVersion = 1;

// Brique émettrice de l'événement. Sert au filtrage (abonnements ciblés de la
// passerelle IA en D4) et à l'audit.
enum class EventSource : quint32 {
    Unknown   = 0,
    Game      = 1,   // singleton Game — cycle de vie carte/partie
    EditorOps = 2,   // EditorOpBus — mutations d'éditeur (locales/distantes)
    Tiles     = 3,   // ItemSnapableEvents — vie des tuiles
    Physics   = 4,   // PhysicsSession — combat / runtime physique
    System    = 5,   // interne au bus
};

// Type métier de l'événement. Numérotation stable, par plages de 100 alignées
// sur la source.
enum class EventType : quint32 {
    Unknown              = 0,

    // --- Game (cycle de vie) ---
    GameStarted          = 100,
    MapLoaded            = 101,
    MapCleared           = 102,
    TileRemovedGame      = 103,
    MapRestored          = 104,

    // --- EditorOpBus ---
    EditorOpLocal        = 200,
    EditorOpRemote       = 201,

    // --- Tuiles (ItemSnapableEvents) ---
    TileCreated          = 300,
    TileDeleted          = 301,
    TileMoved            = 302,
    ZoneParameterChanged = 303,

    // --- Physique (PhysicsSession) ---
    CombatRequest        = 400,
    CombatResolved       = 401,
};

// Durabilité de l'événement (M5 : « distinguer durables/auditables des
// visuels éphémères »). Les DURABLE alimentent le noyau d'audit non
// désactivable (D2/D19) ; les EPHEMERAL sont diffusés mais non archivés
// (déplacements en drag, changements de paramètre haute fréquence…). La
// classification par type est centralisée dans durabilityOf().
enum class EventDurability : quint32 {
    Ephemeral = 0,
    Durable   = 1,
};

// Classification durable/éphémère par type. Défini dans gameplay_event_bus.cpp.
EventDurability durabilityOf(EventType type);

// Libellé lisible d'un type (audit/debug). Défini dans gameplay_event_bus.cpp.
QString eventTypeName(EventType type);
QString eventSourceName(EventSource source);

// Enregistrement typé et horodaté logiquement d'un événement métier.
struct GameplayEvent {
    QString         id;                                       // UUID unique
    EventType       type       = EventType::Unknown;
    EventSource     source     = EventSource::Unknown;
    QString         author;                                   // playerId / "local" / "remote" / "system"
    qint64          logicalTs  = 0;                           // horloge de Lamport (monotone)
    QString         causeId;                                  // id causal (causalité), vide si racine
    quint32         version    = kGameplayEventSchemaVersion; // schéma
    EventDurability durability  = EventDurability::Ephemeral;
    QVariantMap     payload;                                  // charge utile spécifique au type
    qint64          wallTs     = 0;                           // horodatage mur (ms epoch), audit humain

    // --- D2 : curseur d'audit (D19) ---
    // Séquence d'audit strictement monotone (+1 par événement ingéré, JAMAIS de
    // saut — distincte de logicalTs/Lamport qui peut bondir à syncLogicalClock).
    // C'est LA clé de reprise du curseur `events_poll` (D4) et de l'ordre du
    // noyau d'audit. `seq == 0` = non encore ingéré.
    quint64         seq        = 0;

    // Projection QVariantMap pour QML / journalisation / futur events_poll (D4).
    QVariantMap toVariantMap() const;
};

} // namespace meow

Q_DECLARE_METATYPE(meow::GameplayEvent)

#endif // GAMEPLAY_EVENT_TYPES_H
