#ifndef MAP_TRANSACTION_H
#define MAP_TRANSACTION_H

// M4 (T3-1, plan V3 doc 15) — transaction atomique prepare/commit/rollback
// sur la Map de l'éditeur.
//
// Avant M4, Game::beginTransaction() se résumait à un QUuid : les mutations
// étaient appliquées au fil de l'eau, poussées immédiatement sur la pile undo
// et bufferisées côté réseau, sans rollback possible ni résultat global
// (audit doc v3 10 §3 : « groupées, pas atomiques »).
//
// MapTransaction porte le nouvel invariant « tout ou rien » :
//  - `prevalidateBatch` : phase *prepare* — prévalidation complète d'un lot
//    (UUID, existence, cohérence) AVANT la première mutation, par simulation
//    du write-set sans toucher la Map. C'est la voie des propositions V3.
//  - `validateDelta` + `recordApplied` : voie éditeur historique (mutations
//    au fil de l'eau pilotées par QML). Chaque delta est validé au moment où
//    il traverse Game::updateMap ; l'atomicité est alors garantie par le
//    rollback via les inverses `before` d'EditDelta.
//  - `verifyWriteSet` : au commit, vérifie qu'aucune mutation concurrente
//    (typiquement applyRemoteDelta d'un pair) n'a écrasé une tuile touchée
//    par la transaction. Conflit → échec explicite, jamais d'écrasement
//    silencieux.
//  - `rollback` : applique les inverses `before` en ordre inverse.
//
// ATTENTION — triple rôle de l'identifiant (m_id == groupId d'EditDelta) :
//  1. identité de la transaction (Game::m_currentTransaction) ;
//  2. groupement undo/redo dans Map::m_undoStack (batch pop contigu) ;
//  3. clé du batch réseau dans EditorOpBus::m_pendingGroups (flushGroup).
// Tout chemin d'échec doit nettoyer LES TROIS : ne rien pousser sur la pile
// undo, discardGroup() côté op bus, et détruire la transaction. Un commit
// partiel sur un seul des trois axes ré-ouvre le bug R14 (transaction
// groupée ≠ atomique).

#include <QUuid>
#include <QList>
#include <QHash>
#include <QString>
#include <QJsonObject>

#include "game/map/editdelta.h"

class Map;

namespace MeowTx {

class MapTransaction
{
public:
    explicit MapTransaction(const QUuid &id);

    QUuid id() const { return m_id; }

    /// Vrai si une opération du lot a été rejetée en cours de route
    /// (validation échouée dans Game::updateMap). Sticky : le commit
    /// devient alors un rollback global, conformément au critère M4
    /// « injection d'une opération invalide au milieu d'un lot : aucune
    /// mutation finale ».
    bool failed() const { return m_failed; }
    QString failureReason() const { return m_failureReason; }
    void markFailed(const QString &reason);

    bool isEmpty() const { return m_deltas.isEmpty(); }
    const QList<EditDelta> &deltas() const { return m_deltas; }

    /// Enregistre un delta DÉJÀ appliqué à la Map (voie fil-de-l'eau).
    /// Le delta n'est PAS poussé sur la pile undo ici : la matérialisation
    /// du groupe undo est différée au commit (Game::commitTransaction),
    /// sinon un rollback devrait dépiler Map::m_undoStack.
    void recordApplied(const EditDelta &delta);

    // ── Phase prepare ────────────────────────────────────────────────────────

    /// Valide un delta contre l'état courant de la Map, sans muter.
    /// Volontairement tolérant aux idempotences historiques de l'éditeur
    /// (TileAdded sur tuile déjà présente = no-op accepté) : ne rejette que
    /// les corruptions franches.
    static bool validateDelta(Map *map, const EditDelta &delta,
                              QString *reasonOut = nullptr);

    /// Prévalidation complète d'un lot AVANT toute mutation : simule
    /// l'existence des tuiles au fil du lot (Added/Deleted enchaînés) et
    /// rejette globalement si UNE op est invalide. Voie prepare des
    /// propositions V3 (Game::prepareTransaction).
    static bool prevalidateBatch(Map *map, const QList<EditDelta> &deltas,
                                 QString *reasonOut = nullptr);

    // ── Phase commit ─────────────────────────────────────────────────────────

    /// Write-set check : pour chaque tuile touchée, l'état courant de la Map
    /// doit encore correspondre au dernier `after` appliqué par la
    /// transaction (et les tuiles supprimées doivent être absentes). Un
    /// écart signifie qu'une mutation concurrente (op distante) s'est
    /// intercalée → conflit, le commit doit échouer sans écraser.
    bool verifyWriteSet(Map *map, QString *conflictOut = nullptr) const;

    // ── Phase rollback ───────────────────────────────────────────────────────

    /// Restaure l'état d'avant transaction : applique les inverses `before`
    /// des deltas enregistrés, en ordre inverse. `touchedOut` collecte les
    /// UUID des tuiles impactées (pour Map::afterRestoration côté QML).
    void rollback(Map *map, QList<QUuid> *touchedOut = nullptr);

private:
    /// Sérialisation canonique d'un QJsonObject pour comparaison d'états
    /// (QJsonObject trie ses clés → la forme compacte est canonique).
    static QString canonicalJson(const QJsonObject &obj);

    QUuid m_id;
    bool m_failed = false;
    QString m_failureReason;
    QList<EditDelta> m_deltas;
};

} // namespace MeowTx

#endif // MAP_TRANSACTION_H
