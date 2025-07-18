#include "Case.h"
#include "../player.h"
#include <QDebug>

    Case::Case(QObject *parent)
    : QObject(parent), m_name("Unknown"), m_position(-1), type(Case::CS_Unknow) {}

    Case::Case(const QString &name, int position, QObject *parent)
    : QObject(parent), m_name(name), m_position(position), type(Case::CS_Unknow) {}

int Case::position() const {
    return m_position;
}

void Case::setPosition(int newPosition)
{
    m_position = newPosition;
    emit positionChanged();
}

Case::CaseType Case::getType() const
{
    return type;
}

void Case::setType(CaseType newType)
{
    type = newType;
    emit typeChanged();
}

QString Case::name() const
{
    return m_name;
}

void Case::setName(const QString &newName)
{
    qDebug()<< "name changed in CPP " << newName;
    m_name = newName;
    emit nameChanged();
}

void Case::onLand(Player* player)
{
    // Default implementation - can be overridden by derived classes
    Q_UNUSED(player);
}

void Case::onLeave(Player* player)
{
    // Default implementation - can be overridden by derived classes
    Q_UNUSED(player);
}

void Case::onHover(Player* player)
{
    // Default implementation - can be overridden by derived classes
    Q_UNUSED(player);
}
