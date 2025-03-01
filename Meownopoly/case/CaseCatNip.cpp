#include "CaseCatNip.h"
#include <QDebug>

CaseCatNip::CaseCatNip(const QString &name, int position)
    : Case(name, position) {}

void CaseCatNip::onLand(Player* player) {
    // Implement logic for chance card
    qDebug() << "Player landed on a Chance case.";
} 