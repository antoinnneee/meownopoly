#ifndef GAME_SESSION_H
#define GAME_SESSION_H

#include <QObject>
#include <QQmlEngine>
#include <QJsonObject>

/// Couche de session de jeu réseau, construite au-dessus de Catway.
///
/// Rôles :
///  - Hôte  : autoritaire, valide les actions, broadcast l'état à tous.
///  - Client : envoie les intentions à l'hôte, reçoit et applique les états.
///
/// Canal fiable  → événements de jeu Monopoly (achat, dé, tour, MapSync…)
/// Canal UDP brut → inputs minijeux temps réel (PattounX, 60 Hz, lossy)
class GameSession : public QObject
{
    Q_OBJECT

    /// Vrai si la session est active (initAsHost ou initAsClient appelé).
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

    /// Vrai si le joueur local est l'hôte autoritaire.
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)

    /// Identifiant local du joueur (doit correspondre au playerId de Catway).
    Q_PROPERTY(QString localPlayerId READ localPlayerId NOTIFY localPlayerIdChanged)

    /// Identifiant de l'hôte de la session (vide si ce joueur est l'hôte).
    Q_PROPERTY(QString hostPlayerId READ hostPlayerId NOTIFY hostPlayerIdChanged)

public:
    static void registerQml();
    static GameSession *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    bool active() const           { return m_active; }
    bool isHost() const           { return m_isHost; }
    QString localPlayerId() const { return m_localPlayerId; }
    QString hostPlayerId() const  { return m_hostPlayerId; }

    // ── Initialisation ───────────────────────────────────────────────────────

    /// Démarre la session en tant qu'hôte autoritaire.
    Q_INVOKABLE void startAsHost(const QString &localPlayerId);

    /// Démarre la session en tant que client.
    /// hostPlayerId doit correspondre au playerId Catway de l'hôte.
    Q_INVOKABLE void startAsClient(const QString &localPlayerId,
                                   const QString &hostPlayerId);

    /// Arrête la session et déconnecte les signaux.
    Q_INVOKABLE void stop();

    // ── Envoi ─────────────────────────────────────────────────────────────────

    /// Client → hôte : envoie une intention de jeu (reliable).
    /// Si appelé par l'hôte, broadcast directement à tous.
    Q_INVOKABLE void sendEvent(int type, const QJsonObject &payload = {});

    /// Hôte uniquement : broadcast un événement validé à tous les joueurs (reliable).
    Q_INVOKABLE void broadcastEvent(int type, const QJsonObject &payload = {});

    /// Envoie la synchronisation complète de la map en JSON (reliable).
    /// Destiné à être déclenché par le projet de map externe.
    Q_INVOKABLE void sendMapSync(const QJsonObject &mapJson);

    /// Envoie les inputs minijeux en UDP brut (lossy, 60 Hz).
    Q_INVOKABLE void sendMinigameInput(qreal x, qreal y, qreal vx, qreal vy);

    /// Hôte uniquement : broadcast un snapshot de correction (reliable ~1 Hz).
    Q_INVOKABLE void broadcastMinigameSnapshot(const QJsonObject &snapshot);

signals:
    /// Événement de jeu reçu (hors MapSync et minijeux).
    void boardEventReceived(int type, const QString &senderId, const QJsonObject &payload);

    /// Synchronisation JSON de map reçue.
    void mapSyncReceived(const QString &senderId, const QJsonObject &mapJson);

    /// Input minijeu reçu en UDP brut.
    void minigameInputReceived(const QString &senderId, qreal x, qreal y, qreal vx, qreal vy);

    /// Snapshot de correction minijeu reçu (reliable).
    void minigameSnapshotReceived(const QString &senderId, const QJsonObject &snapshot);

    void activeChanged();
    void isHostChanged();
    void localPlayerIdChanged();
    void hostPlayerIdChanged();

private slots:
    void onReliableReceived(const QString &senderId, const QByteArray &data);
    void onUdpReceived(const QString &senderId, const QString &message);

private:
    explicit GameSession(QObject *parent = nullptr);
    static GameSession *m_pThis;

    void connectToCatway();
    void disconnectFromCatway();

    /// Hôte : relay un paquet fiable à tous les joueurs P2P connectés sauf senderId.
    void relayReliableToOthers(const QString &senderId, const QByteArray &packet);
    /// Hôte : relay un message UDP brut à tous les joueurs P2P connectés sauf senderId.
    void relayRawToOthers(const QString &senderId, const QString &message);

    bool    m_active          = false;
    bool    m_isHost          = false;
    QString m_localPlayerId;
    QString m_hostPlayerId;

    QMetaObject::Connection m_reliableConn;
    QMetaObject::Connection m_udpConn;
};

#endif // GAME_SESSION_H
