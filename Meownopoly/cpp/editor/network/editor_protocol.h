#ifndef EDITOR_PROTOCOL_H
#define EDITOR_PROTOCOL_H

#include "editor_message_type.h"
#include <QByteArray>
#include <QJsonObject>

/// Helpers statiques de sérialisation/désérialisation du protocole éditeur.
///
/// Format paquet fiable : [1 byte: EditorMessageType::Value][payload UTF-8 JSON]
class EditorProtocol
{
public:
    /// Construit un paquet fiable : [type byte][JSON payload UTF-8].
    static QByteArray pack(EditorMessageType::Value type, const QJsonObject &payload = {});

    /// Décode un paquet fiable. Retourne false si le paquet est invalide ou
    /// si le type ne fait pas partie de la plage EditorMessageType.
    static bool unpack(const QByteArray &data,
                       EditorMessageType::Value &outType,
                       QJsonObject &outPayload);

    /// Retourne true si le premier octet du paquet appartient à la plage
    /// EditorMessageType (utile pour démultiplexer côté réception).
    static bool isEditorPacket(const QByteArray &data);

private:
    EditorProtocol() = delete;
};

#endif // EDITOR_PROTOCOL_H
