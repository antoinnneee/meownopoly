/*
 *      Meownopoly V3 — enveloppe commune de transport (B1)
 *
 * Unité d'échange de plus bas niveau de la pile réseau V3, au-dessus de
 * Catway/reliable.io. Toute famille applicative V3 (ProposalSession D40, bus
 * d'état D35, transactions, migration de session) voyage dans cette enveloppe
 * commune ; le champ `kind` porte le discriminant applicatif, distinct du
 * schéma métier de l'enveloppe de proposition (doc v3/13) qui, lui, voyage
 * *dans* le `payload`.
 *
 * Champs (cf. plan v3/15, tâche B1) :
 *   - messageId     : identifiant unique du message (UUID) — clé de
 *                     déduplication du transport fiable applicatif (B2).
 *   - sessionId     : session V3 logique à laquelle appartient le message.
 *   - senderId      : playerId (roster) de l'émetteur.
 *   - kind          : type applicatif ("proposal.submit", "state.update"…),
 *                     libre côté transport, contractualisé par chaque famille.
 *   - seq           : séquence monotone par (session, émetteur) — supporte le
 *                     drop de l'ancien (B3) et l'ordonnancement.
 *   - correlationId : relie une réponse à sa requête (vide si sans objet).
 *   - payloadHash   : empreinte du payload ("sha256:<hex>"), intégrité + aide
 *                     à la dédup. Recalculée/vérifiée, jamais reprise aveugle.
 *   - payload       : charge applicative (JSON libre).
 *
 * L'enveloppe est sérialisée en JSON et transportée par V3Protocol derrière
 * l'octet `V3MessageType::Envelope` (0x60).
 */
#ifndef V3_ENVELOPE_H
#define V3_ENVELOPE_H

#include <QByteArray>
#include <QJsonObject>
#include <QString>
#include <QtGlobal>

/// Version du schéma de l'enveloppe de transport V3. Distincte de
/// `envelopeVersion` du schéma métier de proposition (doc 13). Bump à tout
/// changement incompatible du jeu de champs ci-dessous.
inline constexpr int kV3EnvelopeVersion = 1;

/// Enveloppe commune de transport V3. POD sérialisable ; aucune dépendance Qt
/// GUI, utilisable côté worker réseau comme côté métier.
struct V3Envelope
{
    int         envelopeVersion = kV3EnvelopeVersion;
    QString     messageId;      ///< UUID unique du message (dédup transport).
    QString     sessionId;      ///< Session V3 logique.
    QString     senderId;       ///< playerId émetteur (roster).
    QString     kind;           ///< Discriminant applicatif.
    quint64     seq = 0;        ///< Séquence monotone par (session, émetteur).
    QString     correlationId;  ///< Corrélation requête/réponse (vide si N/A).
    QString     payloadHash;    ///< "sha256:<hex>" du payload compact.
    QJsonObject payload;        ///< Charge applicative.

    /// Construit une enveloppe prête à l'envoi : génère un `messageId` frais
    /// si absent et calcule `payloadHash` à partir de `payload`.
    /// `envelopeVersion` reste à la version courante.
    static V3Envelope create(const QString &sessionId,
                             const QString &senderId,
                             const QString &kind,
                             quint64 seq,
                             const QJsonObject &payload,
                             const QString &correlationId = QString());

    /// Empreinte canonique d'un payload : "sha256:<hex>" du JSON compact.
    /// Déterministe (QJsonDocument::Compact trie les clés) → comparable de bout
    /// en bout pour la dédup et la détection de corruption.
    static QString computePayloadHash(const QJsonObject &payload);

    /// Sérialise l'enveloppe complète (champs + payload) en objet JSON.
    QJsonObject toJson() const;

    /// Reconstruit une enveloppe depuis un objet JSON. Retourne false si un
    /// champ obligatoire manque ou est mal typé (l'enveloppe reste alors
    /// partiellement remplie et ne doit pas être utilisée).
    static bool fromJson(const QJsonObject &obj, V3Envelope &out);

    /// Validité structurelle : version supportée, champs obligatoires non
    /// vides, et `payloadHash` cohérent avec `payload` (intégrité). Ne juge pas
    /// la sémantique applicative (rôle du consommateur du `kind`).
    bool isValid() const;

    /// True si `payloadHash` correspond au `payload` courant.
    bool verifyPayloadHash() const;
};

#endif // V3_ENVELOPE_H
