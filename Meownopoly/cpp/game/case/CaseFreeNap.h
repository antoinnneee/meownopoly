#ifndef CASEFREENAP_H
#define CASEFREENAP_H

#include "Case.h"
#include "game/player.h"

class CaseFreeNap : public Case {
    Q_OBJECT

    Q_PROPERTY(int kibbleAmount READ kibbleAmount WRITE setKibbleAmount NOTIFY kibbleAmountChanged FINAL)
public:
    explicit CaseFreeNap(QObject *parent = nullptr);
    CaseFreeNap(const QString &name, QObject *parent = nullptr);
    CaseFreeNap(const QJsonObject &json, QObject *parent = nullptr);

    Q_INVOKABLE void addToPool(int amount);

    // void onLand(Player* player) override;

    int kibbleAmount() const;
    void setKibbleAmount(int newKibbleAmount);

    QJsonObject toJsonObject() const override final;

signals:
    void kibbleAmountChanged();

private:
    enum CaseType type = CS_FreeNap;
    int m_kibbleAmount = 0;
};

#endif // CASEFREENAP_H 
