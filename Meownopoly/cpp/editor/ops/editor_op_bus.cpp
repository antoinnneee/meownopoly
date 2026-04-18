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

    qDebug().noquote() << "[EditorOpBus] submit"
                       << QJsonDocument(op).toJson(QJsonDocument::Compact);
    emit opRecorded(op);

    // Phase 3 : si la session collaborative est active, envoyer l'op.
    EditorSession *sess = EditorSession::instance();
    if (sess->active()) {
        sess->sendOp(op);
    }
}

void EditorOpBus::onSessionOpReceived(const QString &senderId, const QJsonObject &op)
{
    Q_UNUSED(senderId);
    qDebug().noquote() << "[EditorOpBus] remote from" << senderId
                       << QJsonDocument(op).toJson(QJsonDocument::Compact);

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
