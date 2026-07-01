#include "itemsnapablefactory.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QJsonDocument>
#include <QJsonArray>

ItemSnapableFactory *ItemSnapableFactory::m_pThis = nullptr;

ItemSnapableFactory::ItemSnapableFactory(QObject *parent)
    : QObject(parent)
{}

void ItemSnapableFactory::registerQml()
{
    qmlRegisterSingletonType<ItemSnapableFactory>("ItemSnapableFactory",
                                                  1,
                                                  0,
                                                  "ItemSnapableFactory",
                                                  &ItemSnapableFactory::qmlInstance);
}

ItemSnapableFactory *ItemSnapableFactory::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new ItemSnapableFactory;
    }
    return m_pThis;
}

QObject *ItemSnapableFactory::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return ItemSnapableFactory::instance();
}

ItemSnapable *ItemSnapableFactory::createItemSnapable()
{
    ItemSnapable *snap = new ItemSnapable();
    QQmlEngine::setObjectOwnership(snap, QQmlEngine::JavaScriptOwnership);
    return snap;
}

ItemSnapable *ItemSnapableFactory::createItemSnapable(Case::CaseType caseType)
{
    ItemSnapable *snap = new ItemSnapable(caseType);
    QQmlEngine::setObjectOwnership(snap, QQmlEngine::JavaScriptOwnership);
    return snap;
}

ItemSnapable *ItemSnapableFactory::createItemSnapableFromJson(const QJsonObject &json)
{
    ItemSnapable *snap = new ItemSnapable(json);
    QQmlEngine::setObjectOwnership(snap, QQmlEngine::JavaScriptOwnership);
    return snap;
}

ItemSnapable *ItemSnapableFactory::createPhysicZone()
{
    ItemSnapable *snap = new ItemSnapable();
    snap->setTileType(ItemSnapable::PhysicZoneTile);
    QQmlEngine::setObjectOwnership(snap, QQmlEngine::JavaScriptOwnership);
    return snap;
}

ItemSnapable *ItemSnapableFactory::createNPC()
{
    ItemSnapable *snap = new ItemSnapable();
    snap->setTileType(ItemSnapable::NPCTile);
    QQmlEngine::setObjectOwnership(snap, QQmlEngine::JavaScriptOwnership);
    return snap;
}

void ItemSnapableFactory::requestCreateItem(const QJsonObject &jsonData)
{
    emit createItemRequested(jsonData);
}

void ItemSnapableFactory::requestCreateItems(const QJsonArray &jsonArray)
{
    emit createItemsRequested(jsonArray);
}

void ItemSnapableFactory::requestCreateItemFromString(const QString &jsonString)
{
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(jsonString.toUtf8(), &error);
    if (error.error != QJsonParseError::NoError) {
        qWarning() << "ItemSnapableFactory::requestCreateItemFromString : JSON invalide —" << error.errorString();
        return;
    }
    if (doc.isArray()) {
        emit createItemsRequested(doc.array());
    } else if (doc.isObject()) {
        emit createItemRequested(doc.object());
    } else {
        qWarning() << "ItemSnapableFactory::requestCreateItemFromString : le JSON n'est ni un objet ni un tableau";
    }
}

