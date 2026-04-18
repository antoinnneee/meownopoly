#ifndef EDITOR_OP_BUS_H
#define EDITOR_OP_BUS_H

#include <QObject>
#include <QJsonObject>
#include <QQmlEngine>

#include "editor_op_type.h"

/// Chokepoint unique par lequel transitent toutes les intentions de
/// mutation de l'éditeur de carte.
///
/// Phase 2 (actuelle) : simple enregistreur. `recordOp` loggue et réémet
///   un signal `opRecorded` ; la mutation réelle est toujours faite par QML
///   immédiatement après. Aucun changement de comportement pour l'utilisateur.
///
/// Phase 3+ : quand `EditorSession::active()` est vrai, `submitOp` décidera
///   d'envoyer au host et d'attendre le rebroadcast avant d'appliquer, etc.
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

    // ── Soumission locale (Phases 2+) ────────────────────────────────────────

    /// Soumet une op locale produite par une action utilisateur.
    /// - Phase 2 (EditorSession inactive) : loggue uniquement, via `opRecorded`.
    /// - Phase 3 (EditorSession active)  : loggue ET envoie l'op via
    ///   EditorSession::sendOp (client → host, ou broadcast si host).
    /// Si `isApplyingRemote` est vrai (replay d'une op distante), drop silencieux
    /// pour casser la boucle réseau.
    Q_INVOKABLE void submitOp(const QJsonObject &op);

    /// Alias historique (Phase 2). Équivalent à `submitOp`.
    Q_INVOKABLE void recordOp(const QJsonObject &op) { submitOp(op); }

    /// Entre manuellement en mode "apply-remote" pour un bloc de mutations
    /// QML (ex: réhydratation d'un FullSync). Tous les submitOp déclenchés
    /// pendant ce bloc seront droppés (pas de ré-émission réseau).
    /// Chaque begin doit être apparié à endApplyRemote().
    Q_INVOKABLE void beginApplyRemote();
    Q_INVOKABLE void endApplyRemote();

    // ── Helpers de construction d'op (pour QML) ──────────────────────────────

    /// Génère un nouvel UUID sérialisé (utilisé pour pré-minter un item côté
    /// client avant envoi réseau, cf. Phase 3).
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

signals:
    /// Émis pour chaque op enregistrée localement (utile pour logs/tests).
    void opRecorded(const QJsonObject &op);

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

    bool m_isApplyingRemote = false;
    int  m_applyDepth       = 0;  // compteur pour begin/end imbriqués
    bool m_sessionConnected = false;
};

#endif // EDITOR_OP_BUS_H
