#include "CaseCardBoardBox.h"
#include <QDebug>
#include "../player.h"

CaseCardBoardBox::CaseCardBoardBox(QObject *parent)
    : Case("Card Board Box", QUuid::createUuid(), parent)
{
    setType(Case::CS_CardBoardBox);
}

CaseCardBoardBox::CaseCardBoardBox(const QString &name, QUuid uniqueId, QObject *parent)
    : Case(name, uniqueId, parent)
{
    setType(Case::CS_CardBoardBox);
}

CaseCardBoardBox::CaseCardBoardBox(const QJsonObject &json, QObject *parent)
    : Case(json, parent)
{
    setType(Case::CS_CardBoardBox);
}

QString CaseCardBoardBox::toJSON()
{
    QString json;
    json = Case::toJSON();
    json.removeLast();
    json.removeLast();
    json += "\n}";
    return json;
}
