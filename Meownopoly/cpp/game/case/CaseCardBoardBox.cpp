#include "CaseCardBoardBox.h"
#include <QDebug>
#include "game/player.h"

CaseCardBoardBox::CaseCardBoardBox(QObject *parent)
    : Case("Card Board Box", parent)
{
    setType(Case::CS_CardBoardBox);
}

CaseCardBoardBox::CaseCardBoardBox(const QString &name, QObject *parent)
    : Case(name, parent)
{
    setType(Case::CS_CardBoardBox);
}

CaseCardBoardBox::CaseCardBoardBox(const QJsonObject &json, QObject *parent)
    : Case(json, parent)
{
    setType(Case::CS_CardBoardBox);
}
