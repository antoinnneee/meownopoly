#include "CaseFreeNap.h"
#include <QDebug>
#include "../player.h"

CaseFreeNap::CaseFreeNap(QObject *parent)
    : Case("Free Nap", -1, parent)
{
    setType(CT_FreeNap);
}

CaseFreeNap::CaseFreeNap(const QString &name, int position, QObject *parent)
    : Case(name, position, parent)
{
    setType(CT_FreeNap);
}

void CaseFreeNap::onLand(Player* player)
{
    qDebug() << "Player" << player->name() << "landed on Free Nap space at position" << position();
    // Free nap space - player can rest here without paying
    qDebug() << "Player is taking a free nap!";
}

int CaseFreeNap::pot() const {
    return m_pot;
}

void CaseFreeNap::setPot(int newPot) {
    m_pot = newPot;
}

void CaseFreeNap::addToPot(int amount) {
    m_pot += amount;
} 