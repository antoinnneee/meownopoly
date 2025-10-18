#include "itemsnapablefactory.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>

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
    return snap;
}

ItemSnapable *ItemSnapableFactory::createItemSnapable(Case::CaseType caseType)
{
    ItemSnapable *snap = new ItemSnapable(caseType);
    return snap;
}