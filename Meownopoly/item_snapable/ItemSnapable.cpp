#include "ItemSnapable.h"

ItemSnapable::ItemSnapable() {
    qDebug() << "New ItemSnapable created";
}

void ItemSnapable::registerQml()
{
    qmlRegisterType<ItemSnapable>("ItemSnapable", 1, 0, "ItemSnapable"); // Register ItemSnapable class
}

