#include "editor_op_bus.h"

#include <QDebug>
#include <QJsonDocument>
#include <QUuid>

EditorOpBus *EditorOpBus::m_pThis = nullptr;

EditorOpBus::EditorOpBus(QObject *parent) : QObject(parent) {}

EditorOpBus *EditorOpBus::instance()
{
    if (!m_pThis)
        m_pThis = new EditorOpBus();
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

void EditorOpBus::recordOp(const QJsonObject &op)
{
    qDebug().noquote() << "[EditorOpBus]"
                       << QJsonDocument(op).toJson(QJsonDocument::Compact);
    emit opRecorded(op);
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
