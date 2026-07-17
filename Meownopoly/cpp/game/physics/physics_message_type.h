/*
 *      PattounX v2 — types de messages réseau
 *
 * Plage 0x40–0x5F pour cohabiter sur Catway avec :
 *  - GameMessageType   (0x01–0x1F)
 *  - EditorMessageType (0x20–0x3F)
 *  - PhysicsMessageType (0x40–0x5F)
 *  - V3MessageType     (0x60–0x7F, réservée — cf. cpp/net/v3/v3_message_type.h)
 *
 * Toute nouvelle valeur doit être la plus haute pour ne pas être droppée par
 * `PhysicsProtocol::isPhysicsPacket` (filtre par plage), sans dépasser 0x5F.
 */
#ifndef PHYSICS_MESSAGE_TYPE_H
#define PHYSICS_MESSAGE_TYPE_H

#include <QObject>

namespace PhysicsMessageType {
Q_NAMESPACE

enum Value : quint8 {
    // ── Canal raw / haute fréquence ─────────────────────────────────────────
    /// hôte → tous : snapshot binaire compact (cf. PHYSICS_REFACTOR_PLAN §5.5).
    /// Diffusé en reliable pour la phase 7 (simplicité ; perte tolérable mais
    /// le coût ACK est marginal à 30 Hz). Migration vers raw possible si le
    /// budget bande passante l'exige.
    Snapshot         = 0x40,

    // ── Canal fiable (reliable) ─────────────────────────────────────────────
    /// hôte → tous : table {idIndex → actorId} (full ou incremental).
    /// Doit être reçu AVANT le premier `Snapshot` qui contient ces idIndex.
    BodiesAnnounce   = 0x41,

    /// client → hôte : input du clavier d'un client distant, à appliquer côté
    /// hôte via `pushInput(actorId, vec)` avant le prochain step.
    InputUpdate      = 0x42,

    /// client → hôte : "je viens de basculer en CLIENT, envoie-moi la full
    /// table d'idIndex sans attendre le timer 1 Hz". Évite la course où le
    /// BodiesAnnounce delta initial est envoyé par l'host AVANT que le client
    /// n'écoute reliableMessageReceived → tous les snapshots suivants
    /// "droppent" leurs bodies pour idIndex inconnu.
    Hello            = 0x43,

    /// client → hôte : requête de combat (JSON libre, ex. attaque du joueur).
    /// L'hôte autoritaire résout et re-broadcast l'issue via CombatEvent.
    AttackRequest    = 0x44,

    /// hôte → tous : événement de combat résolu (JSON libre : hp, mort,
    /// respawn, loot…). Les clients appliquent sur leurs miroirs locaux
    /// (HealthModule, états dead du CombatController).
    CombatEvent      = 0x45,

    /// hôte → tous : l'hôte quitte volontairement la session. Les clients
    /// repassent immédiatement en sim locale (stop()) au lieu de rester
    /// gelés sur le dernier snapshot jusqu'au timeout Catway (~10-30 s).
    /// Même rôle que EditorMessageType::HostLeaving (0x2A). Si l'app hôte
    /// se ferme, le QML doit retarder Qt.quit() (pattern Timer 300 ms de
    /// ApplicationWindow.onClosing) pour laisser le paquet partir.
    HostLeaving      = 0x46,

    /// hôte → client : réponse au Hello. Payload JSON
    /// { claimAccepted: bool, claim: str, takenBy?: str }. Sans lui, le
    /// client ne sait jamais si son claim a été accepté (la "réponse" au
    /// Hello n'était qu'un BodiesAnnounce anonyme) — un claim refusé
    /// (déjà pris par un autre client, premier arrivé premier servi)
    /// laissait tous ses InputUpdate rejetés silencieusement par l'hôte.
    Welcome          = 0x47,
};
Q_ENUM_NS(Value)

}

#endif // PHYSICS_MESSAGE_TYPE_H
