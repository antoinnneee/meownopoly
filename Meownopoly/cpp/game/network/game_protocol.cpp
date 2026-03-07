#include "game_protocol.h"

#include <QJsonDocument>
#include <QStringList>

QByteArray GameProtocol::pack(GameMessageType::Value type, const QJsonObject &payload)
{
    QByteArray result;
    result.reserve(256);
    result.append(static_cast<char>(type));

    if (!payload.isEmpty()) {
        result.append(QJsonDocument(payload).toJson(QJsonDocument::Compact));
    }

    return result;
}

bool GameProtocol::unpack(const QByteArray &data,
                          GameMessageType::Value &outType,
                          QJsonObject &outPayload)
{
    if (data.isEmpty()) return false;

    outType = static_cast<GameMessageType::Value>(static_cast<quint8>(data.at(0)));

    if (data.size() > 1) {
        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(data.mid(1), &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) return false;
        outPayload = doc.object();
    } else {
        outPayload = QJsonObject{};
    }

    return true;
}

QString GameProtocol::packMinigameInput(qreal x, qreal y, qreal vx, qreal vy)
{
    return QStringLiteral("MG:%1;%2;%3;%4")
        .arg(x, 0, 'f', 2)
        .arg(y, 0, 'f', 2)
        .arg(vx, 0, 'f', 2)
        .arg(vy, 0, 'f', 2);
}

bool GameProtocol::unpackMinigameInput(const QString &msg,
                                       qreal &outX, qreal &outY,
                                       qreal &outVx, qreal &outVy)
{
    if (!msg.startsWith(QLatin1String("MG:"))) return false;

    const QStringList parts = msg.mid(3).split(QLatin1Char(';'));
    if (parts.size() != 4) return false;

    bool ok1, ok2, ok3, ok4;
    outX  = parts[0].toDouble(&ok1);
    outY  = parts[1].toDouble(&ok2);
    outVx = parts[2].toDouble(&ok3);
    outVy = parts[3].toDouble(&ok4);

    return ok1 && ok2 && ok3 && ok4;
}
