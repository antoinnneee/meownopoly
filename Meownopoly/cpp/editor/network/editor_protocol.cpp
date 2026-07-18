#include "editor_protocol.h"

#include <QJsonDocument>

QByteArray EditorProtocol::pack(EditorMessageType::Value type, const QJsonObject &payload)
{
    QByteArray result;
    result.reserve(256);
    result.append(static_cast<char>(type));

    if (!payload.isEmpty()) {
        result.append(QJsonDocument(payload).toJson(QJsonDocument::Compact));
    }

    return result;
}

bool EditorProtocol::isEditorPacket(const QByteArray &data)
{
    if (data.isEmpty()) return false;
    const quint8 rawType = static_cast<quint8>(data.at(0));
    // Plage éditeur : de Hello (0x20) au dernier type défini. Attention :
    // toute nouvelle valeur ajoutée dans editor_message_type.h doit ÊTRE
    // la plus haute, sinon elle serait droppée ici.
    return rawType >= EditorMessageType::Hello
           && rawType <= EditorMessageType::MigrationCheckpointAck;
}

bool EditorProtocol::unpack(const QByteArray &data,
                            EditorMessageType::Value &outType,
                            QJsonObject &outPayload)
{
    if (!isEditorPacket(data)) return false;

    outType = static_cast<EditorMessageType::Value>(static_cast<quint8>(data.at(0)));

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
