#include "editor_op_bus.h"

#include "editor/network/editor_session.h"

#include <QDebug>
#include <QJsonDocument>
#include <QUuid>

EditorOpBus *EditorOpBus::m_pThis = nullptr;

EditorOpBus::EditorOpBus(QObject *parent) : QObject(parent) {}

EditorOpBus *EditorOpBus::instance()
{
    if (!m_pThis) {
        m_pThis = new EditorOpBus();
        m_pThis->connectToEditorSession();
    }
    return m_pThis;
}

QObject *EditorOpBus::qmlInstance(QQmlEngine * /*engine*/, QJSEngine * /*scriptEngine*/)
{
    return instance();
}

void EditorOpBus::registerQml()
{
    qmlRegisterSingletonType<EditorOpBus>("EditorOpBus", 1, 0, "EditorOpBus",
                                          &EditorOpBus::qmlInstance);
    qmlRegisterUncreatableMetaObject(EditorOpType::staticMetaObject,
                                     "EditorOpBus", 1, 0,
                                     "EditorOpType",
                                     "Error: only enums");
}

void EditorOpBus::connectToEditorSession()
{
    if (m_sessionConnected) return;
    EditorSession *sess = EditorSession::instance();
    connect(sess, &EditorSession::opReceived,
            this, &EditorOpBus::onSessionOpReceived);
    m_sessionConnected = true;
}

void EditorOpBus::submitOp(const QJsonObject &op)
{
    // Garde anti-boucle : si on est en train d'appliquer une op distante,
    // les mutations QML vont traverser ce chokepoint mais ne doivent pas
    // être re-soumises au réseau.
    if (m_isApplyingRemote) return;

    EditorSession *sess = EditorSession::instance();

    // rate-limit local (collab uniquement). En monoposte, pas de
    // raison de throttle — l'autosave encaisse déjà les rafales.
    if (sess->active()) {
        if (!m_localClock.isValid()) { m_localClock.start(); m_localLastMs = 0; }
        const qint64 nowMs = m_localClock.elapsed();
        const double dt = (nowMs - m_localLastMs) / 1000.0;
        m_localTokens = qMin(k_localBurst, m_localTokens + dt * k_localRatePerSec);
        m_localLastMs = nowMs;
        if (m_localTokens < 1.0) {
            qWarning().noquote() << "[EditorOpBus] local throttle — drop op"
                                 << QJsonDocument(op).toJson(QJsonDocument::Compact);
            emit localThrottled(op);
            return;
        }
        m_localTokens -= 1.0;
    }

    qDebug().noquote() << "[EditorOpBus] submit"
                       << QJsonDocument(op).toJson(QJsonDocument::Compact);
    emit opRecorded(op);

    // si la session collaborative est active, envoyer l'op.
    if (sess->active()) {
        sess->sendOp(op);
    }
}

void EditorOpBus::onSessionOpReceived(const QString &senderId, const QJsonObject &op)
{
    Q_UNUSED(senderId);
    // log structuré {seq, by, type} pour post-mortem.
    qDebug().noquote() << "[EditorOpBus] apply seq="
                       << op.value("_seq").toDouble(0)
                       << "by=" << op.value("_by").toString(senderId)
                       << "type=" << op.value("op").toInt();

    // Positionne le flag pour que les mutations QML déclenchées par le replay
    // soient droppées dans submitOp (empêche la ré-émission réseau).
    beginApplyRemote();
    emit remoteOpReceived(op);
    endApplyRemote();
}

void EditorOpBus::beginApplyRemote()
{
    if (m_applyDepth++ == 0) {
        m_isApplyingRemote = true;
        emit isApplyingRemoteChanged();
    }
}

void EditorOpBus::endApplyRemote()
{
    if (m_applyDepth <= 0) {
        qWarning() << "[EditorOpBus] endApplyRemote called without matching begin";
        return;
    }
    if (--m_applyDepth == 0) {
        m_isApplyingRemote = false;
        emit isApplyingRemoteChanged();
    }
}

// ── Undo/Redo ────────────────────────────────────────────────────────────────

void EditorOpBus::submitOpWithUndo(const QJsonObject &op, const QJsonObject &inverseOp)
{
    // Soumettre d'abord l'op à la couche normale (loggue + réseau).
    // Si m_isApplyingRemote, submitOp drop ; on ne pousse pas non plus d'undo.
    if (m_isApplyingRemote) return;

    submitOp(op);

    // Nouvelle action utilisateur : pousse sur undoStack, vide redoStack.
    // Skip si on est en train de rejouer un undo/redo (le flag ci-dessous).
    if (m_isUndoingLocal) return;

    m_undoStack.append({ op, inverseOp });
    if (!m_redoStack.isEmpty()) m_redoStack.clear();
}

void EditorOpBus::undo()
{
    if (m_undoStack.isEmpty()) {
        qDebug() << "[EditorOpBus] undo: pile vide";
        return;
    }
    const UndoEntry entry = m_undoStack.takeLast();

    // Le submit de l'inverse ne doit pas re-pusher sur undoStack, mais doit
    // en revanche être envoyé au réseau. On garde redo de l'op originale.
    m_isUndoingLocal = true;
    submitOp(entry.inverseOp);
    m_isUndoingLocal = false;

    m_redoStack.append(entry);
    qDebug() << "[EditorOpBus] undo (undo=" << m_undoStack.size()
             << "redo=" << m_redoStack.size() << ")";
}

void EditorOpBus::redo()
{
    if (m_redoStack.isEmpty()) {
        qDebug() << "[EditorOpBus] redo: pile vide";
        return;
    }
    const UndoEntry entry = m_redoStack.takeLast();

    m_isUndoingLocal = true;
    submitOp(entry.op);
    m_isUndoingLocal = false;

    m_undoStack.append(entry);
    qDebug() << "[EditorOpBus] redo (undo=" << m_undoStack.size()
             << "redo=" << m_redoStack.size() << ")";
}

void EditorOpBus::clearUndo()
{
    m_undoStack.clear();
    m_redoStack.clear();
}

QString EditorOpBus::newUuid() const
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

QJsonObject EditorOpBus::makeCreateOp(const QJsonObject &itemJson) const
{
    return QJsonObject{
        { "op",   static_cast<int>(EditorOpType::CreateItem) },
        { "item", itemJson },
    };
}

QJsonObject EditorOpBus::makeDeleteOp(const QString &uuid) const
{
    return QJsonObject{
        { "op",     static_cast<int>(EditorOpType::DeleteItem) },
        { "target", uuid },
    };
}

QJsonObject EditorOpBus::makeMoveOp(const QString &uuid,
                                    qreal gridX, qreal gridY,
                                    int zOrder) const
{
    QJsonObject op{
        { "op",     static_cast<int>(EditorOpType::MoveItem) },
        { "target", uuid },
        { "gridX",  gridX },
        { "gridY",  gridY },
    };
    if (zOrder >= 0) op.insert("zOrder", zOrder);
    return op;
}

QJsonObject EditorOpBus::makeLinkOp(const QString &source,
                                    const QString &target,
                                    const QString &kind) const
{
    return QJsonObject{
        { "op",     static_cast<int>(EditorOpType::LinkItems) },
        { "source", source },
        { "target", target },
        { "kind",   kind },
    };
}

QJsonObject EditorOpBus::makeUnlinkOp(const QString &source,
                                      const QString &target,
                                      const QString &kind) const
{
    return QJsonObject{
        { "op",     static_cast<int>(EditorOpType::UnlinkItems) },
        { "source", source },
        { "target", target },
        { "kind",   kind },
    };
}

// ── Player Config Panel (PCP_*) ──────────────────────────────────────────────

QJsonObject EditorOpBus::makeAddPlayerProfileOp(const QJsonObject &profile) const
{
    return QJsonObject{
        { "op",      static_cast<int>(EditorOpType::AddPlayerProfile) },
        { "profile", profile },
    };
}

QJsonObject EditorOpBus::makeRemovePlayerProfileOp(const QString &id) const
{
    return QJsonObject{
        { "op", static_cast<int>(EditorOpType::RemovePlayerProfile) },
        { "id", id },
    };
}

QJsonObject EditorOpBus::makeUpdatePlayerProfileOp(const QString &id,
                                                   const QJsonObject &fields) const
{
    return QJsonObject{
        { "op",     static_cast<int>(EditorOpType::UpdatePlayerProfile) },
        { "id",     id },
        { "fields", fields },
    };
}

QJsonObject EditorOpBus::makeReorderPlayerProfileOp(const QString &id,
                                                    int newIndex) const
{
    return QJsonObject{
        { "op",       static_cast<int>(EditorOpType::ReorderPlayerProfile) },
        { "id",       id },
        { "newIndex", newIndex },
    };
}

QJsonObject EditorOpBus::makeSetMapPlayerLimitsOp(const QJsonObject &fields) const
{
    QJsonObject op{
        { "op", static_cast<int>(EditorOpType::SetMapPlayerLimits) },
    };
    // On ne recopie que les champs reconnus pour éviter de polluer la wire.
    if (fields.contains("minPlayers")) op.insert("minPlayers", fields.value("minPlayers"));
    if (fields.contains("maxPlayers")) op.insert("maxPlayers", fields.value("maxPlayers"));
    return op;
}

QJsonObject EditorOpBus::makeSetNpcParameterOp(const QString &uuid,
                                               const QJsonObject &fields) const
{
    return QJsonObject{
        { "op",     static_cast<int>(EditorOpType::SetNpcParameter) },
        { "target", uuid },
        { "fields", fields },
    };
}

// ── Pattern B : broadcast d'un EditDelta générique ───────────────────────────

void EditorOpBus::submitFromDelta(int type,
                                  const QUuid &tileId,
                                  const QUuid &groupId,
                                  const QJsonObject &before,
                                  const QJsonObject &after,
                                  bool applyBefore)
{
    if (m_isApplyingRemote) {
        qDebug() << "[OpBus] submitFromDelta dropped — isApplyingRemote";
        return;
    }
    if (!EditorSession::instance()->active()) {
        qDebug() << "[OpBus] submitFromDelta dropped — EditorSession inactive";
        return;
    }
    qDebug() << "[OpBus] submitFromDelta type=" << type
             << " uuid=" << tileId.toString()
             << " groupId=" << groupId.toString()
             << " (pending queue)";

    // Économie de bande passante : on n'envoie que le côté qu'on va appliquer.
    // applyBefore=false (forward: pose/modif/suppr/undo-redo forward) → only `after`.
    // applyBefore=true  (undo local broadcast) → only `before`.
    // Pour TileAdded forward : after non vide, before vide → envoyer after.
    // Pour TileDeleted forward : before non vide (payload pour undo côté peer), after vide.
    //   Le peer applyBefore=false lit after (vide) → removeTile par UUID. before est inutile
    //   pour le peer distant (son propre undo ne touche pas à ce delta), on peut skip.
    QJsonObject op{
        { "op",          static_cast<int>(EditorOpType::ApplyState) },
        { "type",        type },
        { "tileId",      tileId.toString() },
        { "groupId",     groupId.toString() },
        { "applyBefore", applyBefore },
    };
    if (applyBefore) {
        op.insert("before", before);
    } else {
        op.insert("after", after);
    }

    if (groupId.isNull()) {
        submitOp(op);
    } else {
        m_pendingGroups[groupId].append(op);
    }
}

void EditorOpBus::flushGroup(const QUuid &groupId)
{
    if (groupId.isNull()) return;
    if (!m_pendingGroups.contains(groupId)) return;

    const QList<QJsonObject> ops = m_pendingGroups.take(groupId);
    if (ops.isEmpty()) return;
    if (m_isApplyingRemote) return;
    if (!EditorSession::instance()->active()) return;

    QJsonArray arr;
    for (const QJsonObject &op : ops)
        arr.append(op);

    const QJsonObject batch{
        { "op",      static_cast<int>(EditorOpType::ApplyState) },
        { "batch",   true },
        { "groupId", groupId.toString() },
        { "ops",     arr },
    };
    const int approxBytes = QJsonDocument(batch).toJson(QJsonDocument::Compact).size();
    qDebug() << "[EditorOpBus] flushGroup" << groupId.toString()
             << "ops=" << ops.size() << "bytes=" << approxBytes;
    if (approxBytes > 30000) {
        qWarning() << "[EditorOpBus] batch > 30KB — reliable.io may drop the packet";
    }
    submitOp(batch);
}
