#include "chat_slash_commands.h"
#include <QQmlEngine>
#include <QJSEngine>

const QString ChatSlashCommands::CMD_PING = QStringLiteral("/ping");
const QString ChatSlashCommands::CMD_STUN = QStringLiteral("/stun");
const QString ChatSlashCommands::CMD_CREATE = QStringLiteral("/create");

QStringList ChatSlashCommands::s_allCommands = { CMD_PING, CMD_STUN, CMD_CREATE };

ChatSlashCommands::ChatSlashCommands(QObject *parent)
    : QObject(parent)
{
}

void ChatSlashCommands::registerQml()
{
    qmlRegisterSingletonType<ChatSlashCommands>("Meownopoly.Chat", 1, 0, "SlashCommands", &ChatSlashCommands::qmlInstance);
}

QObject *ChatSlashCommands::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    static ChatSlashCommands instance;
    return &instance;
}

QStringList ChatSlashCommands::commands() const
{
    return s_allCommands;
}

QString ChatSlashCommands::commandFromText(const QString &text) const
{
    const QString trimmed = text.trimmed();
    for (const QString &cmd : s_allCommands) {
        if (trimmed.startsWith(cmd))
            return cmd;
    }
    return QString();
}
