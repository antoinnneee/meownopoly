#ifndef CURRENCY_MODULE_H
#define CURRENCY_MODULE_H

#include "gameplay_module.h"

#include <QHash>

/// Module de monnaie : solde par joueur, crédit/débit, transferts entre
/// joueurs avec refus si solde insuffisant.
///
/// Données indexées par `playerId`. Un joueur inconnu démarre au solde
/// initial (`startingBalance`).
class CurrencyModule : public GameplayModule
{
    Q_OBJECT

    // Solde attribué par défaut à un joueur nouvellement rencontré.
    Q_PROPERTY(int startingBalance READ startingBalance WRITE setStartingBalance NOTIFY startingBalanceChanged)

public:
    explicit CurrencyModule(QObject *parent = nullptr);

    int startingBalance() const { return m_startingBalance; }
    void setStartingBalance(int balance);

    // ── Lecture ───────────────────────────────────────────────────────────
    Q_INVOKABLE int balance(const QString &playerId);
    Q_INVOKABLE bool hasPlayer(const QString &playerId) const;

    // ── Mutations (no-op si module désactivé, retour false) ───────────────
    /// (Ré)initialise le solde d'un joueur à `amount`.
    Q_INVOKABLE bool registerPlayer(const QString &playerId, int amount = 0);

    /// Crédite `amount` (> 0) au joueur.
    Q_INVOKABLE bool credit(const QString &playerId, int amount);

    /// Débite `amount` (> 0). Échoue (false + transferFailed) si le solde
    /// est insuffisant (pas de découvert).
    Q_INVOKABLE bool debit(const QString &playerId, int amount);

    /// Transfère `amount` de `fromId` vers `toId`. Atomique : échoue sans
    /// rien changer si le solde de `fromId` est insuffisant.
    Q_INVOKABLE bool transfer(const QString &fromId, const QString &toId, int amount);

    void reset() override;

signals:
    /// Solde d'un joueur modifié.
    void balanceChanged(const QString &playerId, int balance);
    /// Une opération (débit/transfert) a été refusée. `reason` est un libellé
    /// lisible (ex: "solde insuffisant").
    void transferFailed(const QString &fromId, const QString &toId,
                        int amount, const QString &reason);
    void startingBalanceChanged();

private:
    /// Récupère (en créant au besoin, au solde initial) le solde d'un joueur.
    int &balanceRef(const QString &playerId);

    QHash<QString, int> m_balances;
    int m_startingBalance = 1500;
};

#endif // CURRENCY_MODULE_H
