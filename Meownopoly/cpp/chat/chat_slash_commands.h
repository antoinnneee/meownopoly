#ifndef CHAT_SLASH_COMMANDS_H
#define CHAT_SLASH_COMMANDS_H

#include <QObject>
#include <QStringList>

class QQmlEngine;
class QJSEngine;

/**
 * Répertoire unique des commandes slash du chat.
 * Utiliser les constantes en C++ et le singleton SlashCommands en QML.
 */
class ChatSlashCommands : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList commands READ commands CONSTANT)
    Q_PROPERTY(QString ping READ ping CONSTANT)
    Q_PROPERTY(QString stun READ stun CONSTANT)
    Q_PROPERTY(QString create READ create CONSTANT)

public:
    explicit ChatSlashCommands(QObject *parent = nullptr);

    static void registerQml();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    /// Liste de toutes les commandes (ex. ["/ping", "/stun"]).
    QStringList commands() const;
    /// Retourne la commande si \a text commence par une commande connue, sinon "".
    Q_INVOKABLE QString commandFromText(const QString &text) const;

    /// Constantes pour usage C++ (même ordre que commands()).
    static const QString CMD_PING;
    static const QString CMD_STUN;
    static const QString CMD_CREATE;

    QString ping() const { return CMD_PING; }
    QString stun() const { return CMD_STUN; }
    QString create() const { return CMD_CREATE; }

private:
    static QStringList s_allCommands;
};

#endif // CHAT_SLASH_COMMANDS_H
