/*
 *      Meownopoly V3 — chunking réparable (B4)
 *
 * Fragmentation fiable et réparable des messages V3 qui dépassent la taille
 * d'un paquet Catway. Remplace le chunking « fragile » de l'EditorSession
 * (`editor_session.cpp:191/489`), où la perte d'un seul fragment bloquait le
 * réassemblage à jamais (`buf.chunks.size() < buf.chunkCount` ne se débloque
 * jamais, l.507) : aucun identifiant de transfert stable, pas de détection des
 * manquants, pas de demande de renvoi, pas de checksum.
 *
 * Ce que B4 apporte (audit v3/10 §M3) :
 *   - ID de transfert stable (`transferId`, UUID) partagé par tous les frames ;
 *   - bitmap des chunks reçus côté récepteur → détection précise des manquants ;
 *   - demande ciblée des chunks manquants (`V3ChunkRequestFrame`) ;
 *   - timeout des transferts inactifs (émetteur ET récepteur) ;
 *   - checksum PAR chunk (corruption localisée → renvoi ciblé) ET checksum
 *     final du payload complet (intégrité de bout en bout, D39-esque).
 *
 * Comptabilité pure : aucune I/O réseau, aucune dépendance Qt GUI. L'émetteur
 * (V3ChunkSender) découpe et conserve les frames pour pouvoir les renvoyer ; le
 * récepteur (V3ChunkReceiver) réassemble et signale les manquants. Le câblage
 * réseau (encapsulation des frames dans l'enveloppe B1 avec un `kind` "chunk.*",
 * envoi via Catway, boucle de demande) est laissé au consommateur — comme
 * V3ReliableTracker (B2) et V3SupersedableState (B3), ces classes ne touchent
 * pas au transport et s'utilisent sur un seul thread (aucune synchro interne).
 *
 * Les frames exposent toJson/fromJson pour voyager tels quels dans le `payload`
 * d'une V3Envelope ; les fragments binaires y sont encodés en base64 (survie au
 * transport texte JSON, comme l'ancien OpChunk).
 */
#ifndef V3_CHUNK_TRANSFER_H
#define V3_CHUNK_TRANSFER_H

#include <QBitArray>
#include <QByteArray>
#include <QHash>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QStringList>
#include <QtGlobal>

// ── Frames fil ───────────────────────────────────────────────────────────────

/// Un fragment d'un transfert chunké. `fullHash` identifie le contenu complet
/// (partagé par tous les frames d'un transfert) et sert au checksum final ;
/// `chunkHash` protège ce fragment isolément (corruption localisée).
struct V3ChunkDataFrame
{
    QString    transferId;       ///< UUID du transfert (stable sur tous les frames).
    int        chunkIndex = -1;  ///< Index du fragment [0, chunkCount).
    int        chunkCount = 0;   ///< Nombre total de fragments du transfert.
    QString    fullHash;         ///< "sha256:<hex>" du payload complet reconstitué.
    QString    chunkHash;        ///< "sha256:<hex>" de ce fragment (intégrité locale).
    QByteArray fragment;         ///< Octets bruts de ce fragment.

    QJsonObject toJson() const;                                  ///< Fragment en base64.
    static bool fromJson(const QJsonObject &obj, V3ChunkDataFrame &out);
    bool isStructurallyValid() const; ///< Champs présents et cohérents (hors hash).
};

/// Demande de renvoi des fragments manquants d'un transfert, émise par le
/// récepteur vers l'émetteur.
struct V3ChunkRequestFrame
{
    QString    transferId;
    QList<int> missing;          ///< Index des fragments réclamés.

    QJsonObject toJson() const;
    static bool fromJson(const QJsonObject &obj, V3ChunkRequestFrame &out);
};

// ── Émetteur ─────────────────────────────────────────────────────────────────

/// Découpe un payload en fragments, les conserve, et sait les rejouer sur
/// demande (perte/corruption détectée par le récepteur). Un émetteur peut
/// suivre plusieurs transferts simultanés (clé = transferId).
class V3ChunkSender
{
public:
    /// Marge d'enveloppe recommandée à retrancher d'un budget de paquet pour
    /// obtenir la capacité utile d'un fragment (header JSON + base64 ≈ +33 %).
    static constexpr int kFrameOverheadBytes = 512;

    /// Découpe `payload` en fragments d'au plus `capacityBytes` octets bruts
    /// chacun, sous un nouveau `transferId`. Retourne le transferId (vide si
    /// `payload` vide ou `capacityBytes <= 0`). Le transfert est mémorisé pour
    /// permettre les renvois jusqu'à `complete()`/`drop()`.
    QString begin(const QByteArray &payload, int capacityBytes, qint64 nowMs);

    /// Tous les fragments d'un transfert, dans l'ordre — pour l'envoi initial.
    QList<V3ChunkDataFrame> allFrames(const QString &transferId) const;

    /// Les fragments d'indices donnés (réponse à une demande de manquants).
    /// Ignore silencieusement les index hors bornes. Met à jour l'horodatage
    /// d'activité du transfert (anti-timeout tant qu'il progresse).
    QList<V3ChunkDataFrame> framesFor(const QString &transferId,
                                      const QList<int> &indices, qint64 nowMs);

    /// Sert une demande de renvoi (raccourci sur framesFor).
    QList<V3ChunkDataFrame> serveRequest(const V3ChunkRequestFrame &req, qint64 nowMs);

    /// True si le transfert est encore suivi.
    bool has(const QString &transferId) const;

    /// Nombre de fragments d'un transfert (0 si inconnu).
    int chunkCount(const QString &transferId) const;

    /// Termine un transfert (récepteur a confirmé la complétion) : libère la
    /// mémoire des fragments. Retourne false si inconnu.
    bool complete(const QString &transferId);

    /// Abandon explicite (identique à complete côté mémoire).
    bool drop(const QString &transferId) { return complete(transferId); }

    /// Transferts sans activité (envoi/renvoi) depuis plus de `timeoutMs`.
    /// L'appelant décide d'abandonner et de remonter l'échec au métier.
    QStringList staleTransfers(qint64 nowMs, qint64 timeoutMs) const;

    /// Nombre de transferts en cours (introspection / tests).
    int activeCount() const { return m_transfers.size(); }

private:
    struct SendState {
        QList<V3ChunkDataFrame> frames;
        qint64 lastActivityMs = 0;
    };
    QHash<QString, SendState> m_transfers;
};

// ── Récepteur ────────────────────────────────────────────────────────────────

/// Résultat de l'acceptation d'un fragment.
enum class V3ChunkAccept {
    InProgress,       ///< Fragment intégré, transfert incomplet.
    Complete,         ///< Dernier fragment reçu et checksum final OK → payload prêt.
    Duplicate,        ///< Fragment déjà reçu (réordonnancement/duplication) — ignoré.
    Corrupt,          ///< chunkHash incohérent → fragment rejeté, reste « manquant ».
    Invalid,          ///< Frame malformé ou incohérent avec le transfert en cours.
    ChecksumMismatch  ///< Tous reçus mais checksum FINAL faux → bitmap purgé,
                      ///< transfert rouvert pour re-demande complète.
};

/// Réassemble un transfert chunké : bitmap des reçus, détection des manquants,
/// vérification d'intégrité par fragment puis globale.
class V3ChunkReceiver
{
public:
    /// Intègre un fragment. En cas de `Complete`, `outPayload` reçoit le payload
    /// complet reconstitué et le transfert est purgé. Les autres verdicts
    /// laissent `outPayload` inchangé. `nowMs` horodate l'activité (anti-timeout).
    V3ChunkAccept accept(const V3ChunkDataFrame &frame, qint64 nowMs,
                         QByteArray &outPayload);

    /// Index des fragments encore attendus pour un transfert (vide si inconnu
    /// ou complet). C'est la charge utile d'un V3ChunkRequestFrame.
    QList<int> missing(const QString &transferId) const;

    /// Construit une demande de renvoi des manquants (transferId + missing()).
    /// `requested` vaut true si au moins un fragment manque.
    V3ChunkRequestFrame buildRequest(const QString &transferId, bool &requested) const;

    /// True si un réassemblage est en cours pour ce transfert.
    bool has(const QString &transferId) const;

    /// Nombre de fragments déjà reçus / attendus (0 si inconnu).
    int receivedCount(const QString &transferId) const;
    int expectedCount(const QString &transferId) const;

    /// Abandonne un réassemblage (timeout, transfert annulé). Retourne false si
    /// inconnu.
    bool drop(const QString &transferId);

    /// Réassemblages sans nouveau fragment depuis plus de `timeoutMs`.
    QStringList staleTransfers(qint64 nowMs, qint64 timeoutMs) const;

    /// Nombre de réassemblages en cours (introspection / tests).
    int activeCount() const { return m_transfers.size(); }

private:
    struct RecvState {
        int                        chunkCount = 0;
        QString                    fullHash;
        QBitArray                  received;      ///< bit i = fragment i intégré.
        QList<QByteArray>          fragments;     ///< taille chunkCount, index-adressée.
        int                        haveCount = 0;
        qint64                     lastActivityMs = 0;
    };
    QHash<QString, RecvState> m_transfers;
};

// ── Utilitaire ───────────────────────────────────────────────────────────────

namespace V3ChunkHash {
/// "sha256:<hex>" d'un buffer brut — même forme que V3Envelope::payloadHash.
QString of(const QByteArray &bytes);
}

#endif // V3_CHUNK_TRANSFER_H
