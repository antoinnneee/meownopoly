/*
 *      Meownopoly V3 — état supersédable séquencé (B3)
 *
 * Comptabilité pure (aucun appel réseau, aucune dépendance Qt GUI) pour la
 * partie « état supersédable » de la fiabilité applicative V3 (M3, audit E06/
 * F06). Complément de V3ReliableTracker (B2) : là où B2 garantit qu'un message
 * *commit* (proposition, verdict, transaction) est livré une fois et une seule,
 * B3 traite l'autre régime — les mises à jour d'état à haute cadence, dont seule
 * la plus récente compte.
 *
 * Principe (doc v3/10 §2, §M3 ; D35/D39) :
 *   - chaque valeur d'état est repérée par une CLÉ opaque (ex. "<uuidTuile>/hp")
 *     et porte une SÉQUENCE monotone attribuée par le producteur ;
 *   - à réception, une mise à jour n'est appliquée que si sa séquence est
 *     strictement supérieure à la dernière appliquée pour cette clé ; l'ancienne
 *     (réordonnancée, retardée, dupliquée) est ignorée sans effet — « drop de
 *     l'ancien » ;
 *   - la perte d'un delta ne casse rien : elle est réparée par un SNAPSHOT
 *     périodique / à la demande, qui rétablit un socle cohérent de séquences.
 *
 * Ce composant ne stocke PAS les valeurs applicatives — uniquement les
 * séquences qui décident de l'ordonnancement. Le consommateur (M6-B / bus
 * d'état runtime, T3-3) porte les valeurs et interroge ce tracker pour savoir
 * s'il doit appliquer, ignorer ou réparer. Il est ainsi générique (métier
 * agnostique) et réutilisable pour toute famille d'état supersédable V3.
 *
 * Threading : aucune synchronisation interne — à posséder et utiliser sur un
 * seul thread (comme V3ReliableTracker côté worker, ou côté hôte du bus d'état).
 *
 * Le champ `seq` provient typiquement de l'enveloppe commune V3 (B1,
 * V3Envelope::seq, monotone par (session, émetteur)) mais rien n'impose cette
 * origine : toute séquence monotone par producteur convient.
 */
#ifndef V3_SUPERSEDABLE_STATE_H
#define V3_SUPERSEDABLE_STATE_H

#include <QHash>
#include <QList>
#include <QString>
#include <QStringList>
#include <QtGlobal>

/// Verdict rendu par V3SupersedableState::offer() pour une mise à jour entrante.
enum class V3SupersedeVerdict {
    Applied,     ///< Séquence plus récente : à appliquer, dernière séquence mise à jour.
    Duplicate,   ///< Séquence identique à la dernière appliquée : rien à faire.
    Stale        ///< Séquence plus ancienne : à ignorer (« drop de l'ancien »).
};

/// Photographie d'un socle de séquences, échangée pour la réparation. Le
/// producteur l'émet périodiquement ou sur demande ; le récepteur la passe à
/// applySnapshot() pour combler les deltas perdus. `snapshotSeq` est une
/// séquence de snapshot globale monotone (par producteur) qui ordonne les
/// snapshots entre eux — un snapshot plus ancien que le dernier appliqué est
/// ignoré. `keySeqs` porte, par clé, la séquence de la dernière valeur reflétée
/// dans ce snapshot.
struct V3StateSnapshot {
    quint64                  snapshotSeq = 0;
    QHash<QString, quint64>  keySeqs;
};

class V3SupersedableState
{
public:
    // ── Réception de deltas ──────────────────────────────────────────────────
    /// Décide du sort d'une mise à jour {clé, séquence} SANS muter l'état :
    /// utile pour pré-filtrer avant de décoder la valeur. `Applied` signifie
    /// seulement « serait appliquée » ici.
    V3SupersedeVerdict evaluate(const QString &key, quint64 seq) const;

    /// Enregistre une mise à jour entrante et rend son verdict. En cas de
    /// `Applied`, la dernière séquence de la clé devient `seq`. `Duplicate` et
    /// `Stale` ne mutent rien. C'est le point d'entrée normal du récepteur.
    V3SupersedeVerdict offer(const QString &key, quint64 seq);

    /// Dernière séquence appliquée pour une clé (0 si jamais vue).
    quint64 lastSeq(const QString &key) const;

    /// True si une valeur a déjà été appliquée pour cette clé.
    bool hasKey(const QString &key) const;

    // ── Émission de deltas ───────────────────────────────────────────────────
    /// Alloue la prochaine séquence pour une clé côté producteur et la mémorise
    /// comme dernière appliquée (l'émetteur reflète immédiatement son propre
    /// état). Garantit la monotonie même si des snapshots ont relevé le socle.
    quint64 nextSeq(const QString &key);

    // ── Réparation par snapshot ──────────────────────────────────────────────
    /// Applique un snapshot de réparation. Ignoré (retourne false) si son
    /// `snapshotSeq` n'est pas strictement supérieur au dernier snapshot
    /// appliqué (snapshot rejoué/obsolète). Sinon, fusionne par MAXIMUM par clé
    /// (un delta déjà reçu plus récent que le snapshot n'est jamais régressé) et
    /// relève le socle de snapshot. Retourne true si appliqué.
    bool applySnapshot(const V3StateSnapshot &snapshot);

    /// Capture l'état courant sous forme de snapshot, en lui attribuant la
    /// `snapshotSeq` fournie (à faire croître par le producteur à chaque
    /// capture, pour l'ordonnancement côté récepteurs).
    V3StateSnapshot captureSnapshot(quint64 snapshotSeq) const;

    /// Séquence du dernier snapshot appliqué (ou capturé via captureSnapshot
    /// n'a pas d'effet ici) — 0 si aucun.
    quint64 lastSnapshotSeq() const { return m_snapshotSeq; }

    // ── Cycle de vie ─────────────────────────────────────────────────────────
    /// Oublie une clé (ex. tuile supprimée). Retourne false si inconnue. Une
    /// mise à jour ultérieure repartira d'une dernière séquence de 0.
    bool dropKey(const QString &key);

    /// Oublie toutes les clés commençant par `prefix` (ex. "<uuidTuile>/" pour
    /// purger toutes les valeurs d'une tuile). Retourne le nombre de clés
    /// retirées.
    int dropKeysWithPrefix(const QString &prefix);

    /// Réinitialise totalement le tracker (clés + socle de snapshot).
    void clear();

    /// Nombre de clés suivies (introspection / tests).
    int keyCount() const { return m_keySeq.size(); }

    /// Liste des clés suivies (introspection / tests).
    QStringList keys() const;

private:
    QHash<QString, quint64> m_keySeq;       ///< clé → dernière séquence appliquée.
    quint64                 m_snapshotSeq = 0; ///< séquence du dernier snapshot appliqué.
};

#endif // V3_SUPERSEDABLE_STATE_H
