#ifndef CASERESTAREA_H
#define CASERESTAREA_H

#include <QObject>
#include "Case.h"
#include "../player.h"

enum RestQuality{
    RQ_NONE,
    RQ_1STAR,
    RQ_2STAR,
    RQ_3STAR,
    RQ_4STAR,
    RQ_HOTEL,
    RQ_COUNT
};

class CaseRestArea : public Case
{
    Q_OBJECT
public:
    explicit CaseRestArea(QObject *parent = nullptr);
    CaseRestArea(QString name,  QVector<int> price, QObject *parent = nullptr);

    RestQuality restQuality() const;
    void setRestQuality(RestQuality newRestQuality);

    Player *owner() const;
    void setOwner(Player *newOwner);

    QVector<int> price() const;
    void setPrice(const QVector<int> &newPrice);

    QString name() const;
    void setName(const QString &newName);

    void print_state();

private:
    enum CaseType type = CT_RestArea;
    QString m_name = "UNKNOW";
    enum RestQuality m_restQuality = RQ_NONE;
    Player *m_owner = nullptr;
    QVector<int> m_price;

};

#endif // CASERESTAREA_H
