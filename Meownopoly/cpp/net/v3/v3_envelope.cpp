#include "v3_envelope.h"

#include <QCryptographicHash>
#include <QJsonDocument>
#include <QUuid>

V3Envelope V3Envelope::create(const QString &sessionId,
                              const QString &senderId,
                              const QString &kind,
                              quint64 seq,
                              const QJsonObject &payload,
                              const QString &correlationId)
{
    V3Envelope env;
    env.envelopeVersion = kV3EnvelopeVersion;
    env.messageId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    env.sessionId = sessionId;
    env.senderId = senderId;
    env.kind = kind;
    env.seq = seq;
    env.correlationId = correlationId;
    env.payload = payload;
    env.payloadHash = computePayloadHash(payload);
    return env;
}

QString V3Envelope::computePayloadHash(const QJsonObject &payload)
{
    // JSON compact : QJsonDocument sérialise les clés d'objet triées → forme
    // canonique déterministe, condition d'un hash comparable de bout en bout.
    const QByteArray compact = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    const QByteArray digest = QCryptographicHash::hash(compact, QCryptographicHash::Sha256);
    return QStringLiteral("sha256:") + QString::fromLatin1(digest.toHex());
}

QJsonObject V3Envelope::toJson() const
{
    QJsonObject obj;
    obj.insert(QStringLiteral("envelopeVersion"), envelopeVersion);
    obj.insert(QStringLiteral("messageId"), messageId);
    obj.insert(QStringLiteral("sessionId"), sessionId);
    obj.insert(QStringLiteral("senderId"), senderId);
    obj.insert(QStringLiteral("kind"), kind);
    // quint64 : QJsonValue n'a pas de ctor quint64 ; passer par double perdrait
    // de la précision au-delà de 2^53. Les séquences réalistes restent bien en
    // deçà — on stocke en nombre pour rester lisible/comparable dans le journal.
    obj.insert(QStringLiteral("seq"), static_cast<double>(seq));
    obj.insert(QStringLiteral("correlationId"), correlationId);
    obj.insert(QStringLiteral("payloadHash"), payloadHash);
    obj.insert(QStringLiteral("payload"), payload);
    return obj;
}

bool V3Envelope::fromJson(const QJsonObject &obj, V3Envelope &out)
{
    // Champs obligatoires + typage strict. Un manque = paquet malformé (rejeté
    // en amont par V3Protocol::unpack, jamais consommé à moitié).
    const QJsonValue vVersion = obj.value(QStringLiteral("envelopeVersion"));
    const QJsonValue vMessageId = obj.value(QStringLiteral("messageId"));
    const QJsonValue vSessionId = obj.value(QStringLiteral("sessionId"));
    const QJsonValue vSenderId = obj.value(QStringLiteral("senderId"));
    const QJsonValue vKind = obj.value(QStringLiteral("kind"));
    const QJsonValue vSeq = obj.value(QStringLiteral("seq"));
    const QJsonValue vPayload = obj.value(QStringLiteral("payload"));

    if (!vVersion.isDouble() || !vMessageId.isString() || !vSessionId.isString()
        || !vSenderId.isString() || !vKind.isString() || !vSeq.isDouble()
        || !vPayload.isObject()) {
        return false;
    }

    out.envelopeVersion = vVersion.toInt();
    out.messageId = vMessageId.toString();
    out.sessionId = vSessionId.toString();
    out.senderId = vSenderId.toString();
    out.kind = vKind.toString();
    out.seq = static_cast<quint64>(vSeq.toDouble());
    out.payload = vPayload.toObject();

    // Champs optionnels : tolérés absents (chaîne vide).
    out.correlationId = obj.value(QStringLiteral("correlationId")).toString();
    out.payloadHash = obj.value(QStringLiteral("payloadHash")).toString();

    return true;
}

bool V3Envelope::verifyPayloadHash() const
{
    if (payloadHash.isEmpty()) return false;
    return payloadHash == computePayloadHash(payload);
}

bool V3Envelope::isValid() const
{
    if (envelopeVersion != kV3EnvelopeVersion) return false;
    if (messageId.isEmpty() || sessionId.isEmpty() || senderId.isEmpty()
        || kind.isEmpty()) {
        return false;
    }
    return verifyPayloadHash();
}
