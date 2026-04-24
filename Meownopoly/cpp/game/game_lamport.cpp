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

// Pas de drift float : le compteur reste int (m_lamportClock), on scale juste
// à la sortie. Step = 1e-6 par tick → ~1M ticks avant d'empiéter sur le
// zLayer suivant (zOrder approche de 1.0). La formule de rendu originale
// `z = zOrder + zLayer` est préservée : zOrder tient dans ]0, 1[, zLayer
// domine naturellement.
//
// Sync on receive : on inverse le scale pour retrouver le compteur entier.
static constexpr double kLamportStep = 1e-6;

static double ensureJitter(double &jitter)
{
    if (jitter == 0.0) {
        // Jitter sub-step pour désambiguer les ticks concurrents entre peers
        // sans franchir le pas suivant : jitter ∈ ]0, kLamportStep/2[.
        jitter = (QRandomGenerator::global()->generateDouble() * 0.49 + 0.01)
                 * kLamportStep;
    }
    return jitter;
}

double Game::tickLamport()
{
    ensureJitter(m_lamportJitter);
    ++m_lamportClock;
    emit lamportClockChanged();
    return static_cast<double>(m_lamportClock) * kLamportStep + m_lamportJitter;
}

double Game::previewZOrder() const
{
    // Valeur que tickLamport() retournerait au prochain appel sans muter
    // le compteur. Si le jitter n'est pas encore initialisé, on prend la
    // moitié du step comme placeholder cohérent.
    double jitter = (m_lamportJitter != 0.0) ? m_lamportJitter : kLamportStep * 0.25;
    return static_cast<double>(m_lamportClock + 1) * kLamportStep + jitter;
}

void Game::syncLamport(double remote)
{
    if (!std::isfinite(remote)) return;
    // Inverse du scale : le remote a été émis avec zOrder = clock * step + jitter.
    // round(remote / step) retrouve la partie entière du compteur, tant que
    // jitter < step/2 (garanti par ensureJitter).
    qint64 remoteInt = static_cast<qint64>(std::round(remote / kLamportStep));
    if (remoteInt > m_lamportClock) {
        m_lamportClock = remoteInt;
        emit lamportClockChanged();
    }
}

void Game::resetLamport()
{
    m_lamportClock  = 0;
    m_lamportJitter = 0.0;  // sera re-tiré au prochain tick
    emit lamportClockChanged();
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
        qint64 v = static_cast<qint64>(std::round(dp->zOrder() / kLamportStep));
        if (v > maxClock) maxClock = v;
    }
    if (maxClock != m_lamportClock) {
        m_lamportClock = maxClock;
        emit lamportClockChanged();
    }
}
