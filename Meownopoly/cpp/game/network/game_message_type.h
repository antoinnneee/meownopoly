#ifndef GAME_MESSAGE_TYPE_H
#define GAME_MESSAGE_TYPE_H

#include <QObject>

/// Types de messages du protocole réseau de jeu.
/// Le premier octet de chaque paquet fiable identifie le type.
/// Les types >= 0x10 sont envoyés en UDP brut (minijeux, temps réel).
namespace GameMessageType {
Q_NAMESPACE

enum Value : quint8 {
    // ── Canal fiable (reliable UDP) ─────────────────────────────────────────
    GameStart           = 0x01,  // broadcast hôte : début de partie
    GameEnd             = 0x02,  // broadcast hôte : fin de partie
    TurnStart           = 0x03,  // broadcast hôte : début du tour { playerId }
    DiceRoll            = 0x04,  // client → hôte : résultat dé { value }
    PlayerMove          = 0x05,  // broadcast hôte : déplacement { playerId, caseId }
    BuyProperty         = 0x06,  // client → hôte : achat { caseId }
    PayRent             = 0x07,  // broadcast hôte : loyer { fromId, toId, amount }
    CardDraw            = 0x08,  // broadcast hôte : tirage carte { cardType, cardId }
    JailEnter           = 0x09,  // broadcast hôte : emprisonnement { playerId }
    JailLeave           = 0x0A,  // broadcast hôte : sortie prison { playerId }
    PlayerJoined        = 0x0B,  // broadcast hôte : joueur connecté { playerId, nickname }
    PlayerLeft          = 0x0C,  // broadcast hôte : joueur déconnecté { playerId }
    MapSync             = 0x0D,  // sync JSON complet de la map { map: {...} }

    // ── Canal brut UDP (minijeux, temps réel, perte tolérable) ──────────────
    MinigameInput       = 0x10,  // input joueur { x, y, vx, vy } — 60 Hz, lossy
    MinigameSnapshot    = 0x11,  // snapshot complet autoritaire envoyé en reliable ~1 Hz
};
Q_ENUM_NS(Value)

}

#endif // GAME_MESSAGE_TYPE_H
