#ifndef PLAYER_H
#define PLAYER_H

#include <QObject>
#include <QString>
#include <QColor>
#include <QList>
#include "case/caserestarea.h"

class Player : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(int kibble READ kibble WRITE setKibble NOTIFY kibbleChanged)
    Q_PROPERTY(int propertyCount READ propertyCount NOTIFY propertyCountChanged)
    Q_PROPERTY(int position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(bool inJail READ isInJail WRITE setInJail NOTIFY inJailChanged)

public:
    explicit Player(QObject *parent = nullptr);
    explicit Player(const QString &name, const QColor &color, QObject *parent = nullptr);

    QString name() const { return m_name; }
    void setName(const QString &name);

    QColor color() const { return m_color; }
    void setColor(const QColor &color);

    int kibble() const { return m_kibble; }
    void setKibble(int kibble);

    int position() const { return m_position; }
    void setPosition(int position);

    bool isInJail() const { return m_inJail; }
    void setInJail(bool inJail);

    bool canAfford(int amount) const;
    void earnKibble(int amount);
    void spendKibble(int amount);

    QList<CaseRestArea*> ownedProperties() const;
    void addProperty(CaseRestArea* property);
    void removeProperty(CaseRestArea* property);
    int propertyCount() const { return m_ownedProperties.size(); }

    Q_INVOKABLE void rollDice();
    Q_INVOKABLE void move(int steps);
    Q_INVOKABLE void buyProperty(CaseRestArea* property);

signals:
    void nameChanged();
    void colorChanged();
    void kibbleChanged();
    void propertyCountChanged();
    void positionChanged();
    void inJailChanged();
    void playerMoved(int oldPosition, int newPosition, int steps);
    void passedStart();
    void landedOnSpecialTile();

private:
    QString m_name;
    QColor m_color;
    int m_kibble = 1500;  // Starting money
    int m_position = 0;
    QList<CaseRestArea*> m_ownedProperties;
    bool m_inJail = false;
    int m_consecutiveDoubles = 0; // Track consecutive doubles
};

#endif // PLAYER_H
