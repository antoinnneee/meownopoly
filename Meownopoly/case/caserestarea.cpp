#include "caserestarea.h"
#include "qdebug.h"

CaseRestArea::CaseRestArea(QObject *parent)
    : Case{parent}
{
    int i = 0;
    while (i < RQ_COUNT)
    {
        m_price.append(0);
    }
}

CaseRestArea::CaseRestArea(QString name, QVector<int> price, QObject *parent)
    : Case{parent}, m_name(name), m_price(price)
{
    while (m_price.count() < RQ_COUNT)
    {
        m_price.append(0);
    }
}

RestQuality CaseRestArea::restQuality() const
{
    return m_restQuality;
}

void CaseRestArea::setRestQuality(RestQuality newRestQuality)
{
    m_restQuality = newRestQuality;
}

Player *CaseRestArea::owner() const
{
    return m_owner;
}

void CaseRestArea::setOwner(Player *newOwner)
{
    m_owner = newOwner;
}

QVector<int> CaseRestArea::price() const
{
    return m_price;
}

void CaseRestArea::setPrice(const QVector<int> &newPrice)
{
    m_price = newPrice;
}

QString CaseRestArea::name() const
{
    return m_name;
}

void CaseRestArea::setName(const QString &newName)
{
    m_name = newName;
}

void CaseRestArea::print_state()
{
    qDebug() << "Quality[" << m_restQuality << "] name[" << m_name << "] price[" << m_price <<"]";
}
