#ifndef INVENTORY_MODULE_H
#define INVENTORY_MODULE_H

#include "gameplay_module.h"

#include <QHash>
#include <QMap>
#include <QVariantList>

/// Module d'inventaire : objets possédés par joueur, avec quantités et
/// capacité optionnelle (nombre total d'objets, quantités cumulées).
///
/// Données indexées par `playerId`. Chaque joueur possède une map
/// `itemName -> quantité`. Une capacité <= 0 signifie « illimitée ».
class InventoryModule : public GameplayModule
{
    Q_OBJECT

    // Capacité totale par joueur (somme des quantités). <= 0 = illimitée.
    Q_PROPERTY(int capacity READ capacity WRITE setCapacity NOTIFY capacityChanged)

public:
    explicit InventoryModule(QObject *parent = nullptr);

    int capacity() const { return m_capacity; }
    void setCapacity(int capacity);

    // ── Lecture ───────────────────────────────────────────────────────────
    /// Quantité d'un item pour un joueur (0 si absent).
    Q_INVOKABLE int itemQuantity(const QString &playerId, const QString &itemName) const;
    /// Somme des quantités possédées par le joueur.
    Q_INVOKABLE int totalItems(const QString &playerId) const;
    /// Liste des items du joueur sous forme [{ name, quantity }, ...],
    /// triée par nom — directement consommable par un ListView QML.
    Q_INVOKABLE QVariantList items(const QString &playerId) const;

    // ── Mutations (no-op si module désactivé, retour false) ───────────────
    /// Ajoute `quantity` exemplaires de `itemName`. Échoue (false) si la
    /// capacité serait dépassée (émet capacityExceeded). quantity doit être > 0.
    Q_INVOKABLE bool addItem(const QString &playerId, const QString &itemName,
                             int quantity = 1);

    /// Retire `quantity` exemplaires. Retire l'entrée si la quantité tombe
    /// à 0. Échoue (false) si le joueur n'en possède pas assez.
    Q_INVOKABLE bool removeItem(const QString &playerId, const QString &itemName,
                                int quantity = 1);

    /// Vide l'inventaire d'un joueur.
    Q_INVOKABLE bool clearPlayer(const QString &playerId);

    void reset() override;

signals:
    /// Item ajouté. `newQuantity` = quantité après ajout pour cet item.
    void itemAdded(const QString &playerId, const QString &itemName,
                   int quantity, int newQuantity);
    /// Item retiré. `newQuantity` = quantité restante (0 si supprimé).
    void itemRemoved(const QString &playerId, const QString &itemName,
                     int quantity, int newQuantity);
    /// Le contenu de l'inventaire du joueur a changé (hook UI générique).
    void inventoryChanged(const QString &playerId);
    /// Un addItem a été refusé faute de capacité.
    void capacityExceeded(const QString &playerId, const QString &itemName,
                          int requested);
    void capacityChanged();

private:
    // itemName -> quantité, trié par nom (QMap) pour un rendu stable.
    using Bag = QMap<QString, int>;
    QHash<QString, Bag> m_bags;
    int m_capacity = 0;  // 0 = illimité

    int totalOf(const Bag &bag) const;
};

#endif // INVENTORY_MODULE_H
