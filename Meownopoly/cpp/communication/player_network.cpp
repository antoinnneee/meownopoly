#include "player_network.h"
#include <QQmlEngine>

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
