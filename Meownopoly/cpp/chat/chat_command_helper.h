#ifndef CHAT_COMMAND_HELPER_H
#define CHAT_COMMAND_HELPER_H

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonDocument>

class ChatCommandHelper : public QObject
{
    Q_OBJECT
public:
    explicit ChatCommandHelper(QObject *parent = nullptr);

    /**
     * Formats a command as a JSON string.
     * @param type The type of the command (e.g., "GAME_START", "MOVE_PLAYER").
     * @param payload The data associated with the command.
     * @return A JSON string representing the command.
     */
    static QString formatCommand(const QString &type, const QJsonObject &payload);

    /**
     * Parses a command JSON string.
     * @param jsonString The JSON string to parse.
     * @param type Output parameter for the command type.
     * @param payload Output parameter for the command payload.
     * @return true if parsing was successful, false otherwise.
     */
    static bool parseCommand(const QString &jsonString, QString &type, QJsonObject &payload);
};

#endif // CHAT_COMMAND_HELPER_H
