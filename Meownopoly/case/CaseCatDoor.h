#ifndef CASECATDOOR_H
#define CASECATDOOR_H

#include "Case.h"



class CaseCatDoor : public Case {
    Q_OBJECT
public:
    explicit CaseCatDoor(QObject *parent = nullptr);
    CaseCatDoor(const QString &name, int position, QObject *parent = nullptr);
    ~CaseCatDoor() override = default;

    void onLand(Player* player) override;

signals:

private:
};

#endif // CASECATDOOR_H
