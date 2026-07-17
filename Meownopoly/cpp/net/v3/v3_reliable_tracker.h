/*
 *      Meownopoly V3 — fiabilité applicative au-dessus de reliable.io (B2)
 *
 * Comptabilité pure (aucun appel réseau) de l'ACK applicatif, du retry et de
 * la déduplication des messages V3 (enveloppe B1). Possédé par CatwayWorker et
 * utilisé EXCLUSIVEMENT sur le thread réseau — aucune synchronisation interne.
 *
 * Pourquoi : reliable.io calcule bien les ACKs par séquence, mais le worker
 * les jetait sans les lire (`reliable_endpoint_clear_acks` aveugle, cœur du
 * problème E06/F06) et ne retransmettait jamais — « reliable » ne l'était que
 * de nom pour un paquet perdu. Ce tracker :
 *   - côté émission : mémorise {messageId → paquet fil + séquence reliable}
 *     et confirme à partir des ACKs capturés AVANT clear_acks ; retransmet
 *     avec backoff adaptatif (RTT de l'endpoint) ; plafonds de file et de
 *     tentatives, échec définitif remonté au métier par le worker ;
 *   - côté réception : déduplique par `messageId` (une retransmission arrive
 *     sous une NOUVELLE séquence reliable, donc la couche reliable ne peut pas
 *     la reconnaître comme doublon — seule la clé applicative le peut).
 *
 * Les échéances sont exprimées sur l'horloge du worker (m_reliableClock, ms).
 */
#ifndef V3_RELIABLE_TRACKER_H
#define V3_RELIABLE_TRACKER_H

#include <QByteArray>
#include <QHash>
#include <QList>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QtGlobal>

/// Message V3 en attente d'ACK applicatif pour un pair donné.
struct V3PendingSend
{
    QString    playerId;
    QString    messageId;     ///< Clé de dédup/confirmation (UUID enveloppe B1).
    QByteArray packet;        ///< Paquet fil complet (V3Protocol::pack), retransmissible tel quel.
    quint16    seq       = 0; ///< Dernière séquence reliable utilisée pour ce message.
    int        sendCount = 0; ///< Nombre d'envois effectués (1 = envoi initial).
    qint64     firstSentMs = 0; ///< Horodatage du premier envoi (horloge worker).
    qint64     nextRetryMs = 0; ///< Échéance de la prochaine retransmission.
};

class V3ReliableTracker
{
public:
    // ── Plafonds (échec définitif remonté au métier au-delà) ────────────────
    /// File d'attente max par pair : au-delà, l'envoi est refusé immédiatement.
    static constexpr int    kMaxPendingPerPlayer = 128;
    /// Tentatives d'envoi max (envoi initial inclus) avant échec définitif.
    static constexpr int    kMaxSendAttempts     = 8;
    /// Bornes du délai de retransmission (ms).
    static constexpr qint64 kRetryMinMs          = 200;
    static constexpr qint64 kRetryMaxMs          = 3000;
    /// Mémoire de dédup par pair (messageIds récents, éviction FIFO).
    static constexpr int    kDedupMemoryPerPlayer = 1024;

    /// Délai avant retransmission : adaptatif sur le RTT lissé de l'endpoint
    /// (2×RTT + marge), borné [kRetryMinMs, kRetryMaxMs], backoff exponentiel
    /// par tentative. `rttMs` peut être 0 (pas encore mesuré) → borne basse.
    static qint64 retryDelayMs(double rttMs, int sendCount);

    // ── Émission ────────────────────────────────────────────────────────────
    /// Enregistre un envoi initial. Retourne false si la file du pair est
    /// pleine ou si le messageId y est déjà (l'appelant remonte l'échec).
    bool trackSend(const QString &playerId, const QString &messageId,
                   const QByteArray &packet, quint16 seq,
                   qint64 nowMs, double rttMs);

    /// Confirme les séquences reliable ACKées (capturées avant clear_acks).
    /// Retourne les messageIds confirmés, retirés de la file.
    QStringList confirmAcks(const QString &playerId,
                            const quint16 *acks, int numAcks);

    /// Entrées dues pour retransmission à `nowMs`. Celles ayant épuisé
    /// kMaxSendAttempts sont RETIRÉES de la file et copiées dans `outFailed`.
    /// Les pointeurs retournés restent valides jusqu'à la prochaine mutation
    /// du tracker — à consommer immédiatement via markResent().
    QList<V3PendingSend *> collectDue(const QString &playerId, qint64 nowMs,
                                      QList<V3PendingSend> &outFailed);

    /// Met à jour une entrée après retransmission : nouvelle séquence reliable
    /// (l'ancienne est désindexée), compteur et prochaine échéance.
    void markResent(V3PendingSend *entry, quint16 newSeq,
                    qint64 nowMs, double rttMs);

    /// Retire un envoi en attente (abandon explicite, ex : pair injoignable).
    /// Retourne false si inconnu. Invalide les pointeurs de collectDue().
    bool removePending(const QString &playerId, const QString &messageId);

    // ── Réception (déduplication) ───────────────────────────────────────────
    /// Enregistre un messageId entrant. Retourne false si déjà vu (doublon à
    /// consommer sans livrer — la couche reliable l'ACKera quand même, ce qui
    /// stoppe les retransmissions de l'émetteur).
    bool registerIncoming(const QString &playerId, const QString &messageId);

    // ── Cycle de vie ────────────────────────────────────────────────────────
    /// Purge l'état d'un pair disparu. Retourne ses envois en attente (échecs
    /// définitifs à remonter au métier).
    QList<V3PendingSend> dropPlayer(const QString &playerId);

    /// Ids des pairs ayant au moins un envoi en attente.
    QStringList playersWithPending() const;

    /// Nombre d'envois en attente pour un pair (introspection/tests).
    int pendingCount(const QString &playerId) const;

private:
    struct PlayerState {
        QHash<QString, V3PendingSend> pending;   ///< messageId → entrée.
        QHash<quint16, QString> seqToMessage;    ///< séquence reliable → messageId.
        QSet<QString>   seenIncoming;            ///< dédup réception.
        QList<QString>  seenOrder;               ///< ordre FIFO pour l'éviction.
    };

    QHash<QString, PlayerState> m_players;
};

#endif // V3_RELIABLE_TRACKER_H
