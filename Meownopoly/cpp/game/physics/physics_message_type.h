/*
 *      PattounX v2 — types de messages réseau
 *
 * Plage 0x40+ pour cohabiter sur Catway avec :
 *  - GameMessageType   (0x01–0x1F)
 *  - EditorMessageType (0x20–0x3F)
 *  - PhysicsMessageType (0x40+)
 *
 * Toute nouvelle valeur doit être la plus haute pour ne pas être droppée par
 * `PhysicsProtocol::isPhysicsPacket` (filtre par plage).
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
};
Q_ENUM_NS(Value)

}

#endif // PHYSICS_MESSAGE_TYPE_H
