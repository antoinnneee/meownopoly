#ifndef EDITOR_OP_BUS_H
#define EDITOR_OP_BUS_H

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QHash>
#include <QUuid>
#include <QQmlEngine>
#include <QElapsedTimer>

#include "editor_op_type.h"

/// Chokepoint unique par lequel transitent toutes les intentions de
/// mutation de l'éditeur de carte. En monoposte, `submitOp` loggue et émet
/// `opRecorded` ; en collaboratif (EditorSession active), il envoie aussi
/// l'op au host (ou broadcast si host) et attend le rebroadcast pour l'apply.
///
/// Exposé à QML comme singleton pour pouvoir être invoqué depuis n'importe
/// quel handler (TileLogic, MouseLogic_Selection, panels CCP_/ASP_/VEP_).
class EditorOpBus : public QObject
{
    Q_OBJECT

    /// Vrai pendant qu'une op distante est en cours d'application locale.
    /// Utilisé comme garde pour éviter que les mutations déclenchées par
    /// le replay remote ne re-soumettent une op (boucle infinie réseau).
    Q_PROPERTY(bool isApplyingRemote READ isApplyingRemote NOTIFY isApplyingRemoteChanged)

public:
    static void registerQml();
    static EditorOpBus *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    bool isApplyingRemote() const { return m_isApplyingRemote; }

    // ── Soumission locale ─────────────────────────────────────────────────────

    /// Soumet une op locale produite par une action utilisateur. Loggue via
    /// `opRecorded`, et si la session collaborative est active, envoie l'op
    /// à EditorSession (client → host, ou broadcast si host).
    /// Si `isApplyingRemote` est vrai (replay d'une op distante), drop silencieux
    /// pour casser la boucle réseau.
    Q_INVOKABLE void submitOp(const QJsonObject &op);

    /// Alias historique. Équivalent à `submitOp`.
    Q_INVOKABLE void recordOp(const QJsonObject &op) { submitOp(op); }

    /// Entre manuellement en mode "apply-remote" pour un bloc de mutations
    /// QML (ex: réhydratation d'un FullSync). Tous les submitOp déclenchés
    /// pendant ce bloc seront droppés (pas de ré-émission réseau).
    /// Chaque begin doit être apparié à endApplyRemote().
    Q_INVOKABLE void beginApplyRemote();
    Q_INVOKABLE void endApplyRemote();

    // ── Undo/Redo (v1, mode collaboratif uniquement) ─────────────────────────

    /// Variante de submitOp qui empile aussi l'op inverse dans la pile d'undo.
    /// À utiliser depuis QML pour les actions utilisateur locales dont on peut
    /// construire un inverse au moment du submit (Create/Delete/Link/Unlink v1).
    /// `inverseOp` est purement local — jamais envoyé au réseau.
    Q_INVOKABLE void submitOpWithUndo(const QJsonObject &op,
                                      const QJsonObject &inverseOp);

    /// Déclenche l'annulation de la dernière action locale en mode collaboratif.
    /// Pop de undoStack, submit de l'inverse au réseau, push sur redoStack.
    /// No-op si la pile est vide ou si EditorSession est inactif.
    Q_INVOKABLE void undo();

    /// Déclenche le refaire : pop de redoStack, submit de l'op originale,
    /// push sur undoStack.
    Q_INVOKABLE void redo();

    /// Vide les deux piles. Appelé automatiquement quand EditorSession stop.
    Q_INVOKABLE void clearUndo();

    Q_INVOKABLE int undoDepth() const { return m_undoStack.size(); }
    Q_INVOKABLE int redoDepth() const { return m_redoStack.size(); }

    // ── Helpers de construction d'op (pour QML) ──────────────────────────────

    /// Génère un nouvel UUID sérialisé (utilisé pour pré-minter un item côté
    /// client avant envoi réseau).
    Q_INVOKABLE QString newUuid() const;

    /// Construit une op CreateItem { op, item }.
    Q_INVOKABLE QJsonObject makeCreateOp(const QJsonObject &itemJson) const;

    /// Construit une op DeleteItem { op, target }.
    Q_INVOKABLE QJsonObject makeDeleteOp(const QString &uuid) const;

    /// Construit une op MoveItem { op, target, gridX, gridY, zOrder }.
    Q_INVOKABLE QJsonObject makeMoveOp(const QString &uuid,
                                       qreal gridX, qreal gridY,
                                       int zOrder = -1) const;

    /// Construit une op LinkItems { op, source, target, kind }.
    Q_INVOKABLE QJsonObject makeLinkOp(const QString &source,
                                       const QString &target,
                                       const QString &kind) const;

    /// Construit une op UnlinkItems { op, source, target, kind }.
    Q_INVOKABLE QJsonObject makeUnlinkOp(const QString &source,
                                         const QString &target,
                                         const QString &kind) const;

    // ── Player Config Panel (PCP_*) ──────────────────────────────────────────

    /// Construit une op AddPlayerProfile { op, profile }.
    Q_INVOKABLE QJsonObject makeAddPlayerProfileOp(const QJsonObject &profile) const;

    /// Construit une op RemovePlayerProfile { op, id }.
    Q_INVOKABLE QJsonObject makeRemovePlayerProfileOp(const QString &id) const;

    /// Construit une op UpdatePlayerProfile { op, id, fields }.
    Q_INVOKABLE QJsonObject makeUpdatePlayerProfileOp(const QString &id,
                                                      const QJsonObject &fields) const;

    /// Construit une op ReorderPlayerProfile { op, id, newIndex }.
    Q_INVOKABLE QJsonObject makeReorderPlayerProfileOp(const QString &id,
                                                       int newIndex) const;

    /// Construit une op SetMapPlayerLimits { op, ...fields }.
    /// `fields` peut contenir minPlayers et/ou maxPlayers.
    Q_INVOKABLE QJsonObject makeSetMapPlayerLimitsOp(const QJsonObject &fields) const;

    /// Construit une op SetNpcParameter { op, target, fields }.
    Q_INVOKABLE QJsonObject makeSetNpcParameterOp(const QString &uuid,
                                                  const QJsonObject &fields) const;

    /// Construit une op SetEnemyParameter { op, target, fields }.
    Q_INVOKABLE QJsonObject makeSetEnemyParameterOp(const QString &uuid,
                                                    const QJsonObject &fields) const;

    /// Construit une op SetPhysicalObjectParameter { op, target, fields }.
    Q_INVOKABLE QJsonObject makeSetPhysicalObjectParameterOp(const QString &uuid,
                                                             const QJsonObject &fields) const;

    // ── Pattern B : broadcast d'un EditDelta générique ───────────────────────

    /// Construit une op ApplyState depuis un delta. Si `groupId` n'est pas
    /// nul, l'op est bufferisée dans m_pendingGroups[groupId] ; sinon elle
    /// est submittée immédiatement via submitOp.
    /// Appelé par Game::updateMap (applyBefore=false, forward) et par
    /// Game::askPreview/askNext (applyBefore=true pour undo, false pour redo).
    void submitFromDelta(int type,
                         const QUuid &tileId,
                         const QUuid &groupId,
                         const QJsonObject &before,
                         const QJsonObject &after,
                         bool applyBefore);

    /// Flush toutes les ops accumulées pour `groupId` en un seul event
    /// ApplyStateBatch (liste d'ApplyState). Appelé par Game::commitTransaction.
    void flushGroup(const QUuid &groupId);

signals:
    /// Émis pour chaque op enregistrée localement (utile pour logs/tests).
    void opRecorded(const QJsonObject &op);

    /// une soumission locale a été rejetée par le rate-limit client
    /// (avant même d'atteindre le réseau). QML peut afficher un toast.
    void localThrottled(const QJsonObject &op);

    /// Émis quand une op distante est reçue et doit être appliquée par QML.
    /// QML doit mettre isApplyingRemote=true via beginApplyRemote() avant la
    /// mutation, et endApplyRemote() juste après — automatique via le flag
    /// interne qui est vrai pendant l'émission du signal.
    void remoteOpReceived(const QJsonObject &op);

    void isApplyingRemoteChanged();

private:
    explicit EditorOpBus(QObject *parent = nullptr);
    static EditorOpBus *m_pThis;

    /// Connecte les signaux d'EditorSession (appelé à la première instance).
    void connectToEditorSession();

    /// Handler de réception — posée en slot privé pour éviter une lambda-connect.
    void onSessionOpReceived(const QString &senderId, const QJsonObject &op);

    /// Entrée d'undo : op originale + inverse. L'originale est conservée
    /// pour pouvoir "refaire" (redo) après un undo.
    struct UndoEntry {
        QJsonObject op;
        QJsonObject inverseOp;
    };

    bool m_isApplyingRemote = false;
    int  m_applyDepth       = 0;  // compteur pour begin/end imbriqués
    bool m_sessionConnected = false;
    bool m_isUndoingLocal   = false;  // suppresseur d'ajout undo pendant undo/redo
    QList<UndoEntry> m_undoStack;
    QList<UndoEntry> m_redoStack;

    // Ops en attente, indexées par groupId de transaction (Game::beginTransaction).
    // Vidées en un seul batch via flushGroup(groupId) à commitTransaction.
    QHash<QUuid, QList<QJsonObject>> m_pendingGroups;

    // Rate-limit local (token bucket). Évite de noyer la file réseau quand
    // un script QML boucle sur submitOp.
    double m_localTokens   = 60.0;
    qint64 m_localLastMs   = 0;
    QElapsedTimer m_localClock;
    static constexpr double k_localRatePerSec = 30.0;
    static constexpr double k_localBurst      = 60.0;
};

#endif // EDITOR_OP_BUS_H
