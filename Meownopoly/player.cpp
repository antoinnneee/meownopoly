#include "player.h"
#include "game.h"
#include <QRandomGenerator>
#include <QDebug>

Player::Player(QObject *parent)
    : QObject(parent)
    , m_name("")
    , m_color(QColor("#7f8c8d"))
    , m_kibble(0)
    , m_position(0)
    , m_inJail(false)
    , m_consecutiveDoubles(0)
{
}

Player::Player(const QString &name, const QColor &color, QObject *parent)
    : QObject(parent), m_name(name), m_color(color) {}

void Player::setName(const QString &name)
{
    if (m_name != name) {
        m_name = name;
        emit nameChanged();
    }
}

void Player::setColor(const QColor &color)
{
    if (m_color != color) {
        m_color = color;
        emit colorChanged();
    }
}

void Player::setKibble(int kibble)
{
    if (m_kibble != kibble) {
        m_kibble = kibble;
        emit kibbleChanged();
    }
}

void Player::setPosition(int position)
{
    if (m_position != position) {
        m_position = position;
        emit positionChanged();
    }
}

bool Player::canAfford(int amount) const {
    return m_kibble >= amount;
}

void Player::earnKibble(int amount) {
    m_kibble += amount;
}

void Player::spendKibble(int amount) {
    if (canAfford(amount)) {
        m_kibble -= amount;
    }
}

QList<CaseRestArea*> Player::ownedProperties() const {
    return m_ownedProperties;
}

void Player::addProperty(CaseRestArea* property) {
    if (!m_ownedProperties.contains(property)) {
        m_ownedProperties.append(property);
    }
}

void Player::removeProperty(CaseRestArea* property) {
    m_ownedProperties.removeAll(property);
}

void Player::rollDice() {
    if (m_inJail) {
        // If player is in jail, they need to roll doubles to get out
        int dice1 = QRandomGenerator::global()->bounded(1, 7); // 1-6
        int dice2 = QRandomGenerator::global()->bounded(1, 7); // 1-6
        
        qDebug() << "Player in jail rolled " << dice1 << " and " << dice2;
        
        if (dice1 == dice2) {
            // Player rolled doubles, they can get out of jail
            m_inJail = false;
            m_consecutiveDoubles = 0; // Reset consecutive doubles
            qDebug() << "Player rolled doubles and got out of jail!";
            
            // Move the player according to the dice roll
            move(dice1 + dice2);
        } else {
            qDebug() << "Player did not roll doubles and remains in jail.";
        }
    } else {
        // Normal dice roll
        int dice1 = QRandomGenerator::global()->bounded(1, 7); // 1-6
        int dice2 = QRandomGenerator::global()->bounded(1, 7); // 1-6
        int total = dice1 + dice2;
        
        qDebug() << "Player rolled " << dice1 << " and " << dice2 << " for a total of " << total;
        
        if (dice1 == dice2) {
            // Player rolled doubles
            m_consecutiveDoubles++;
            qDebug() << "Player rolled doubles! Consecutive doubles: " << m_consecutiveDoubles;
            
            if (m_consecutiveDoubles >= 3) {
                // Player rolled three consecutive doubles, send to jail
                qDebug() << "Player rolled three consecutive doubles and is sent to jail!";
                m_inJail = true;
                m_consecutiveDoubles = 0; // Reset consecutive doubles
                
                // Find the jail position
                for (int i = 0; i < Game::instance()->boardSize(); i++) {
                    Case* currentCase = Game::instance()->getCaseAt(i);
                    if (currentCase && currentCase->getType() == CT_Jail) {
                        setPosition(i);
                        break;
                    }
                }
                
                // Emit signal for UI to update
                emit playerMoved(m_position, m_position, 0);
            } else {
                // Move the player according to the dice roll
                move(total);
                
                // Player gets another turn after rolling doubles
                qDebug() << "Player gets another turn after rolling doubles.";
            }
        } else {
            // Player did not roll doubles
            m_consecutiveDoubles = 0; // Reset consecutive doubles
            
            // Move the player according to the dice roll
            move(total);
        }
    }
}

void Player::move(int steps) {
    int oldPosition = m_position;
    m_position = (m_position + steps) % Game::instance()->boardSize();
    
    // Check if player passed the start
    if (m_position < oldPosition) {
        emit passedStart();
    }
    
    // Land on the new position
    Case* currentCase = Game::instance()->getCaseAt(m_position);
    if (currentCase) {
        currentCase->onLand(this);
        emit landedOnSpecialTile();
    }
    
    // Emit signal for UI to update
    emit playerMoved(oldPosition, m_position, steps);
    
    qDebug() << "Player moved from position " << oldPosition << " to position " << m_position;
}

void Player::buyProperty(CaseRestArea* property) {
    if (canAfford(property->get_price())) {
        spendKibble(property->get_price());
        property->setOwner(this);
        m_ownedProperties.append(property);
        qDebug() << "Player" << m_name << "bought property" << property->name() << "for" << property->get_price() << "kibble";
    } else {
        qDebug() << "Player" << m_name << "cannot afford property" << property->name();
    }
}

void Player::setInJail(bool inJail) {
    m_inJail = inJail;
    emit inJailChanged();
}
