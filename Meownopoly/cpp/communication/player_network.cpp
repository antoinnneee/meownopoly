#include "player_network.h"
#include <QQmlEngine>
#include <QDebug>

PlayerNetwork::PlayerNetwork(QObject *parent)
    : QObject(parent)
{
}

PlayerNetwork::~PlayerNetwork()
{
    destroyReliable();
}

void PlayerNetwork::initReliable(
    void *context,
    void (*transmitFn)(void*, uint64_t, uint16_t, uint8_t*, int),
    int  (*processFn)(void*, uint64_t, uint16_t, uint8_t*, int)
)
{
    destroyReliable();

    struct reliable_config_t config;
    reliable_default_config(&config);

    // Nom lisible dans les logs reliable (tronqué à 255 chars)
    QByteArray name = ("player:" + m_playerId).toUtf8();
    reliable_copy_string(config.name, name.constData(), sizeof(config.name));

    config.context                 = context;
    config.transmit_packet_function = transmitFn;
    config.process_packet_function  = processFn;

    // Paramètres adaptés au jeu (paquets < 1200 bytes la plupart du temps)
    config.max_packet_size = 32 * 1024;
    config.fragment_above  = 1200;
    config.max_fragments   = 32;
    config.fragment_size   = 1024;
    config.sent_packets_buffer_size     = 128;
    config.received_packets_buffer_size = 128;

    m_endpoint = reliable_endpoint_create(&config, 0.0);
}

void PlayerNetwork::destroyReliable()
{
    if (m_endpoint) {
        reliable_endpoint_destroy(m_endpoint);
        m_endpoint = nullptr;
    }
}

void PlayerNetwork::registerQml()
{
    qmlRegisterType<PlayerNetwork>("Catway", 1, 0, "PlayerNetwork");
}

QVariantMap PlayerNetwork::stats() const
{
    QVariantMap m;
    if (!m_endpoint) return m;

    const float rtt    = reliable_endpoint_rtt(m_endpoint);
    const float rttMin = reliable_endpoint_rtt_min(m_endpoint);
    const float rttMax = reliable_endpoint_rtt_max(m_endpoint);
    const float rttAvg = reliable_endpoint_rtt_avg(m_endpoint);
    const float loss   = reliable_endpoint_packet_loss(m_endpoint);

    float sentKbps = 0, recvKbps = 0, ackedKbps = 0;
    reliable_endpoint_bandwidth(m_endpoint, &sentKbps, &recvKbps, &ackedKbps);

    m.insert("rtt",        rtt);
    m.insert("rttMin",     rttMin);
    m.insert("rttMax",     rttMax);
    m.insert("rttAvg",     rttAvg);
    m.insert("packetLoss", loss);

    m.insert("sentBwKbps",  sentKbps);
    m.insert("recvBwKbps",  recvKbps);
    m.insert("ackedBwKbps", ackedKbps);

    const uint64_t *c = reliable_endpoint_counters(m_endpoint);
    if (c) {
        m.insert("packetsSent",       quint64(c[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_SENT]));
        m.insert("packetsReceived",   quint64(c[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_RECEIVED]));
        m.insert("packetsAcked",      quint64(c[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_ACKED]));
        m.insert("packetsStale",      quint64(c[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_STALE]));
        m.insert("packetsInvalid",    quint64(c[RELIABLE_ENDPOINT_COUNTER_NUM_PACKETS_INVALID]));
        m.insert("fragmentsSent",     quint64(c[RELIABLE_ENDPOINT_COUNTER_NUM_FRAGMENTS_SENT]));
        m.insert("fragmentsReceived", quint64(c[RELIABLE_ENDPOINT_COUNTER_NUM_FRAGMENTS_RECEIVED]));
        m.insert("fragmentsInvalid",  quint64(c[RELIABLE_ENDPOINT_COUNTER_NUM_FRAGMENTS_INVALID]));
    }
    return m;
}

void PlayerNetwork::setPlayerId(const QString &id)
{
    if (m_playerId != id) {
        m_playerId = id;
        emit playerIdChanged();
    }
}

void PlayerNetwork::setNickname(const QString &name)
{
    if (m_nickname != name) {
        m_nickname = name;
        emit nicknameChanged();
    }
}

void PlayerNetwork::setSocketInfo(UdpSocketInfo *info)
{
    if (m_socketInfo != info) {
        m_socketInfo = info;
        if (info) {
            if (m_ip != info->publicAddress()) {
                m_ip = info->publicAddress();
                emit ipChanged();
            }
            if (m_port != info->publicPort()) {
                m_port = info->publicPort();
                emit portChanged();
            }
        } else {
            if (!m_ip.isEmpty()) { m_ip.clear(); emit ipChanged(); }
            if (m_port != 0) { m_port = 0; emit portChanged(); }
        }
        emit socketInfoChanged();
    }
}

void PlayerNetwork::setIp(const QString &ip)
{
    if (m_ip != ip) {
        m_ip = ip;
        emit ipChanged();
    }
}

void PlayerNetwork::setPort(quint16 port)
{
    if (m_port != port) {
        m_port = port;
        emit portChanged();
    }
}

void PlayerNetwork::setP2pConnected(bool connected)
{
    if (m_p2pConnected != connected) {
        m_p2pConnected = connected;
        emit p2pConnectedChanged();
    }
}
