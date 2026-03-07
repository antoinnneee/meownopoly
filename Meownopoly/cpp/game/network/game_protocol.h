#ifndef GAME_PROTOCOL_H
#define GAME_PROTOCOL_H

#include "game_message_type.h"
#include <QByteArray>
#include <QJsonObject>
#include <QString>

/// Helpers statiques de sérialisation/désérialisation du protocole réseau de jeu.
///
/// Format paquet fiable : [1 byte: GameMessageType::Value][payload UTF-8 JSON]
/// Format paquet brut UDP minijeux : "MG:<x>;<y>;<vx>;<vy>"
class GameProtocol
{
public:
    // ── Paquets fiables ──────────────────────────────────────────────────────

    /// Construit un paquet fiable : [type byte][JSON payload UTF-8].
    static QByteArray pack(GameMessageType::Value type, const QJsonObject &payload = {});

    /// Décode un paquet fiable. Retourne false si le paquet est invalide.
    static bool unpack(const QByteArray &data,
                       GameMessageType::Value &outType,
                       QJsonObject &outPayload);

    // ── Paquets bruts UDP (minijeux) ─────────────────────────────────────────

    /// Encode une position minijeu en chaîne compacte envoyable en UDP brut.
    static QString packMinigameInput(qreal x, qreal y, qreal vx, qreal vy);

    /// Décode une chaîne UDP brute minijeu. Retourne false si format invalide.
    static bool unpackMinigameInput(const QString &msg,
                                    qreal &outX, qreal &outY,
                                    qreal &outVx, qreal &outVy);

private:
    GameProtocol() = delete;

    static constexpr char k_minigamePrefix[] = "MG:";
};

#endif // GAME_PROTOCOL_H
