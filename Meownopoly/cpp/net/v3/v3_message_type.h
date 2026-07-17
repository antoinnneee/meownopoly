/*
 *      Meownopoly V3 — types de messages réseau (réservation de plage)
 *
 * Plage 0x60+ réservée à V3 pour cohabiter sur Catway avec les protocoles
 * existants, sans jamais entrer en collision avec leurs filtres de plage
 * (`isXxxPacket`) — une collision = drop silencieux du paquet.
 *
 *  - GameMessageType    0x01–0x1F  (game/network)
 *  - EditorMessageType  0x20–0x3F  (dernier occupé : 0x2A, HostLeaving)
 *  - PhysicsMessageType 0x40–0x47  (« doit toujours être la plus haute »)
 *  - [0x48–0x5F]        libre (marge tampon volontaire)
 *  - V3MessageType      0x60+      (ci-dessous)
 *
 * Cette plage couvre les familles V3 identifiées par le plan
 * d'implémentation ([doc 15](../../doc/v3/15_PLAN_IMPLEMENTATION.md), P0-3) :
 *   - ProposalSession (D40, [doc 13](../../doc/v3/13_ENVELOPPE_PROPOSITION.md)) ;
 *   - bus d'état partagé (D35) ;
 *   - transactions applicatives ;
 *   - migration / cycle de vie de session V3.
 *
 * Les valeurs concrètes seront ajoutées au fur et à mesure des tâches B/M ;
 * ce fichier fige uniquement le point de départ de la plage et le contrat
 * « toute nouvelle valeur reste dans 0x60+ et l'enveloppe commune (B1) porte
 * le `kind` applicatif à l'intérieur du payload ».
 */
#ifndef V3_MESSAGE_TYPE_H
#define V3_MESSAGE_TYPE_H

#include <QObject>

namespace V3MessageType {
Q_NAMESPACE

/// Premier octet des paquets V3 sur Catway. Toute valeur DOIT être >= Base
/// (0x60) pour ne pas empiéter sur Game/Editor/Physics. L'enveloppe commune V3
/// (B1) est transportée dans le payload ; ces octets ne sont qu'un aiguillage
/// de transport de plus haut niveau.
enum Value : quint8 {
    /// Borne basse de la plage V3. Sert de sentinelle pour les futurs filtres
    /// `V3Protocol::isV3Packet` (plage `>= Base && <= <dernier type>`).
    Base = 0x60,

    /// Enveloppe commune V3 (B1). Aiguillage de transport unique : tout paquet
    /// V3 est un `[0x60][enveloppe JSON]`, l'enveloppe porte le `kind`
    /// applicatif (ProposalSession, StateBus, Transaction, migration…) dans
    /// son propre champ. Les familles applicatives se distinguent par `kind`,
    /// pas par un octet de tête distinct — un seul point d'entrée réseau.
    Envelope = 0x60,

    // ── À pourvoir (les tâches suivantes occupent la plage si un aiguillage ──
    // ── de transport distinct s'avère nécessaire ; par défaut tout passe par ──
    // ── `Envelope` et se discrimine sur `kind`) : ──
    // ProposalSession  (D40) : kind "proposal.*".
    // StateBus         (D35) : kind "state.*" (seq monotone dans l'enveloppe).
    // Transaction              : kind "tx.*" (commit / rollback applicatifs).
    // SessionMigration         : kind "session.*" (départ hôte, ré-élection).
    //
    // Contrainte : toute nouvelle valeur doit rester la plus haute de l'enum
    // (comme PhysicsMessageType) pour un filtrage par plage sûr.
};
Q_ENUM_NS(Value)

}

#endif // V3_MESSAGE_TYPE_H
