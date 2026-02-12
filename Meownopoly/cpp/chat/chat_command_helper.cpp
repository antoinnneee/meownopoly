#include "chat_command_helper.h"
#include <QJsonDocument>
#include <QDebug>

ChatCommandHelper::ChatCommandHelper(QObject *parent) : QObject(parent)
{
}

QString ChatCommandHelper::formatCommand(const QString &type, const QJsonObject &payload)
{
    QJsonObject obj;
    obj["type"] = type;
    obj["payload"] = payload;
    return QJsonDocument(obj).toJson(QJsonDocument::Compact);
}

bool ChatCommandHelper::parseCommand(const QString &jsonString, QString &type, QJsonObject &payload)
{
    QJsonDocument doc = QJsonDocument::fromJson(jsonString.toUtf8());
    if (doc.isNull() || !doc.isObject()) {
        qWarning() << "[ChatCommandHelper] Failed to parse command JSON";
        return false;
    }

    QJsonObject obj = doc.object();
    type = obj["type"].toString();
    payload = obj["payload"].toObject();

    if (type.isEmpty()) {
        qWarning() << "[ChatCommandHelper] Command type is empty";
        return false;
    }

    return true;
}
