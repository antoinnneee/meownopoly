#include "minigame_sync.h"
#include "game_session.h"

#include <QQmlEngine>

MinigameSync::MinigameSync(QObject *parent) : QObject(parent)
{
    connect(&m_inputTimer,    &QTimer::timeout, this, &MinigameSync::onInputTick);
    connect(&m_snapshotTimer, &QTimer::timeout, this, &MinigameSync::onSnapshotTick);

    GameSession *gs = GameSession::instance();
    connect(gs, &GameSession::minigameInputReceived,
            this, &MinigameSync::onRemotePosition);
    connect(&m_renderTimer, &QTimer::timeout,
            this, &MinigameSync::onRenderTick);
    m_renderTimer.setInterval(33); // ~30 Hz
    connect(gs, &GameSession::minigameSnapshotReceived,
            this, &MinigameSync::snapshotReceived);
}

void MinigameSync::registerQml()
{
    qmlRegisterType<MinigameSync>("GameSession", 1, 0, "MinigameSync");
}

// ── Contrôle ──────────────────────────────────────────────────────────────────

void MinigameSync::start()
{
    applyRates();
    m_inputTimer.start();
    m_renderTimer.start();
    emit runningChanged();
}

void MinigameSync::stop()
{
    m_inputTimer.stop();
    m_snapshotTimer.stop();
    m_renderTimer.stop();
    emit runningChanged();
}

void MinigameSync::setInputRate(int hz)
{
    if (m_inputRateHz == hz) return;
    m_inputRateHz = hz;
    if (m_inputTimer.isActive()) applyRates();
    emit inputRateChanged();
}

void MinigameSync::setSnapshotRate(int hz)
{
    if (m_snapshotRateHz == hz) return;
    m_snapshotRateHz = hz;
    if (m_snapshotTimer.isActive()) applyRates();
    emit snapshotRateChanged();
}

void MinigameSync::applyRates()
{
    m_inputTimer.setInterval(m_inputRateHz > 0 ? 1000 / m_inputRateHz : 16);

    GameSession *gs = GameSession::instance();
    if (gs->isHost() && m_snapshotRateHz > 0) {
        m_snapshotTimer.setInterval(1000 / m_snapshotRateHz);
        m_snapshotTimer.start();
    } else {
        m_snapshotTimer.stop();
    }
}

// ── Mise à jour de la position locale ─────────────────────────────────────────

void MinigameSync::setLocalPosition(qreal x, qreal y, qreal vx, qreal vy)
{
    m_localX  = x;
    m_localY  = y;
    m_localVx = vx;
    m_localVy = vy;
}

void MinigameSync::setSnapshot(const QJsonObject &snapshot)
{
    m_snapshot = snapshot;
}

// ── Ticks ─────────────────────────────────────────────────────────────────────

void MinigameSync::onInputTick()
{
    GameSession::instance()->sendMinigameInput(m_localX, m_localY, m_localVx, m_localVy);
}

void MinigameSync::onSnapshotTick()
{
    if (!m_snapshot.isEmpty())
        GameSession::instance()->broadcastMinigameSnapshot(m_snapshot);
}

// ── Rendu différé des positions distantes (30 Hz) ─────────────────────────────

void MinigameSync::onRemotePosition(const QString &playerId, qreal x, qreal y, qreal vx, qreal vy)
{
    m_remotePositions[playerId] = {x, y, vx, vy};
}

void MinigameSync::onRenderTick()
{
    for (auto it = m_remotePositions.constBegin(); it != m_remotePositions.constEnd(); ++it)
        emit playerPositionUpdated(it.key(), it.value().x, it.value().y, it.value().vx, it.value().vy);
}
