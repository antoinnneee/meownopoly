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

void Player::setPosition(int position, int steps)
{
    // Only emit the signal if position actually changes
    if (m_position != position) {
        int oldPosition = m_position;
        m_position = position;

        // We'll only emit position changed here, playerMoved signal is handled in move() method
        emit positionChanged();
        
        // Log position change
        qDebug() << "Player" << m_name << "position set from" << oldPosition << "to" << position;
    } else {
        // Position didn't change, log this unusual situation
        qDebug() << "Warning: setPosition called with same position" << position << "for player" << m_name;
    }
}

bool Player::canAfford(int amount) const {
    return m_kibble >= amount;
}

void Player::earnKibble(int amount) {
    m_kibble += amount;
}

bool Player::spendKibble(int amount) {
    if (canAfford(amount)) {
        m_kibble -= amount;
        return true;
    }
    return false;
}

QList<CaseRestArea*> Player::ownedProperties() const {
    return m_ownedProperties;
}

void Player::addProperty(CaseRestArea* property) {
    if (!m_ownedProperties.contains(property)) {
        m_ownedProperties.append(property);
        emit propertyCountChanged();
    }
}

void Player::removeProperty(CaseRestArea* property) {
    m_ownedProperties.removeAll(property);
    emit propertyCountChanged();
}

void Player::addCatDevice(CaseCatDevice *catDevice)
{
    if (!m_ownedCatDevice.contains(catDevice)) {
        m_ownedCatDevice.append(catDevice);
        emit propertyCountChanged();
    }
}

void Player::removeCatDevice(CaseCatDevice *catDevice)
{
    m_ownedCatDevice.removeAll(catDevice);
    emit catDeviceCountChanged();
}

QList<CaseRestArea *> Player::ownedCatDevices() const
{
    return m_ownedCatDevice;
}

void Player::setInJail(bool inJail) {
    m_inJail = inJail;
    emit inJailChanged();
}
