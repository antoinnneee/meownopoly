#ifndef EDITOR_MESSAGE_TYPE_H
#define EDITOR_MESSAGE_TYPE_H

#include <QObject>

/// Types de messages du protocole réseau de l'éditeur collaboratif.
/// Le premier octet de chaque paquet fiable identifie le type.
/// Plage 0x20–0x3F pour ne pas entrer en collision avec GameMessageType
/// (0x01–0x11), PhysicsMessageType (0x40+) ni V3MessageType (0x60+, réservé
/// P0-3, cf. cpp/net/v3/v3_message_type.h). Rester sous 0x40.
namespace EditorMessageType {
Q_NAMESPACE

enum Value : quint8 {
    // ── Canal fiable (reliable UDP) ─────────────────────────────────────────
    Hello             = 0x20,  // client → hôte : demande de join { nickname, assetPackHash }
    Welcome           = 0x21,  // hôte → client : acceptation { sessionId, version, hostPlayerId, baseSeq }
    FullSync          = 0x22,  // hôte → client : snapshot map (chunké) { chunkIndex, chunkCount, payloadB64 }
    Op                = 0x23,  // client ↔ hôte : opération d'édition { opId, type, target, payload, serverSeq }
    OpAck             = 0x24,  // hôte → client : ack d'op validée { opId, serverSeq }
    OpReject          = 0x25,  // hôte → client : op rejetée { opId, reason }
    CursorUpdate      = 0x26,  // broadcast UDP brut : { playerId, x, y } (lossy, ~20 Hz)
    SelectionUpdate   = 0x27,  // broadcast reliable : { playerId, uuids, dragging }
    PlayerRoster      = 0x28,  // hôte → tous : { players: [{playerId, nickname, color}] }
    // transport chunké pour ops dont le JSON dépasse le plafond reliable (~28 KB).
    // Payload : { opId, chunkIndex, chunkCount, payloadB64, origType }.
    OpChunk           = 0x29,
    // hôte → tous : l'hôte quitte proprement. Permet aux clients de déclencher
    // l'élection d'un nouvel hôte immédiatement (sans attendre le timeout ~10 s).
    // V3 T4-3 (D37) : le payload embarque aussi `checkpoint` (règlement versionné
    // + hashes d'artefacts actifs + hash/état du bus d'état + contexte arbitre
    // best-effort) — chunké via OpChunk si volumineux.
    HostLeaving       = 0x2A,
    // V3 T4-3 (D37) : nouvel hôte → tous. Le checkpoint de migration a été
    // appliqué ET l'arbitre a passé le handshake D24 → les propositions
    // reprennent (fin de la suspension côté pairs). Doit rester la valeur la
    // plus haute (filtre de plage isEditorPacket).
    MigrationCheckpointAck = 0x2B,
};
Q_ENUM_NS(Value)

}

#endif // EDITOR_MESSAGE_TYPE_H
