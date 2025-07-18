#include "CaseCardBoardBox.h"
#include <QDebug>
#include "../player.h"

CaseCardBoardBox::CaseCardBoardBox(QObject *parent)
    : Case("Card Board Box", -1, parent)
{
    setType(Case::CS_CardBoardBox);
}

CaseCardBoardBox::CaseCardBoardBox(const QString &name, int position, QObject *parent)
    : Case(name, position, parent)
{
    setType(Case::CS_CardBoardBox);
}
