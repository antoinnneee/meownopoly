#include "ItemSnapable.h"

ItemSnapable::ItemSnapable() {}

void ItemSnapable::registerQml()
{
    qmlRegisterType<ItemSnapable>("ItemSnapable", 1, 0, "ItemSnapable"); // Register ItemSnapable class
}

