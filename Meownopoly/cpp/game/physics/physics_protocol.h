/*
 *      PattounX v2 — sérialisation des paquets réseau
 *
 * Format paquet : [1 byte: PhysicsMessageType][payload].
 *   - Snapshot       : payload binaire compact (cf. PhysicsWorld::serializeSnapshot)
 *   - BodiesAnnounce : payload UTF-8 JSON { added: [{i, id}], removed: ["id"] }
 *   - InputUpdate    : payload UTF-8 JSON { actorId, x, y }
 *
 * Le filtre `isPhysicsPacket` ne lit que le 1er octet et compare à la plage
 * [0x40 .. dernier type]. Cohabite avec EditorProtocol/GameProtocol sur Catway.
 */
#ifndef PHYSICS_PROTOCOL_H
#define PHYSICS_PROTOCOL_H

#include "physics_message_type.h"

#include <QByteArray>
#include <QJsonObject>

class PhysicsProtocol
{
public:
    /// Construit un paquet avec payload JSON (BodiesAnnounce, InputUpdate).
    static QByteArray packJson(PhysicsMessageType::Value type,
                               const QJsonObject &payload = {});

    /// Construit un paquet avec payload binaire opaque (Snapshot).
    static QByteArray packBinary(PhysicsMessageType::Value type,
                                 const QByteArray &payload);

    /// True si le paquet appartient à la plage PhysicsMessageType.
    static bool isPhysicsPacket(const QByteArray &data);

    /// Lit le type d'un paquet déjà filtré par isPhysicsPacket. Retourne false
    /// si data est vide.
    static bool peekType(const QByteArray &data,
                         PhysicsMessageType::Value &outType);

    /// Décode payload JSON (Snapshot non supporté — utiliser payloadBytes).
    static bool unpackJson(const QByteArray &data,
                           PhysicsMessageType::Value &outType,
                           QJsonObject &outPayload);

    /// Retourne le payload brut (octets après le type byte). Utilisé pour
    /// Snapshot.
    static QByteArray payloadBytes(const QByteArray &data);

private:
    PhysicsProtocol() = delete;
};

#endif // PHYSICS_PROTOCOL_H
