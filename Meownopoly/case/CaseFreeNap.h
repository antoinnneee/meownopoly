#ifndef CASEFREENAP_H
#define CASEFREENAP_H

#include "Case.h"
#include "player.h"

class CaseFreeNap : public Case {
    Q_OBJECT

    Q_PROPERTY(int kibbleAmount READ kibbleAmount WRITE setKibbleAmount NOTIFY kibbleAmountChanged FINAL)
public:
    explicit CaseFreeNap(QObject *parent = nullptr);
    CaseFreeNap(const QString &name, QUuid uniqueId, QObject *parent = nullptr);
    CaseFreeNap(const QJsonDocument &json, QObject *parent = nullptr);

    Q_INVOKABLE void addToPool(int amount);

    // void onLand(Player* player) override;

    int kibbleAmount() const;
    void setKibbleAmount(int newKibbleAmount);

    Q_INVOKABLE virtual QString toJSON() override;

signals:
    void kibbleAmountChanged();

private:
    enum CaseType type = CS_FreeNap;
    int m_kibbleAmount = 0;
};

#endif // CASEFREENAP_H 
