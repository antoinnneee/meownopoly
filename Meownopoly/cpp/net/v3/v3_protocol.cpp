#include "v3_protocol.h"

#include <QJsonDocument>

QByteArray V3Protocol::pack(const V3Envelope &envelope, V3MessageType::Value type)
{
    QByteArray result;
    result.reserve(512);
    result.append(static_cast<char>(type));
    result.append(QJsonDocument(envelope.toJson()).toJson(QJsonDocument::Compact));
    return result;
}

bool V3Protocol::isV3Packet(const QByteArray &data)
{
    if (data.isEmpty()) return false;
    const quint8 rawType = static_cast<quint8>(data.at(0));
    // Plage V3 : de Base (0x60) au dernier type défini (Envelope aujourd'hui).
    // Toute nouvelle valeur ajoutée dans v3_message_type.h doit être la plus
    // haute et remplacer la borne ci-dessous, sinon elle serait droppée ici.
    return rawType >= V3MessageType::Base && rawType <= V3MessageType::Envelope;
}

bool V3Protocol::unpack(const QByteArray &data,
                        V3MessageType::Value &outType,
                        V3Envelope &outEnvelope)
{
    if (!isV3Packet(data)) return false;

    outType = static_cast<V3MessageType::Value>(static_cast<quint8>(data.at(0)));

    if (data.size() <= 1) return false; // enveloppe obligatoire

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(data.mid(1), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return false;

    return V3Envelope::fromJson(doc.object(), outEnvelope);
}
