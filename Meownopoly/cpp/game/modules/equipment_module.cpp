#include "equipment_module.h"

#include "stats_module.h"

#include <QDebug>

EquipmentModule::EquipmentModule(QObject *parent)
    : GameplayModule(QStringLiteral("equipment"), QStringLiteral("Module d'équipement"), parent)
{
}

QStringList EquipmentModule::slotIds() const
{
    return { QStringLiteral("weapon"), QStringLiteral("boots"),
             QStringLiteral("tunic"), QStringLiteral("hat") };
}

QString EquipmentModule::slotLabel(const QString &slot) const
{
    if (slot == QStringLiteral("weapon"))
        return QStringLiteral("Arme");
    if (slot == QStringLiteral("boots"))
        return QStringLiteral("Bottes");
    if (slot == QStringLiteral("tunic"))
        return QStringLiteral("Tunique");
    if (slot == QStringLiteral("hat"))
        return QStringLiteral("Chapeau");
    return slot;
}

bool EquipmentModule::isValidSlot(const QString &slot) const
{
    return slotIds().contains(slot);
}

QVariantMap EquipmentModule::equippedItem(const QString &playerId, const QString &slot) const
{
    QVariantMap result;
    auto it = m_equipment.constFind(playerId);
    if (it != m_equipment.constEnd()) {
        auto sit = it->constFind(slot);
        if (sit != it->constEnd()) {
            result.insert(QStringLiteral("name"), sit->name);
            result.insert(QStringLiteral("bonuses"), sit->bonuses);
        }
    }
    return result;
}

QVariantList EquipmentModule::equipment(const QString &playerId) const
{
    QVariantList list;
    const QStringList ids = slotIds();
    for (const QString &slot : ids) {
        QVariantMap entry;
        entry.insert(QStringLiteral("slot"), slot);
        entry.insert(QStringLiteral("label"), slotLabel(slot));
        const QVariantMap item = equippedItem(playerId, slot);
        entry.insert(QStringLiteral("name"), item.value(QStringLiteral("name")).toString());
        entry.insert(QStringLiteral("bonuses"), item.value(QStringLiteral("bonuses")));
        list.append(entry);
    }
    return list;
}

QString EquipmentModule::removeSlot(const QString &playerId, const QString &slot)
{
    auto it = m_equipment.find(playerId);
    if (it == m_equipment.end())
        return QString();
    auto sit = it->find(slot);
    if (sit == it->end())
        return QString();

    const QString name = sit->name;
    it->erase(sit);
    if (it->isEmpty())
        m_equipment.erase(it);

    // Retire les modificateurs de stats posés par ce slot (source "equip:<slot>").
    if (m_stats)
        m_stats->removeModifiersFromSource(playerId, sourceIdFor(slot));
    return name;
}

bool EquipmentModule::equip(const QString &playerId, const QString &slot,
                            const QString &itemName, const QVariantMap &bonuses)
{
    if (!enabled()) {
        qWarning() << "[EquipmentModule] equip ignoré — module désactivé";
        return false;
    }
    if (!isValidSlot(slot)) {
        qWarning() << "[EquipmentModule] equip : slot inconnu" << slot;
        return false;
    }

    // Remplace l'item existant : déséquipe d'abord (retire ses modificateurs).
    const QString previous = removeSlot(playerId, slot);
    if (!previous.isEmpty())
        emit itemUnequipped(playerId, slot, previous);

    Item item;
    item.name = itemName;
    item.bonuses = bonuses;
    m_equipment[playerId][slot] = item;

    // Applique les bonus via l'API de modificateurs de StatsModule (posés même
    // si StatsModule est désactivé — cf. sémantique enabled de StatsModule).
    if (m_stats) {
        const QString source = sourceIdFor(slot);
        for (auto b = bonuses.constBegin(); b != bonuses.constEnd(); ++b)
            m_stats->addModifier(playerId, source, b.key(), b.value().toDouble());
    }

    emit itemEquipped(playerId, slot, itemName);
    emit equipmentChanged(playerId);
    return true;
}

bool EquipmentModule::unequip(const QString &playerId, const QString &slot)
{
    if (!enabled()) {
        qWarning() << "[EquipmentModule] unequip ignoré — module désactivé";
        return false;
    }
    if (!isValidSlot(slot))
        return false;

    const QString name = removeSlot(playerId, slot);
    if (name.isEmpty())
        return false;

    emit itemUnequipped(playerId, slot, name);
    emit equipmentChanged(playerId);
    return true;
}

void EquipmentModule::reset()
{
    // Retire tous les modificateurs posés par l'équipement avant de vider.
    if (m_stats) {
        for (auto it = m_equipment.constBegin(); it != m_equipment.constEnd(); ++it) {
            const QString &playerId = it.key();
            for (auto sit = it->constBegin(); sit != it->constEnd(); ++sit)
                m_stats->removeModifiersFromSource(playerId, sourceIdFor(sit.key()));
        }
    }
    m_equipment.clear();
}
