#include "Case.h"

Case::Case(QObject *parent)
    : QObject{parent}
{}

int Case::position() const
{
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
