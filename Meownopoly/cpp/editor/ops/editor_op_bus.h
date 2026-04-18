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

public:
    static void registerQml();
    static EditorOpBus *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    // ── Enregistrement local (Phase 2) ───────────────────────────────────────

    /// Enregistre une op locale. Loggue et réémet via `opRecorded`.
    /// En Phase 2 cette méthode n'applique rien — c'est l'appelant QML qui
    /// continue de réaliser la mutation comme avant.
    Q_INVOKABLE void recordOp(const QJsonObject &op);

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
    /// Émis pour chaque op enregistrée (utile pour logs, tests, UI de debug).
    void opRecorded(const QJsonObject &op);

private:
    explicit EditorOpBus(QObject *parent = nullptr);
    static EditorOpBus *m_pThis;
};

#endif // EDITOR_OP_BUS_H
