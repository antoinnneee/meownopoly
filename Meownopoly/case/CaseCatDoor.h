#ifndef CASECATDOOR_H
#define CASECATDOOR_H

#include "CaseCatPerks.h"

class CaseCatDoor : public CaseCatPerks {
    Q_OBJECT

public:
    explicit CaseCatDoor(QObject *parent = nullptr);
    CaseCatDoor(const QString &name, int position, QObject *parent = nullptr);
    ~CaseCatDoor() override = default;

    Q_INVOKABLE bool buyCase(Player *buyer);
    Q_INVOKABLE bool sellCase(Player *buyer);


    void onLand(Player* player) override;


private:
};

#endif // CASECATDOOR_H
