#include "Case.h"
#include "../player.h"
#include <QDebug>

Case::Case(QObject *parent)
    : QObject(parent), m_name("Unknown"), m_position(-1), type(CT_Unknow) {}

Case::Case(const QString &name, int position, QObject *parent)
    : QObject(parent), m_name(name), m_position(position), type(CT_Unknow) {}

int Case::position() const {
    return m_position;
}

void Case::setPosition(int newPosition)
{
    m_position = newPosition;
}

CaseType Case::getType() const
{
    return type;
}

void Case::setType(CaseType newType)
{
    type = newType;
}

QString Case::name() const
{
    return m_name;
}

void Case::setName(const QString &newName)
{
    m_name = newName;
}

void Case::onLand(Player* player)
{
    // Default implementation - can be overridden by derived classes
    Q_UNUSED(player);
}
