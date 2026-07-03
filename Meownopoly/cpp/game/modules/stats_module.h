#ifndef STATS_MODULE_H
#define STATS_MODULE_H

#include "gameplay_module.h"

#include <QHash>
#include <QList>
#include <QStringList>

/// Module de statistiques : valeurs numériques par joueur (vitesse, dommage…)
/// composées d'une stat de base + d'un empilement de modificateurs identifiés
/// par une source (`sourceId`). L'équipement, les cartes, les effets de cases…
/// modulent les stats via l'API de modificateurs sans couplage dur.
///
/// Stat effective = stat de base + somme des modificateurs actifs pour la clé.
/// Le stockage est extensible : la clé de stat est une QString libre, les
/// valeurs des `qreal`. `knownStats()` expose la liste des stats connues (v1 :
/// speed, damage) à l'UI.
///
/// Sémantique `enabled` : les LECTURES et l'API de modificateurs
/// (addModifier/removeModifiersFromSource) restent disponibles même désactivé
/// — c'est la surface d'intégration des autres modules (l'équipement doit
/// pouvoir poser/retirer ses bonus quel que soit l'état d'activation, pour que
/// la stat effective soit correcte dès la réactivation). Seule la mutation
/// « joueur » directe `setBaseStat` est gatée par `enabled()`.
class StatsModule : public GameplayModule
{
    Q_OBJECT

public:
    explicit StatsModule(QObject *parent = nullptr);

    // ── Métadonnées ───────────────────────────────────────────────────────
    /// Liste des clés de stats connues (extensible ; v1 : speed, damage).
    Q_INVOKABLE QStringList knownStats() const;
    /// Libellé français d'une stat (pour l'UI).
    Q_INVOKABLE QString statLabel(const QString &statKey) const;
    /// Valeur de base par défaut d'une stat non encore définie pour un joueur.
    Q_INVOKABLE qreal defaultBaseStat(const QString &statKey) const;

    // ── Lecture (autorisée même désactivé) ────────────────────────────────
    Q_INVOKABLE qreal baseStat(const QString &playerId, const QString &statKey) const;
    Q_INVOKABLE qreal effectiveStat(const QString &playerId, const QString &statKey) const;

    // ── Mutation joueur (no-op si module désactivé, retour false) ─────────
    Q_INVOKABLE bool setBaseStat(const QString &playerId, const QString &statKey, qreal value);

    // ── API de modificateurs (NON gatée : surface d'intégration) ──────────
    /// Empile un modificateur `value` sur `statKey`, attribué à `sourceId`
    /// (ex : "equip:weapon"). Plusieurs modificateurs peuvent coexister ;
    /// `removeModifiersFromSource` permet de tous les retirer proprement.
    Q_INVOKABLE void addModifier(const QString &playerId, const QString &sourceId,
                                 const QString &statKey, qreal value);
    /// Retire tous les modificateurs posés par `sourceId` pour ce joueur.
    /// Retourne le nombre de modificateurs retirés.
    Q_INVOKABLE int removeModifiersFromSource(const QString &playerId, const QString &sourceId);

    void reset() override;

signals:
    /// Une stat a changé (base et/ou effective), après recalcul.
    void statChanged(const QString &playerId, const QString &statKey,
                     qreal baseValue, qreal effectiveValue);
    /// Un modificateur a été empilé.
    void modifierAdded(const QString &playerId, const QString &sourceId,
                       const QString &statKey, qreal value);
    /// Tous les modificateurs d'une source ont été retirés.
    void modifiersRemoved(const QString &playerId, const QString &sourceId);

private:
    struct Modifier {
        QString sourceId;
        QString statKey;
        qreal value = 0.0;
    };

    qreal sumModifiers(const QString &playerId, const QString &statKey) const;
    /// Émet statChanged avec les valeurs base/effective courantes.
    void notifyStat(const QString &playerId, const QString &statKey);

    // playerId -> (statKey -> base). Absence = defaultBaseStat(statKey).
    QHash<QString, QHash<QString, qreal>> m_baseStats;
    // playerId -> liste de modificateurs actifs.
    QHash<QString, QList<Modifier>> m_modifiers;
};

#endif // STATS_MODULE_H
