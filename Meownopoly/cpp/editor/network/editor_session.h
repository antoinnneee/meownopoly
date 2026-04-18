#ifndef EDITOR_SESSION_H
#define EDITOR_SESSION_H

#include <QObject>
#include <QQmlEngine>
#include <QJsonObject>

/// Couche de session d'éditeur collaboratif, construite au-dessus de Catway.
///
/// Même modèle de rôle que GameSession :
///  - Hôte  : autoritaire sur la carte en cours d'édition, valide les ops,
///            les applique, puis les rediffuse à tous les clients.
///  - Client : envoie ses intentions (ops) à l'hôte, n'applique qu'au rebroadcast.
///
/// Coexiste avec GameSession sur le même canal Catway : le filtrage se fait
/// par plage de type-byte (EditorMessageType = 0x20+, GameMessageType = 0x01–0x11).
/// Par prudence, on refuse de démarrer EditorSession si GameSession est active.
class EditorSession : public QObject
{
    Q_OBJECT

    /// Vrai si la session est active (startAsHost ou startAsClient appelé).
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

    /// Vrai si le joueur local est l'hôte autoritaire.
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)

    /// Identifiant local du joueur (doit correspondre au playerId de Catway).
    Q_PROPERTY(QString localPlayerId READ localPlayerId NOTIFY localPlayerIdChanged)

    /// Identifiant de l'hôte de la session (vide si ce joueur est l'hôte).
    Q_PROPERTY(QString hostPlayerId READ hostPlayerId NOTIFY hostPlayerIdChanged)

    /// Identifiant de la session (transmis dans Welcome, utile pour les chemins d'autosave).
    Q_PROPERTY(QString sessionId READ sessionId NOTIFY sessionIdChanged)

    /// Sélections en cours des autres participants (présence).
    /// Format : { playerId -> [uuid, uuid, ...] } en valeurs QStringList.
    /// Mis à jour par onReliableReceived sur SelectionUpdate ; purgé quand un
    /// pair se déconnecte (best-effort, timeouts non implémentés en v1).
    Q_PROPERTY(QVariantMap remoteSelections READ remoteSelections NOTIFY remoteSelectionsChanged)

public:
    static void registerQml();
    static EditorSession *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    bool active() const           { return m_active; }
    bool isHost() const           { return m_isHost; }
    QString localPlayerId() const { return m_localPlayerId; }
    QString hostPlayerId() const  { return m_hostPlayerId; }
    QString sessionId() const     { return m_sessionId; }
    QVariantMap remoteSelections() const { return m_remoteSelections; }

    // ── Initialisation ───────────────────────────────────────────────────────

    /// Démarre la session en tant qu'hôte autoritaire.
    /// Échoue si GameSession est active.
    Q_INVOKABLE bool startAsHost(const QString &localPlayerId,
                                 const QString &sessionId = QString{});

    /// Démarre la session en tant que client.
    /// hostPlayerId doit correspondre au playerId Catway de l'hôte.
    /// Échoue si GameSession est active.
    Q_INVOKABLE bool startAsClient(const QString &localPlayerId,
                                   const QString &hostPlayerId,
                                   const QString &sessionId = QString{});

    /// Arrête la session et déconnecte les signaux.
    Q_INVOKABLE void stop();

    // ── Envoi ─────────────────────────────────────────────────────────────────

    /// Client → hôte : soumet une op d'édition (reliable).
    /// Si appelé par l'hôte, broadcast directement à tous (auteur inclus).
    Q_INVOKABLE void sendOp(const QJsonObject &op);

    /// Hôte uniquement : diffuse une op validée à tous les clients (reliable).
    Q_INVOKABLE void broadcastOp(const QJsonObject &op);

    /// Envoi générique d'un événement éditeur (reliable).
    Q_INVOKABLE void sendEvent(int type, const QJsonObject &payload = {});

    /// Hôte uniquement : broadcast d'un événement à tous (reliable).
    Q_INVOKABLE void broadcastEvent(int type, const QJsonObject &payload = {});

    /// Envoi point-à-point d'un événement éditeur (reliable).
    /// Utilisé notamment par l'hôte pour pousser un FullSync au seul client
    /// qui vient de rejoindre, sans polluer les autres pairs.
    Q_INVOKABLE void sendEventTo(const QString &playerId,
                                 int type,
                                 const QJsonObject &payload = {});

    /// Mise à jour de curseur — UDP brut (lossy), haute fréquence.
    Q_INVOKABLE void sendCursor(qreal x, qreal y);

signals:
    /// Op d'édition reçue (après validation/rebroadcast hôte pour un client,
    /// directement pour l'hôte).
    void opReceived(const QString &senderId, const QJsonObject &op);

    /// Op rejetée par l'hôte (reçue uniquement par l'émetteur originel).
    void opRejected(const QJsonObject &reject);

    /// Événement éditeur générique non-op (Hello/Welcome/FullSync/PlayerRoster…).
    void editorEventReceived(int type, const QString &senderId, const QJsonObject &payload);

    /// Mise à jour de sélection d'un autre joueur (reliable).
    void selectionReceived(const QString &senderId, const QJsonObject &payload);

    /// Mise à jour de curseur d'un autre joueur (UDP brut).
    void cursorReceived(const QString &senderId, qreal x, qreal y);

    void activeChanged();
    void isHostChanged();
    void localPlayerIdChanged();
    void hostPlayerIdChanged();
    void sessionIdChanged();
    void remoteSelectionsChanged();

private slots:
    void onReliableReceived(const QString &senderId, const QByteArray &data);
    void onUdpReceived(const QString &senderId, const QString &message);

private:
    explicit EditorSession(QObject *parent = nullptr);
    static EditorSession *m_pThis;

    void connectToCatway();
    void disconnectFromCatway();

    /// Hôte : relay un paquet fiable à tous les joueurs P2P connectés sauf senderId.
    void relayReliableToOthers(const QString &senderId, const QByteArray &packet);

    bool    m_active        = false;
    bool    m_isHost        = false;
    QString m_localPlayerId;
    QString m_hostPlayerId;
    QString m_sessionId;
    QVariantMap m_remoteSelections;  // playerId → QStringList d'uuids

    QMetaObject::Connection m_reliableConn;
    QMetaObject::Connection m_udpConn;

    static constexpr const char *k_cursorPrefix = "EC:";  // Editor Cursor (UDP brut)
};

#endif // EDITOR_SESSION_H
