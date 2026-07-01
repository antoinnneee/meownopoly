#include "inventory_module.h"

#include <QDebug>
#include <QVariantMap>

InventoryModule::InventoryModule(QObject *parent)
    : GameplayModule(QStringLiteral("inventory"), QStringLiteral("Module d'inventaire"), parent)
{
}

void InventoryModule::setCapacity(int capacity)
{
    if (capacity < 0)
        capacity = 0;
    if (m_capacity == capacity)
        return;
    m_capacity = capacity;
    emit capacityChanged();
}

int InventoryModule::totalOf(const Bag &bag) const
{
    int total = 0;
    for (int q : bag)
        total += q;
    return total;
}

int InventoryModule::itemQuantity(const QString &playerId, const QString &itemName) const
{
    const auto it = m_bags.constFind(playerId);
    if (it == m_bags.constEnd())
        return 0;
    return it.value().value(itemName, 0);
}

int InventoryModule::totalItems(const QString &playerId) const
{
    const auto it = m_bags.constFind(playerId);
    if (it == m_bags.constEnd())
        return 0;
    return totalOf(it.value());
}

QVariantList InventoryModule::items(const QString &playerId) const
{
    QVariantList out;
    const auto it = m_bags.constFind(playerId);
    if (it == m_bags.constEnd())
        return out;
    const Bag &bag = it.value();
    for (auto bit = bag.constBegin(); bit != bag.constEnd(); ++bit) {
        QVariantMap entry;
        entry.insert(QStringLiteral("name"), bit.key());
        entry.insert(QStringLiteral("quantity"), bit.value());
        out.append(entry);
    }
    return out;
}

bool InventoryModule::addItem(const QString &playerId, const QString &itemName,
                              int quantity)
{
    if (!enabled()) {
        qWarning() << "[InventoryModule] addItem ignoré — module désactivé";
        return false;
    }
    if (quantity <= 0 || itemName.isEmpty())
        return false;

    Bag &bag = m_bags[playerId];
    if (m_capacity > 0 && totalOf(bag) + quantity > m_capacity) {
        emit capacityExceeded(playerId, itemName, quantity);
        return false;
    }
    const int newQty = bag.value(itemName, 0) + quantity;
    bag.insert(itemName, newQty);
    emit itemAdded(playerId, itemName, quantity, newQty);
    emit inventoryChanged(playerId);
    return true;
}

bool InventoryModule::removeItem(const QString &playerId, const QString &itemName,
                                 int quantity)
{
    if (!enabled()) {
        qWarning() << "[InventoryModule] removeItem ignoré — module désactivé";
        return false;
    }
    if (quantity <= 0 || itemName.isEmpty())
        return false;

    auto bagIt = m_bags.find(playerId);
    if (bagIt == m_bags.end())
        return false;
    Bag &bag = bagIt.value();
    const int current = bag.value(itemName, 0);
    if (current < quantity)
        return false;

    const int newQty = current - quantity;
    if (newQty == 0)
        bag.remove(itemName);
    else
        bag.insert(itemName, newQty);
    emit itemRemoved(playerId, itemName, quantity, newQty);
    emit inventoryChanged(playerId);
    return true;
}

bool InventoryModule::clearPlayer(const QString &playerId)
{
    if (!enabled()) {
        qWarning() << "[InventoryModule] clearPlayer ignoré — module désactivé";
        return false;
    }
    if (m_bags.remove(playerId) > 0) {
        emit inventoryChanged(playerId);
        return true;
    }
    return false;
}

void InventoryModule::reset()
{
    m_bags.clear();
}
