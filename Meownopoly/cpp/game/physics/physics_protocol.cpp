#include "physics_protocol.h"

#include <QJsonDocument>

QByteArray PhysicsProtocol::packJson(PhysicsMessageType::Value type,
                                     const QJsonObject &payload)
{
    QByteArray result;
    result.reserve(256);
    result.append(static_cast<char>(type));
    if (!payload.isEmpty()) {
        result.append(QJsonDocument(payload).toJson(QJsonDocument::Compact));
    }
    return result;
}

QByteArray PhysicsProtocol::packBinary(PhysicsMessageType::Value type,
                                       const QByteArray &payload)
{
    QByteArray result;
    result.reserve(payload.size() + 1);
    result.append(static_cast<char>(type));
    result.append(payload);
    return result;
}

bool PhysicsProtocol::isPhysicsPacket(const QByteArray &data)
{
    if (data.isEmpty()) return false;
    const quint8 rawType = static_cast<quint8>(data.at(0));
    // Plage physique : Snapshot (0x40) → InputUpdate (0x42). À étendre quand
    // de nouveaux types apparaissent (cf. note dans physics_message_type.h).
    return rawType >= PhysicsMessageType::Snapshot
        && rawType <= PhysicsMessageType::InputUpdate;
}

bool PhysicsProtocol::peekType(const QByteArray &data,
                               PhysicsMessageType::Value &outType)
{
    if (!isPhysicsPacket(data)) return false;
    outType = static_cast<PhysicsMessageType::Value>(static_cast<quint8>(data.at(0)));
    return true;
}

bool PhysicsProtocol::unpackJson(const QByteArray &data,
                                 PhysicsMessageType::Value &outType,
                                 QJsonObject &outPayload)
{
    if (!peekType(data, outType)) return false;

    if (data.size() > 1) {
        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(data.mid(1), &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) return false;
        outPayload = doc.object();
    } else {
        outPayload = QJsonObject{};
    }
    return true;
}

QByteArray PhysicsProtocol::payloadBytes(const QByteArray &data)
{
    if (data.size() <= 1) return {};
    return data.mid(1);
}
