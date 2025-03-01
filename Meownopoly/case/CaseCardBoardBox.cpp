#include "CaseCardBoardBox.h"
#include <QDebug>

CaseCardBoardBox::CaseCardBoardBox(const QString &name, int position)
    : Case(name, position) {}

void CaseCardBoardBox::onLand(Player* player) {
    // Implement logic for community chest card
    qDebug() << "Player landed on a Community Chest case.";
} 
