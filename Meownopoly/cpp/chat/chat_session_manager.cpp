#include "chat_session_manager.h"
#include "communication/catway.h"
#include "tools/logger.h"

#include <QQmlEngine>

ChatSessionManager *ChatSessionManager::m_pThis = nullptr;

// ---------------------------------------------------------------------------
// Construction / Destruction
// ---------------------------------------------------------------------------

ChatSessionManager::ChatSessionManager(QObject *parent)
    : QObject(parent)
{
    // --- Server query client ---
    // Ce client est uniquement connecté au serveur pour récupérer la liste des
    // sessions. Il ne rejoint jamais de session.
    m_serverQueryClient = new ChatClient(this);

    connect(m_serverQueryClient, &ChatClient::connectedChanged, this, [this]() {
        if (m_serverQueryClient->isConnected()) {
            Logger::instance()->info("Server client connected, requesting sessions...", "ChatSessionManager");
            m_serverQueryClient->requestSessionsList();
            m_refreshTimer->start();
        } else {
            Logger::instance()->warn("Server client disconnected, scheduling reconnect...", "ChatSessionManager");
            m_refreshTimer->stop();
            QTimer::singleShot(5000, this, &ChatSessionManager::connectServerClient);
        }
        emit serverConnectedChanged();
    });

    connect(m_serverQueryClient, &ChatClient::availableSessionsChanged, this, [this]() {
        m_availableSessions = m_serverQueryClient->availableSessions();
        updateTotalPlayerCount();
        emit availableSessionsChanged();
    });

    // --- Refresh timer (main thread, lightweight) ---
    m_refreshTimer = new QTimer(this);
    m_refreshTimer->setInterval(REFRESH_INTERVAL_MS);
    m_refreshTimer->setSingleShot(false);
    connect(m_refreshTimer, &QTimer::timeout, this, [this]() {
        if (m_serverQueryClient->isConnected()) {
            m_serverQueryClient->requestSessionsList();
        }
    });

    connectServerClient();
}

ChatSessionManager::~ChatSessionManager()
{
    m_refreshTimer->stop();
}

// ---------------------------------------------------------------------------
// Singleton
// ---------------------------------------------------------------------------

ChatSessionManager *ChatSessionManager::instance()
{
    if (!m_pThis) {
        m_pThis = new ChatSessionManager();
    }
    return m_pThis;
}

QObject *ChatSessionManager::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    return ChatSessionManager::instance();
}

void ChatSessionManager::registerQml()
{
    qmlRegisterSingletonType<ChatSessionManager>(
        "Meownopoly.Chat", 1, 0, "ChatSessionManager",
        &ChatSessionManager::qmlInstance);
}


// ---------------------------------------------------------------------------
// Accesseurs statiques C++
// ---------------------------------------------------------------------------

int ChatSessionManager::getSessionCount()
{
    return instance()->activeSessionCount();
}

int ChatSessionManager::getTotalPlayerCount()
{
    return instance()->m_totalPlayerCount;
}

QVariantList ChatSessionManager::getAvailableSessions()
{
    return instance()->m_availableSessions;
}

// ---------------------------------------------------------------------------
// Propriétés
// ---------------------------------------------------------------------------

bool ChatSessionManager::serverConnected() const
{
    return m_serverQueryClient && m_serverQueryClient->isConnected();
}

// ---------------------------------------------------------------------------
// API QML
// ---------------------------------------------------------------------------

ChatClient *ChatSessionManager::joinSession(const QString &sessionId, const QString &password)
{
    // Vérifier si la session est déjà rejointe
    ChatClient *existing = clientForSession(sessionId);
    if (existing) {
        Logger::instance()->warn("Already joined session: " + sessionId, "ChatSessionManager");
        return existing;
    }

    ChatClient *client = new ChatClient(this);

    connectSessionClient(client, sessionId);

    // Rejoindre la session dès que le WebSocket est établi.
    // La connexion n'est PAS single-shot : elle se déclenche aussi sur reconnexion,
    // ce qui re-envoie JOIN_SESSION au serveur automatiquement.
    connect(client, &ChatClient::connectedChanged, this, [client, sessionId, password]() {
        if (client->isConnected()) {
            client->connectToSessionDirect(sessionId, password);
        }
    });

    client->connectToServer(SERVER_URL);
    emit sessionJoined(client, sessionId);
    Logger::instance()->info("Joining session: " + sessionId, "ChatSessionManager");

    return client;
}

ChatClient *ChatSessionManager::createAndJoinSession(const QString &name, const QString &password)
{
    ChatClient *client = new ChatClient(this);

    // L'id de session n'est pas encore connu (le serveur l'assignera via sessionCreated).
    // On connecte le signal pour enregistrer le client une fois la session confirmée.
    connect(client, &ChatClient::sessionIdChanged, this, [this, client]() {
        const QString sid = client->sessionId();
        if (!sid.isEmpty() && !m_sessions.contains(client)) {
            connectSessionClient(client, sid);
            emit sessionJoined(client, sid);
            Logger::instance()->info("Session created and joined: " + sid, "ChatSessionManager");
        }
    });

    connect(client, &ChatClient::connectedChanged, this, [client, name, password]() {
        if (client->isConnected()) {
            client->createSession(name, password);
        }
    });

    client->connectToServer(SERVER_URL);
    return client;
}

void ChatSessionManager::leaveSession(ChatClient *client)
{
    if (!client) return;

    int idx = m_sessions.indexOf(client);
    if (idx < 0) return;

    const QString sessionId = client->sessionId();
    m_sessions.removeAt(idx);

    emit sessionLeft(sessionId);
    emit statsChanged();

    client->deleteLater();
    Logger::instance()->info("Left session: " + sessionId, "ChatSessionManager");
}

void ChatSessionManager::setActiveSession(ChatClient *client)
{
    Catway::instance()->setChatClient(client);
    Logger::instance()->info(
        "Active session set: " + (client ? client->sessionId() : QStringLiteral("null")),
        "ChatSessionManager");
}

ChatClient *ChatSessionManager::clientForSession(const QString &sessionId) const
{
    for (ChatClient *c : m_sessions) {
        if (c->sessionId() == sessionId) return c;
    }
    return nullptr;
}

QString ChatSessionManager::sessionNameForId(const QString &sessionId) const
{
    for (const QVariant &v : m_availableSessions) {
        QVariantMap session = v.toMap();
        if (session.value("sessionId").toString() == sessionId)
            return session.value("name", sessionId).toString();
    }
    return sessionId;
}

void ChatSessionManager::requestSessionsRefresh()
{
    if (m_serverQueryClient && m_serverQueryClient->isConnected()) {
        m_serverQueryClient->requestSessionsList();
    }
}

// ---------------------------------------------------------------------------
// Privé
// ---------------------------------------------------------------------------

void ChatSessionManager::connectSessionClient(ChatClient *client, const QString &sessionId)
{
    m_sessions.append(client);
    emit statsChanged();

    connect(client, &ChatClient::participantsChanged, this, [this]() {
        updateTotalPlayerCount();
        emit statsChanged();
    });

    // Propagation des erreurs vers le lobby/UI
    connect(client, &ChatClient::errorOccurred, this,
            [this, client](const QString &error, ChatClient::ErrorSession errorType) {
        const QString sid = client->sessionId().isEmpty()
                                ? QStringLiteral("unknown")
                                : client->sessionId();
        // Sur INVALID_PASSWORD, retirer le client échoué de la liste
        if (errorType == ChatClient::INVALID_PASSWORD) {
            int idx = m_sessions.indexOf(client);
            if (idx >= 0) {
                m_sessions.removeAt(idx);
                emit statsChanged();
                client->deleteLater();
            }
        }
        emit sessionError(sid, error, static_cast<int>(errorType));
    });

    Q_UNUSED(sessionId)
}

void ChatSessionManager::connectServerClient()
{
    Logger::instance()->info(
        QStringLiteral("Connecting server client to ") + SERVER_URL,
        "ChatSessionManager");
    m_serverQueryClient->connectToServer(SERVER_URL);
}

void ChatSessionManager::updateTotalPlayerCount()
{
    int total = 0;
    for (const QVariant &v : m_availableSessions) {
        total += v.toMap().value("players", 0).toInt();
    }
    if (total != m_totalPlayerCount) {
        m_totalPlayerCount = total;
        emit statsChanged();
    }
}
