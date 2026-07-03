#include "physics_protocol.h"

#include <QDebug>
#include <QJsonDocument>

QByteArray PhysicsProtocol::packJson(PhysicsMessageType::Value type,
                                     const QJsonObject &payload)
{
    QByteArray result;
    result.reserve(256);
    result.append(static_cast<char>(type));
    result.append(static_cast<char>(kProtocolVersion));
    if (!payload.isEmpty()) {
        result.append(QJsonDocument(payload).toJson(QJsonDocument::Compact));
    }
    return result;
}

QByteArray PhysicsProtocol::packBinary(PhysicsMessageType::Value type,
                                       const QByteArray &payload)
{
    QByteArray result;
    result.reserve(payload.size() + 2);
    result.append(static_cast<char>(type));
    result.append(static_cast<char>(kProtocolVersion));
    result.append(payload);
    return result;
}

bool PhysicsProtocol::isPhysicsPacket(const QByteArray &data)
{
    if (data.isEmpty()) return false;
    const quint8 rawType = static_cast<quint8>(data.at(0));
    // Plage physique : Snapshot (0x40) → dernier type. À étendre quand
    // de nouveaux types apparaissent (cf. note dans physics_message_type.h).
    return rawType >= PhysicsMessageType::Snapshot
        && rawType <= PhysicsMessageType::Welcome;
}

bool PhysicsProtocol::peekType(const QByteArray &data,
                               PhysicsMessageType::Value &outType)
{
    if (!isPhysicsPacket(data)) return false;
    // Vérification de version au chokepoint de toute réception : deux
    // builds au format différent rejettent proprement au lieu de
    // désérialiser du garbage en silence.
    if (data.size() < 2
        || static_cast<quint8>(data.at(1)) != kProtocolVersion) {
        static int mismatches = 0;
        if ((mismatches++ & 0x3F) == 0) {
            qWarning() << "[PhysicsProtocol] paquet rejeté — version"
                       << (data.size() >= 2 ? static_cast<quint8>(data.at(1)) : 0)
                       << "!= attendue" << kProtocolVersion
                       << "(builds incompatibles ?" << mismatches
                       << "rejets cumulés)";
        }
        return false;
    }
    outType = static_cast<PhysicsMessageType::Value>(static_cast<quint8>(data.at(0)));
    return true;
}

bool PhysicsProtocol::unpackJson(const QByteArray &data,
                                 PhysicsMessageType::Value &outType,
                                 QJsonObject &outPayload)
{
    if (!peekType(data, outType)) return false;

    // Garde-fou : aucun payload JSON légitime du protocole physique
    // n'approche cette taille (le plus gros est la full table idIndex,
    // quelques KB). Un paquet forgé énorme ne doit pas passer par le
    // parseur JSON (allocation + parse coûteux sur le thread GUI).
    constexpr qsizetype kMaxJsonPayload = 64 * 1024;
    if (data.size() - 2 > kMaxJsonPayload) return false;

    if (data.size() > 2) {
        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(data.mid(2), &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) return false;
        outPayload = doc.object();
    } else {
        outPayload = QJsonObject{};
    }
    return true;
}

QByteArray PhysicsProtocol::payloadBytes(const QByteArray &data)
{
    if (data.size() <= 2) return {};
    return data.mid(2);
}
