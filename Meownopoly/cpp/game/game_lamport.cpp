#include "game.h"

#include <QRandomGenerator>
#include <algorithm>
#include <cmath>

#include "item_snapable/ItemSnapable.h"
#include "item_snapable/Displayparameter.h"
#include "map/map.h"

// ==================== LAMPORT CLOCK ====================
//
// Le zOrder retourné est `(double)m_lamportClock + m_lamportJitter`.
//  - Partie entière  : compteur logique monotone, synchronisé entre peers.
//  - Partie fraction : offset sub-1.0 tiré au hasard une fois par session
//                      (constant par peer). Permet que deux peers ayant
//                      tické concurremment (même m_lamportClock) produisent
//                      quand même des zOrder distincts au rendu — sinon Qt
//                      résout les égalités par ordre de création, qui
//                      diffère entre peers et cause du z-fighting.
//
// Sync on receive : `m_lamportClock = max(m_lamportClock, floor(remote))`.
// Pas de "+1" ici : ce n'est pas un event local, on ajuste juste pour que
// le PROCHAIN tick local soit > à tout ce qu'on a vu. (Lamport classique
// fait +1 pour l'event reçu lui-même, mais ici la réception ne crée pas
// de tile locale — c'est l'app du delta qui compte, et son zOrder est
// déjà transporté dans le message.)

double Game::tickLamport()
{
    // Init paresseuse du jitter : une fois par instance, valeur stable pour
    // toute la session. Petit (<1.0) pour ne pas interférer avec l'ordre
    // total entre ticks différents.
    if (m_lamportJitter == 0.0) {
        m_lamportJitter = QRandomGenerator::global()->generateDouble() * 0.999
                          + 1e-6;  // ∈ ]0, 1[
    }
    ++m_lamportClock;
    return static_cast<double>(m_lamportClock) + m_lamportJitter;
}

void Game::syncLamport(double remote)
{
    if (!std::isfinite(remote)) return;
    qint64 remoteInt = static_cast<qint64>(std::floor(remote));
    if (remoteInt > m_lamportClock)
        m_lamportClock = remoteInt;
}

void Game::resetLamport()
{
    m_lamportClock  = 0;
    m_lamportJitter = 0.0;  // sera re-tiré au prochain tick
}

void Game::syncLamportFromMap(Map *map)
{
    if (!map) return;
    qint64 maxClock = m_lamportClock;
    const QList<ItemSnapable*> tiles = map->tiles();
    for (ItemSnapable *t : tiles) {
        if (!t) continue;
        DisplayParameter *dp = t->displayParameter();
        if (!dp) continue;
        qint64 v = static_cast<qint64>(std::floor(dp->zOrder()));
        if (v > maxClock) maxClock = v;
    }
    m_lamportClock = maxClock;
}
