#include "player.h"

Player::Player(QObject *parent)
    : QObject{parent}
{}

int Player::position() const
{
    return m_position;
}

void Player::setPosition(int newPosition)
{
    m_position = newPosition;
}

int Player::croquettes() const
{
    return m_croquettes;
}

void Player::setCroquettes(int newCroquettes)
{
    m_croquettes = newCroquettes;
}
