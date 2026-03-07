#ifndef MINIGAME_SYNC_H
#define MINIGAME_SYNC_H

#include <QObject>
#include <QTimer>
#include <QQmlEngine>
#include <QJsonObject>

/// Gestionnaire de synchronisation réseau pour les minijeux (PattounX).
///
/// Flux :
///   - Tick 60 Hz : envoi des inputs locaux via GameSession::sendMinigameInput
///   - Tick ~1 Hz (hôte seulement) : envoi d'un snapshot correctif complet (reliable)
///   - Réception : émet playerPositionUpdated pour que PattounX applique les positions
///
/// Usage QML :
///   MinigameSync { id: sync }
///   Component.onCompleted: sync.start()
///   onPlayerPositionUpdated: pattounx.applyPosition(senderId, x, y, vx, vy)
class MinigameSync : public QObject
{
    Q_OBJECT

    /// Fréquence d'envoi des inputs en Hz (défaut 60).
    Q_PROPERTY(int inputRate READ inputRate WRITE setInputRate NOTIFY inputRateChanged)

    /// Fréquence d'envoi des snapshots de correction en Hz (défaut 1, hôte seulement).
    Q_PROPERTY(int snapshotRate READ snapshotRate WRITE setSnapshotRate NOTIFY snapshotRateChanged)

    /// Vrai si le sync est en cours.
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
    static void registerQml();

    explicit MinigameSync(QObject *parent = nullptr);

    int  inputRate() const    { return m_inputRateHz; }
    void setInputRate(int hz);

    int  snapshotRate() const { return m_snapshotRateHz; }
    void setSnapshotRate(int hz);

    bool running() const      { return m_inputTimer.isActive(); }

    /// Démarre la synchronisation.
    Q_INVOKABLE void start();

    /// Arrête la synchronisation.
    Q_INVOKABLE void stop();

    /// Met à jour la position locale à broadcaster au prochain tick.
    Q_INVOKABLE void setLocalPosition(qreal x, qreal y, qreal vx, qreal vy);

    /// Hôte : fournit un snapshot complet à broadcaster (reliable ~1 Hz).
    Q_INVOKABLE void setSnapshot(const QJsonObject &snapshot);

signals:
    /// Position reçue d'un autre joueur (appliquer à PattounX).
    void playerPositionUpdated(const QString &playerId, qreal x, qreal y, qreal vx, qreal vy);

    /// Snapshot autoritaire reçu (appliquer correction PattounX).
    void snapshotReceived(const QString &senderId, const QJsonObject &snapshot);

    void inputRateChanged();
    void snapshotRateChanged();
    void runningChanged();

private slots:
    void onInputTick();
    void onSnapshotTick();

private:
    void applyRates();

    QTimer m_inputTimer;
    QTimer m_snapshotTimer;

    int m_inputRateHz    = 60;
    int m_snapshotRateHz = 1;

    qreal m_localX  = 0;
    qreal m_localY  = 0;
    qreal m_localVx = 0;
    qreal m_localVy = 0;

    QJsonObject m_snapshot;
};

#endif // MINIGAME_SYNC_H
