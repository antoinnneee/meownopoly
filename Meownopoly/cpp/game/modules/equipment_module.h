#ifndef EQUIPMENT_MODULE_H
#define EQUIPMENT_MODULE_H

#include "gameplay_module.h"

#include <QHash>
#include <QMap>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// Forward declaration : m_stats n'est PAS un Q_PROPERTY pointeur, moc n'a donc
// pas besoin du type complet (contrairement aux accesseurs typés du manager).
// Ça évite un couplage dur à stats_module.h dans ce header.
class StatsModule;

/// Module d'équipement : 4 slots fixes (arme, bottes, tunique, chapeau) par
/// joueur, au plus un item par slot. Chaque item porte des bonus de stats
/// ({statKey: valeur}) appliqués via l'API de modificateurs de `StatsModule`
/// avec la source "equip:<slot>" — posés à l'équipement, retirés au
/// déséquipement, au remplacement et au reset.
///
/// Couplage à StatsModule par injection (`setStatsModule`), câblée dans le
/// ctor du `GameplayModuleManager`. Aucun include de stats_module.h ici.
class EquipmentModule : public GameplayModule
{
    Q_OBJECT

public:
    explicit EquipmentModule(QObject *parent = nullptr);

    /// Injecte le module de stats cible (appelé par le manager au câblage).
    void setStatsModule(StatsModule *stats) { m_stats = stats; }

    // ── Métadonnées ───────────────────────────────────────────────────────
    /// Identifiants des 4 slots (weapon, boots, tunic, hat).
    /// NB : nommé `slotIds()` et pas `slots()` — `slots` est un mot-clé macro
    /// de Qt (`#define slots`), inutilisable comme nom de méthode.
    Q_INVOKABLE QStringList slotIds() const;
    /// Libellé français d'un slot (pour l'UI).
    Q_INVOKABLE QString slotLabel(const QString &slot) const;

    // ── Lecture (autorisée même désactivé) ────────────────────────────────
    /// { name, bonuses } de l'item équipé sur `slot` (map vide si slot libre).
    Q_INVOKABLE QVariantMap equippedItem(const QString &playerId, const QString &slot) const;
    /// Vue complète des 4 slots : [{ slot, label, name, bonuses }, ...],
    /// toujours 4 entrées (name vide si slot libre) — pour un Repeater QML.
    Q_INVOKABLE QVariantList equipment(const QString &playerId) const;

    // ── Mutations (no-op si module désactivé, retour false) ───────────────
    /// Équipe `itemName` (bonus {statKey: valeur}) sur `slot`. Remplace l'item
    /// existant (déséquipé au préalable, ses modificateurs retirés). Slot
    /// inconnu → false.
    Q_INVOKABLE bool equip(const QString &playerId, const QString &slot,
                           const QString &itemName, const QVariantMap &bonuses);
    /// Déséquipe le slot (retire ses modificateurs de stats). false si slot
    /// vide ou inconnu.
    Q_INVOKABLE bool unequip(const QString &playerId, const QString &slot);

    void reset() override;

signals:
    void itemEquipped(const QString &playerId, const QString &slot, const QString &itemName);
    void itemUnequipped(const QString &playerId, const QString &slot, const QString &itemName);
    /// L'équipement du joueur a changé (hook UI générique).
    void equipmentChanged(const QString &playerId);

private:
    struct Item {
        QString name;
        QVariantMap bonuses;  // statKey -> valeur
    };

    bool isValidSlot(const QString &slot) const;
    QString sourceIdFor(const QString &slot) const { return QStringLiteral("equip:") + slot; }
    /// Retire l'item d'un slot (et ses modificateurs de stats) sans vérifier
    /// `enabled` ni émettre de signal. Retourne le nom retiré (vide si libre).
    QString removeSlot(const QString &playerId, const QString &slot);

    // playerId -> (slot -> Item). Slot absent = libre.
    QHash<QString, QMap<QString, Item>> m_equipment;
    StatsModule *m_stats = nullptr;
};

#endif // EQUIPMENT_MODULE_H
