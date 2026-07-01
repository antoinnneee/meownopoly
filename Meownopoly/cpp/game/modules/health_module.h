#ifndef HEALTH_MODULE_H
#define HEALTH_MODULE_H

#include "gameplay_module.h"

#include <QHash>

/// Module de vie : points de vie courants/max par joueur, dégâts, soin,
/// état mort/KO.
///
/// Données indexées par `playerId` (QString). Un joueur inconnu est
/// implicitement créé au plein de vie (`defaultMaxHp`) au premier accès.
class HealthModule : public GameplayModule
{
    Q_OBJECT

    // PV max attribués par défaut à un joueur nouvellement rencontré.
    Q_PROPERTY(int defaultMaxHp READ defaultMaxHp WRITE setDefaultMaxHp NOTIFY defaultMaxHpChanged)

public:
    explicit HealthModule(QObject *parent = nullptr);

    int defaultMaxHp() const { return m_defaultMaxHp; }
    void setDefaultMaxHp(int maxHp);

    // ── Lecture ───────────────────────────────────────────────────────────
    Q_INVOKABLE int hp(const QString &playerId);
    Q_INVOKABLE int maxHp(const QString &playerId);
    Q_INVOKABLE bool isDead(const QString &playerId);
    /// Renvoie true si un état existe déjà pour ce joueur (sans le créer).
    Q_INVOKABLE bool hasPlayer(const QString &playerId) const;

    // ── Mutations (no-op si module désactivé, retour false) ───────────────
    /// Enregistre/réinitialise un joueur avec des PV pleins (maxHp).
    /// Si maxHp <= 0, utilise defaultMaxHp.
    Q_INVOKABLE bool registerPlayer(const QString &playerId, int maxHp = 0);

    /// Inflige `amount` dégâts (clampé à 0). Émet playerDied au passage à 0.
    Q_INVOKABLE bool damage(const QString &playerId, int amount);

    /// Soigne `amount` PV (clampé au max). Ressuscite un joueur mort si
    /// le soin le repasse au-dessus de 0.
    Q_INVOKABLE bool heal(const QString &playerId, int amount);

    /// Fixe directement les PV courants (clampés à [0, maxHp]).
    Q_INVOKABLE bool setHp(const QString &playerId, int hp);

    /// Fixe le maxHp d'un joueur (clampé à un minimum de 1). Les PV courants
    /// sont clampés au nouveau max ; si le max augmente les PV ne bougent pas
    /// (pas de soin gratuit).
    ///
    /// NON gatée par `enabled()` : c'est la surface d'intégration pilotée par
    /// la stat effective `maxHealth` de StatsModule (même philosophie que l'API
    /// de modificateurs de StatsModule — la valeur doit rester cohérente quel
    /// que soit l'état d'activation). Émet `healthChanged`.
    Q_INVOKABLE bool setMaxHp(const QString &playerId, int maxHp);

    /// Redonne tous ses PV au joueur (revive inclus).
    Q_INVOKABLE bool revive(const QString &playerId);

    void reset() override;

signals:
    /// PV modifiés (après clamp). Émis pour toute variation de hp ou maxHp.
    void healthChanged(const QString &playerId, int hp, int maxHp);
    /// Le joueur vient de tomber à 0 PV.
    void playerDied(const QString &playerId);
    /// Le joueur mort est repassé au-dessus de 0 PV.
    void playerRevived(const QString &playerId);
    void defaultMaxHpChanged();

private:
    struct HealthState {
        int hp = 0;
        int maxHp = 0;
    };

    /// Récupère (en créant au besoin) l'état d'un joueur.
    HealthState &stateFor(const QString &playerId);

    QHash<QString, HealthState> m_states;
    int m_defaultMaxHp = 100;
};

#endif // HEALTH_MODULE_H
