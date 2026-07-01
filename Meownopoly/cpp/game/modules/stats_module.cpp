#include "stats_module.h"

#include <QDebug>

namespace {
// Valeurs de base par défaut (v1). Toute stat inconnue défaute à 0.
constexpr qreal kDefaultSpeed = 1.0;
constexpr qreal kDefaultDamage = 10.0;
} // namespace

StatsModule::StatsModule(QObject *parent)
    : GameplayModule(QStringLiteral("stats"), QStringLiteral("Module de statistiques"), parent)
{
}

QStringList StatsModule::knownStats() const
{
    return { QStringLiteral("speed"), QStringLiteral("damage") };
}

QString StatsModule::statLabel(const QString &statKey) const
{
    if (statKey == QStringLiteral("speed"))
        return QStringLiteral("Vitesse");
    if (statKey == QStringLiteral("damage"))
        return QStringLiteral("Dommage");
    return statKey;
}

qreal StatsModule::defaultBaseStat(const QString &statKey) const
{
    if (statKey == QStringLiteral("speed"))
        return kDefaultSpeed;
    if (statKey == QStringLiteral("damage"))
        return kDefaultDamage;
    return 0.0;
}

qreal StatsModule::baseStat(const QString &playerId, const QString &statKey) const
{
    auto it = m_baseStats.constFind(playerId);
    if (it != m_baseStats.constEnd()) {
        auto sit = it->constFind(statKey);
        if (sit != it->constEnd())
            return sit.value();
    }
    return defaultBaseStat(statKey);
}

qreal StatsModule::sumModifiers(const QString &playerId, const QString &statKey) const
{
    qreal sum = 0.0;
    auto it = m_modifiers.constFind(playerId);
    if (it != m_modifiers.constEnd()) {
        for (const Modifier &m : it.value()) {
            if (m.statKey == statKey)
                sum += m.value;
        }
    }
    return sum;
}

qreal StatsModule::effectiveStat(const QString &playerId, const QString &statKey) const
{
    return baseStat(playerId, statKey) + sumModifiers(playerId, statKey);
}

void StatsModule::notifyStat(const QString &playerId, const QString &statKey)
{
    emit statChanged(playerId, statKey,
                     baseStat(playerId, statKey),
                     effectiveStat(playerId, statKey));
}

bool StatsModule::setBaseStat(const QString &playerId, const QString &statKey, qreal value)
{
    if (!enabled()) {
        qWarning() << "[StatsModule] setBaseStat ignoré — module désactivé";
        return false;
    }
    m_baseStats[playerId][statKey] = value;
    notifyStat(playerId, statKey);
    return true;
}

void StatsModule::addModifier(const QString &playerId, const QString &sourceId,
                              const QString &statKey, qreal value)
{
    // NON gatée par enabled() : c'est la surface d'intégration des autres
    // modules (équipement, cartes, cases…). Les modificateurs sont stockés
    // même si le module est désactivé, pour être pris en compte dès sa
    // réactivation.
    m_modifiers[playerId].append(Modifier{ sourceId, statKey, value });
    emit modifierAdded(playerId, sourceId, statKey, value);
    notifyStat(playerId, statKey);
}

int StatsModule::removeModifiersFromSource(const QString &playerId, const QString &sourceId)
{
    auto it = m_modifiers.find(playerId);
    if (it == m_modifiers.end())
        return 0;

    QList<Modifier> &list = it.value();
    QStringList affected;   // stats impactées, pour ré-émettre statChanged
    int removed = 0;
    for (int i = list.size() - 1; i >= 0; --i) {
        if (list.at(i).sourceId == sourceId) {
            if (!affected.contains(list.at(i).statKey))
                affected.append(list.at(i).statKey);
            list.removeAt(i);
            ++removed;
        }
    }
    if (removed == 0)
        return 0;
    if (list.isEmpty())
        m_modifiers.erase(it);

    emit modifiersRemoved(playerId, sourceId);
    for (const QString &statKey : std::as_const(affected))
        notifyStat(playerId, statKey);
    return removed;
}

void StatsModule::reset()
{
    m_baseStats.clear();
    m_modifiers.clear();
}
