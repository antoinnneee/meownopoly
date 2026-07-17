/*
 *      Meownopoly V3 — sérialisation du transport (B1)
 *
 * Helpers statiques calqués sur EditorProtocol : encapsulent l'enveloppe
 * commune V3 (V3Envelope) dans le format fil de Catway.
 *
 * Format paquet : [1 octet V3MessageType::Value][enveloppe JSON UTF-8].
 * L'octet de tête (0x60, `Envelope`) est le seul aiguillage de transport ; le
 * `kind` de l'enveloppe porte le discriminant applicatif.
 */
#ifndef V3_PROTOCOL_H
#define V3_PROTOCOL_H

#include "v3_envelope.h"
#include "v3_message_type.h"

#include <QByteArray>

class V3Protocol
{
public:
    /// Construit un paquet fil : [type byte][enveloppe JSON compact].
    /// `type` par défaut `Envelope` (0x60) — le seul aiguillage V3 pour l'instant.
    static QByteArray pack(const V3Envelope &envelope,
                           V3MessageType::Value type = V3MessageType::Envelope);

    /// Décode un paquet V3. Retourne false si :
    ///  - le premier octet n'est pas dans la plage V3 (0x60+), ou
    ///  - le JSON est invalide, ou
    ///  - l'enveloppe est malformée (champ obligatoire manquant / mal typé).
    /// Le contrôle d'intégrité `payloadHash` (V3Envelope::isValid) est laissé
    /// au consommateur : `unpack` garantit la forme, pas la cohérence métier.
    static bool unpack(const QByteArray &data,
                       V3MessageType::Value &outType,
                       V3Envelope &outEnvelope);

    /// True si le premier octet appartient à la plage V3 (>= Base 0x60). Sert
    /// à démultiplexer côté réception, à l'image de `isEditorPacket`.
    /// Attention : toute nouvelle valeur de V3MessageType doit rester la plus
    /// haute de l'enum (borne haute étendue ici) sous peine de drop silencieux.
    static bool isV3Packet(const QByteArray &data);

private:
    V3Protocol() = delete;
};

#endif // V3_PROTOCOL_H
