/*
 *      PattounX v2 — sérialisation des paquets réseau
 *
 * Format paquet : [1 byte: PhysicsMessageType][1 byte: kProtocolVersion][payload].
 *   - Snapshot       : payload binaire compact (cf. PhysicsWorld::serializeSnapshot)
 *   - BodiesAnnounce : payload UTF-8 JSON { added: [{i, id}], removed: ["id"] }
 *   - InputUpdate    : payload UTF-8 JSON { actorId, x, y }
 *
 * Le filtre `isPhysicsPacket` ne lit que le 1er octet et compare à la plage
 * [0x40 .. dernier type]. Cohabite avec EditorProtocol/GameProtocol sur Catway.
 * La version est vérifiée dans `peekType` (chokepoint de toute réception) :
 * deux builds au format différent rejettent proprement au lieu de
 * désérialiser du garbage en silence. Incrémenter kProtocolVersion à CHAQUE
 * changement de format (snapshot binaire compris).
 */
#ifndef PHYSICS_PROTOCOL_H
#define PHYSICS_PROTOCOL_H

#include "physics_message_type.h"

#include <QByteArray>
#include <QJsonObject>

class PhysicsProtocol
{
public:
    /// Version du format filaire. 1 = introduction du byte de version
    /// (2026-07-03, review N14).
    static constexpr quint8 kProtocolVersion = 1;

    /// Construit un paquet avec payload JSON (BodiesAnnounce, InputUpdate).
    static QByteArray packJson(PhysicsMessageType::Value type,
                               const QJsonObject &payload = {});

    /// Construit un paquet avec payload binaire opaque (Snapshot).
    static QByteArray packBinary(PhysicsMessageType::Value type,
                                 const QByteArray &payload);

    /// True si le paquet appartient à la plage PhysicsMessageType.
    static bool isPhysicsPacket(const QByteArray &data);

    /// Lit le type d'un paquet déjà filtré par isPhysicsPacket. Retourne false
    /// si data est vide ou si la version du protocole ne correspond pas
    /// (warning throttlé — builds incompatibles).
    static bool peekType(const QByteArray &data,
                         PhysicsMessageType::Value &outType);

    /// Décode payload JSON (Snapshot non supporté — utiliser payloadBytes).
    static bool unpackJson(const QByteArray &data,
                           PhysicsMessageType::Value &outType,
                           QJsonObject &outPayload);

    /// Retourne le payload brut (octets après les bytes type + version).
    /// Utilisé pour Snapshot.
    static QByteArray payloadBytes(const QByteArray &data);

private:
    PhysicsProtocol() = delete;
};

#endif // PHYSICS_PROTOCOL_H
