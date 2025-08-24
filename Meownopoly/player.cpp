#include "player.h"
#include <QRandomGenerator>
#include <QDebug>

Player::Player(QObject *parent)
    : QObject(parent)
    , m_name("unname")
    , m_color(QColor("#7f8c8d"))
    , m_kibble(12000)
    , m_position(0)
    , m_inJail(false)
{
}

Player::Player(QString name, QColor color, int indexLogo, int kibbles, QObject *parent)
    : QObject(parent), m_name(name), m_color(color), m_kibble(kibbles), m_indexLogo(indexLogo) {
}

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
    setKibble(m_kibble + amount);
}

bool Player::spendKibble(int amount) {
    if (canAfford(amount)) {
        setKibble(m_kibble - amount);
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
    if (!m_ownedCatDevices.contains(catDevice)) {
        m_ownedCatDevices.append(catDevice);
        emit catDeviceCountChanged();
    }
}

void Player::removeCatDevice(CaseCatDevice *catDevice)
{
    m_ownedCatDevices.removeAll(catDevice);
    emit catDeviceCountChanged();
}

QList<CaseCatDoor *> Player::ownedCatDoors() const
{
    return m_ownedCatDoors;
}

void Player::addCatDoor(CaseCatDoor *catDoor)
{
    if (!m_ownedCatDoors.contains(catDoor)) {
        m_ownedCatDoors.append(catDoor);
        emit catDoorCountChanged();
    }
}

void Player::removeCatDoor(CaseCatDoor *catDoor)
{
    m_ownedCatDoors.removeAll(catDoor);
    emit catDoorCountChanged();

}

QList<CaseCatDevice *> Player::ownedCatDevices() const
{
    return m_ownedCatDevices;
}

void Player::setInJail(bool inJail) {
    m_inJail = inJail;
    emit inJailChanged();
}

int Player::indexLogo() const
{
    return m_indexLogo;
}

void Player::setIndexLogo(int newIndexLogo)
{
    if (m_indexLogo == newIndexLogo)
        return;
    m_indexLogo = newIndexLogo;
    emit indexLogoChanged();
}
