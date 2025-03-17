#include "CaseCardBoardBox.h"
#include <QDebug>
#include "../player.h"

CaseCardBoardBox::CaseCardBoardBox(QObject *parent)
    : Case("Card Board Box", -1, parent)
{
    setType(CT_CardBoardBox);
}

CaseCardBoardBox::CaseCardBoardBox(const QString &name, int position, QObject *parent)
    : Case(name, position, parent)
{
    setType(CT_CardBoardBox);
}

void CaseCardBoardBox::onLand(Player* player)
{
    Q_UNUSED(player);
    qDebug() << "Player landed on Card Board Box";
    // TODO: Implement community chest card logic
} 
