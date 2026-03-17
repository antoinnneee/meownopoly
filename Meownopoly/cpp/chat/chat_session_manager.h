#ifndef CHAT_SESSION_MANAGER_H
#define CHAT_SESSION_MANAGER_H

#include <QObject>
#include <QQmlEngine>
#include <QTimer>
#include <QList>
#include "chat_client.h"

/**
 * Singleton centralisant la gestion de toutes les sessions de chat actives.
 *
 * Responsabilitees :
 *  - Maintenir un serverQueryClient dediee a LIST_SESSIONS (jamais en session)
 *  - Gerer un QList<ChatClient*> de sessions rejointes simultanément
 *  - Rafraichir automatiquement la liste des sessions toutes les 10s
 *  - Exposer setActiveSession() qui délègue à Catway::setChatClient()
 *  - Fournir des accesseurs statiques C++ (getSessionCount, etc.)
 */
class ChatSessionManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList availableSessions READ availableSessions NOTIFY availableSessionsChanged)
    Q_PROPERTY(int totalPlayerCount READ totalPlayerCount NOTIFY statsChanged)
    Q_PROPERTY(int activeSessionCount READ activeSessionCount NOTIFY statsChanged)
    Q_PROPERTY(bool serverConnected READ serverConnected NOTIFY serverConnectedChanged)

public:
    static ChatSessionManager *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static void registerQml();

    /** Retourne le nom d'une session � partir de son ID, ou l'ID si non trouv�. */
    Q_INVOKABLE QString sessionNameForId(const QString &sessionId) const;

    // --- Accesseurs statiques C++ (délèguent à instance()) ---
    static int          getSessionCount();
    static int          getTotalPlayerCount();
    static QVariantList getAvailableSessions();

    // --- Propriétés ---
    QVariantList availableSessions() const { return m_availableSessions; }
    int          totalPlayerCount()  const { return m_totalPlayerCount; }
    int          activeSessionCount() const { return m_sessions.size(); }
    bool         serverConnected()   const;

    // --- API QML ---

    /** Retourne le client dédié à la liste des sessions (jamais en session). */
    Q_INVOKABLE ChatClient *serverClient() const { return m_serverQueryClient; }

    /**
     * Creer un nouveau ChatClient, le connecte au serveur et le fait rejoindre sessionId.
     * Si sessionId est déjà rejoint, retourne le client existant.
     * L'appelant est responsable d'appeler setActiveSession() si ce client doit etre actif.
     */
    Q_INVOKABLE ChatClient *joinSession(const QString &sessionId, const QString &password);

    /**
     * Crée une nouvelle session sur le serveur via un client dédié.
     * Le client rejoint automatiquement la session après sa création.
     * Retourne le client pour permettre à l'appelant d'appeler setActiveSession().
     */
    Q_INVOKABLE ChatClient *createAndJoinSession(const QString &name, const QString &password);

    /** Quitte une session et détruit le ChatClient associé. */
    Q_INVOKABLE void leaveSession(ChatClient *client);

    /** Définit le client actif via Catway::setChatClient(). */
    Q_INVOKABLE void setActiveSession(ChatClient *client);

    /** Retourne le client associé à sessionId, ou nullptr. */
    Q_INVOKABLE ChatClient *clientForSession(const QString &sessionId) const;

    /** Force un rafraîchissement immédiat de la liste des sessions. */
    Q_INVOKABLE void requestSessionsRefresh();

signals:
    void availableSessionsChanged();
    void statsChanged();
    void serverConnectedChanged();
    void sessionJoined(ChatClient *client, const QString &sessionId);
    void sessionLeft(const QString &sessionId);
    /** Erreur sur un client de session (ex. INVALID_PASSWORD). errorType = ChatClient::ErrorSession enum. */
    void sessionError(const QString &sessionId, const QString &error, int errorType);

private:
    explicit ChatSessionManager(QObject *parent = nullptr);
    ~ChatSessionManager() override;

    static ChatSessionManager *m_pThis;

    void connectServerClient();
    void updateTotalPlayerCount();
    /** Enregistre client dans m_sessions et connecte les signaux de stats/erreur. */
    void connectSessionClient(ChatClient *client, const QString &sessionId);

    ChatClient        *m_serverQueryClient = nullptr;
    QList<ChatClient *> m_sessions;
    QTimer            *m_refreshTimer = nullptr;

    QVariantList m_availableSessions;
    int          m_totalPlayerCount = 0;

    static constexpr int         REFRESH_INTERVAL_MS = 100000;
    static constexpr const char *SERVER_URL = "ws://pattounecorp.ovh:3000";
};

#endif // CHAT_SESSION_MANAGER_H
