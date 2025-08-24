#include "CaseCardBoardBox.h"
#include <QDebug>
#include "../player.h"

CaseCardBoardBox::CaseCardBoardBox(QObject *parent)
    : Case("Card Board Box", -1, parent)
{
    setType(Case::CS_CardBoardBox);
}

CaseCardBoardBox::CaseCardBoardBox(const QString &name, int uniqueId, QObject *parent)
    : Case(name, uniqueId, parent)
{
    setType(Case::CS_CardBoardBox);
}

QString CaseCardBoardBox::getJSON()
{
    QString json;
    json = Case::getJSON();
    json.removeLast();
    json += "}";
    return json;
}