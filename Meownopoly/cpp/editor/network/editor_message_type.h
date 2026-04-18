#ifndef EDITOR_MESSAGE_TYPE_H
#define EDITOR_MESSAGE_TYPE_H

#include <QObject>

/// Types de messages du protocole réseau de l'éditeur collaboratif.
/// Le premier octet de chaque paquet fiable identifie le type.
/// Plage 0x20+ pour ne pas entrer en collision avec GameMessageType (0x01–0x11).
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
};
Q_ENUM_NS(Value)

}

#endif // EDITOR_MESSAGE_TYPE_H
