#ifndef PLAYER_H
#define PLAYER_H

#include <QObject>
#include <QString>
#include <QList>
#include "case/caserestarea.h"

class Player : public QObject
{
    Q_OBJECT
public:
    explicit Player(const QString &name, QObject *parent = nullptr);

    QString name() const;

    int position() const;
    void setPosition(int newPosition);

    int kibble() const;
    void setKibble(int newKibble);
    bool canAfford(int amount) const;
    void earnKibble(int amount);
    void spendKibble(int amount);

    QList<CaseRestArea*> ownedProperties() const;
    void addProperty(CaseRestArea* property);
    void removeProperty(CaseRestArea* property);

    void rollDice();
    void move(int steps);
    void buyProperty(CaseRestArea* property);

    bool isInJail() const;
    void setInJail(bool inJail);

signals:
    void playerMoved(int oldPosition, int newPosition, int steps);
    void passedStart();
    void landedOnSpecialTile();

private:
    QString m_name;
    int m_position = 0;
    int m_kibble = 1500; // Starting amount of kibble
    QList<CaseRestArea*> m_ownedProperties;
    bool m_inJail = false;
    int m_consecutiveDoubles = 0; // Track consecutive doubles
};

#endif // PLAYER_H
