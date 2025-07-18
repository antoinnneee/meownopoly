#include "CaseCatNip.h"
#include <QDebug>
#include "../player.h"

CaseCatNip::CaseCatNip(QObject *parent)
    : Case("Cat Nip", -1, parent)
{
    setType(Case::CS_CatNip);
}

CaseCatNip::CaseCatNip(const QString &name, int position, QObject *parent)
    : Case(name, position, parent)
{
    setType(Case::CS_CatNip);
}

void CaseCatNip::onLand(Player* player)
{
    Q_UNUSED(player);
    qDebug() << "Player landed on Cat Nip";
    // TODO: Implement chance card logic
} 