#include "CaseCatDevice.h"
#include "../player.h"

CaseCatDevice::CaseCatDevice() {}

void CaseCatDevice::buy(Player *player) {

    player->spendKibble(100);
}

