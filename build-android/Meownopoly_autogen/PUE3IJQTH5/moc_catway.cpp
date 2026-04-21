/****************************************************************************
** Meta object code from reading C++ file 'catway.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/communication/catway.h"
#include <QtNetwork/QSslPreSharedKeyAuthenticator>
#include <QtNetwork/QSslError>
#include <QtCore/qmetatype.h>
#include <QtCore/QList>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'catway.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.10.3. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN12CatwayWorkerE_t {};
} // unnamed namespace

template <> constexpr inline auto CatwayWorker::qt_create_metaobjectdata<qt_meta_tag_ZN12CatwayWorkerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "CatwayWorker",
        "datagramReceived",
        "",
        "QUdpSocket*",
        "socket",
        "datagram",
        "QHostAddress",
        "sender",
        "port",
        "playerTimedOut",
        "playerId",
        "initReliable",
        "startReliableTimer",
        "tearDown",
        "startStunServer",
        "stopStunServer",
        "sendStunRequest",
        "setStunServerInfo",
        "host",
        "takeStunSocket",
        "UdpSocketInfo*",
        "sendDatagram",
        "data",
        "address",
        "sendReliablePacket",
        "onSocketReadyRead",
        "broadcastReliable",
        "setPlayerSnapshots",
        "QList<PlayerSnapshot>",
        "snapshots",
        "initLastReceived",
        "onReliableUpdate",
        "onHeartbeat"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'datagramReceived'
        QtMocHelpers::SignalData<void(QUdpSocket *, QByteArray, QHostAddress, quint16)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 }, { QMetaType::QByteArray, 5 }, { 0x80000000 | 6, 7 }, { QMetaType::UShort, 8 },
        }}),
        // Signal 'playerTimedOut'
        QtMocHelpers::SignalData<void(QString)>(9, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 10 },
        }}),
        // Slot 'initReliable'
        QtMocHelpers::SlotData<void()>(11, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'startReliableTimer'
        QtMocHelpers::SlotData<void()>(12, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'tearDown'
        QtMocHelpers::SlotData<void()>(13, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'startStunServer'
        QtMocHelpers::SlotData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'stopStunServer'
        QtMocHelpers::SlotData<void()>(15, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'sendStunRequest'
        QtMocHelpers::SlotData<void()>(16, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'setStunServerInfo'
        QtMocHelpers::SlotData<void(const QString &, quint16)>(17, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 18 }, { QMetaType::UShort, 8 },
        }}),
        // Slot 'takeStunSocket'
        QtMocHelpers::SlotData<UdpSocketInfo *()>(19, 2, QMC::AccessPublic, 0x80000000 | 20),
        // Slot 'sendDatagram'
        QtMocHelpers::SlotData<void(QUdpSocket *, const QByteArray &, const QHostAddress &, quint16)>(21, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 }, { QMetaType::QByteArray, 22 }, { 0x80000000 | 6, 23 }, { QMetaType::UShort, 8 },
        }}),
        // Slot 'sendReliablePacket'
        QtMocHelpers::SlotData<void(const QString &, const QByteArray &)>(24, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 10 }, { QMetaType::QByteArray, 22 },
        }}),
        // Slot 'onSocketReadyRead'
        QtMocHelpers::SlotData<void()>(25, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'broadcastReliable'
        QtMocHelpers::SlotData<void(const QByteArray &)>(26, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QByteArray, 22 },
        }}),
        // Slot 'setPlayerSnapshots'
        QtMocHelpers::SlotData<void(QList<PlayerSnapshot>)>(27, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 28, 29 },
        }}),
        // Slot 'initLastReceived'
        QtMocHelpers::SlotData<void(const QString &)>(30, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 10 },
        }}),
        // Slot 'onReliableUpdate'
        QtMocHelpers::SlotData<void()>(31, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onHeartbeat'
        QtMocHelpers::SlotData<void()>(32, 2, QMC::AccessPrivate, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<CatwayWorker, qt_meta_tag_ZN12CatwayWorkerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject CatwayWorker::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CatwayWorkerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CatwayWorkerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN12CatwayWorkerE_t>.metaTypes,
    nullptr
} };

void CatwayWorker::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<CatwayWorker *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->datagramReceived((*reinterpret_cast<std::add_pointer_t<QUdpSocket*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QHostAddress>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[4]))); break;
        case 1: _t->playerTimedOut((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 2: _t->initReliable(); break;
        case 3: _t->startReliableTimer(); break;
        case 4: _t->tearDown(); break;
        case 5: _t->startStunServer(); break;
        case 6: _t->stopStunServer(); break;
        case 7: _t->sendStunRequest(); break;
        case 8: _t->setStunServerInfo((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[2]))); break;
        case 9: { UdpSocketInfo* _r = _t->takeStunSocket();
            if (_a[0]) *reinterpret_cast<UdpSocketInfo**>(_a[0]) = std::move(_r); }  break;
        case 10: _t->sendDatagram((*reinterpret_cast<std::add_pointer_t<QUdpSocket*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QHostAddress>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[4]))); break;
        case 11: _t->sendReliablePacket((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[2]))); break;
        case 12: _t->onSocketReadyRead(); break;
        case 13: _t->broadcastReliable((*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[1]))); break;
        case 14: _t->setPlayerSnapshots((*reinterpret_cast<std::add_pointer_t<QList<PlayerSnapshot>>>(_a[1]))); break;
        case 15: _t->initLastReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 16: _t->onReliableUpdate(); break;
        case 17: _t->onHeartbeat(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 0:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< QUdpSocket* >(); break;
            }
            break;
        case 10:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< QUdpSocket* >(); break;
            }
            break;
        case 14:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< QList<PlayerSnapshot> >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (CatwayWorker::*)(QUdpSocket * , QByteArray , QHostAddress , quint16 )>(_a, &CatwayWorker::datagramReceived, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (CatwayWorker::*)(QString )>(_a, &CatwayWorker::playerTimedOut, 1))
            return;
    }
}

const QMetaObject *CatwayWorker::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *CatwayWorker::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CatwayWorkerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int CatwayWorker::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 18)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 18;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 18)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 18;
    }
    return _id;
}

// SIGNAL 0
void CatwayWorker::datagramReceived(QUdpSocket * _t1, QByteArray _t2, QHostAddress _t3, quint16 _t4)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1, _t2, _t3, _t4);
}

// SIGNAL 1
void CatwayWorker::playerTimedOut(QString _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1);
}
namespace {
struct qt_meta_tag_ZN6CatwayE_t {};
} // unnamed namespace

template <> constexpr inline auto Catway::qt_create_metaobjectdata<qt_meta_tag_ZN6CatwayE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "Catway",
        "log",
        "",
        "message",
        "stunServerStarted",
        "port",
        "externalAddressReceived",
        "ip",
        "udpMessageReceived",
        "senderId",
        "localPortsChanged",
        "playersChanged",
        "reliableMessageReceived",
        "data",
        "chatClientChanged",
        "playerTimedOut",
        "playerId",
        "setupNewPort",
        "onAccountStunChanged",
        "onExternalAddressReceivedTakePort",
        "onChatCommandReceived",
        "commandType",
        "QJsonObject",
        "onPendingCommandReady",
        "onDatagramReceived",
        "QUdpSocket*",
        "socket",
        "datagram",
        "QHostAddress",
        "sender",
        "onStunRequestFailed",
        "onCurrentSocketInfoChanged",
        "UdpSocketInfo*",
        "info",
        "onPlayerNetworkPlayerIdChanged",
        "startStunServer",
        "stopStunServer",
        "sendStunRequest",
        "getSocket",
        "currentSocketInfo",
        "takeStunSocket",
        "setChatClient",
        "ChatClient*",
        "client",
        "addPlayer",
        "PlayerNetwork*",
        "player",
        "removePlayer",
        "playerAt",
        "index",
        "playersCount",
        "playerById",
        "localPortAt",
        "localPortCount",
        "lastLocalPort",
        "initiateHolePunch",
        "sendUdpMessageToPlayer",
        "sendReliableToPlayer",
        "broadcastReliable",
        "broadcastRaw",
        "localPorts",
        "QQmlListProperty<UdpSocketInfo>",
        "players",
        "QQmlListProperty<PlayerNetwork>",
        "chatClient"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'log'
        QtMocHelpers::SignalData<void(QString)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 3 },
        }}),
        // Signal 'stunServerStarted'
        QtMocHelpers::SignalData<void(quint16)>(4, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::UShort, 5 },
        }}),
        // Signal 'externalAddressReceived'
        QtMocHelpers::SignalData<void(QString, quint16)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::UShort, 5 },
        }}),
        // Signal 'udpMessageReceived'
        QtMocHelpers::SignalData<void(QString, QString)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 9 }, { QMetaType::QString, 3 },
        }}),
        // Signal 'localPortsChanged'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'playersChanged'
        QtMocHelpers::SignalData<void()>(11, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'reliableMessageReceived'
        QtMocHelpers::SignalData<void(QString, QByteArray)>(12, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 9 }, { QMetaType::QByteArray, 13 },
        }}),
        // Signal 'chatClientChanged'
        QtMocHelpers::SignalData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'playerTimedOut'
        QtMocHelpers::SignalData<void(QString)>(15, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 16 },
        }}),
        // Slot 'setupNewPort'
        QtMocHelpers::SlotData<void()>(17, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'onAccountStunChanged'
        QtMocHelpers::SlotData<void()>(18, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onExternalAddressReceivedTakePort'
        QtMocHelpers::SlotData<void(QString, quint16)>(19, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::UShort, 5 },
        }}),
        // Slot 'onChatCommandReceived'
        QtMocHelpers::SlotData<void(const QString &, const QString &, const QJsonObject &)>(20, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 9 }, { QMetaType::QString, 21 }, { 0x80000000 | 22, 13 },
        }}),
        // Slot 'onPendingCommandReady'
        QtMocHelpers::SlotData<void(QString, quint16)>(23, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::UShort, 5 },
        }}),
        // Slot 'onDatagramReceived'
        QtMocHelpers::SlotData<void(QUdpSocket *, QByteArray, QHostAddress, quint16)>(24, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { 0x80000000 | 25, 26 }, { QMetaType::QByteArray, 27 }, { 0x80000000 | 28, 29 }, { QMetaType::UShort, 5 },
        }}),
        // Slot 'onStunRequestFailed'
        QtMocHelpers::SlotData<void()>(30, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onCurrentSocketInfoChanged'
        QtMocHelpers::SlotData<void(UdpSocketInfo *)>(31, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { 0x80000000 | 32, 33 },
        }}),
        // Slot 'onPlayerNetworkPlayerIdChanged'
        QtMocHelpers::SlotData<void()>(34, 2, QMC::AccessPrivate, QMetaType::Void),
        // Method 'startStunServer'
        QtMocHelpers::MethodData<void()>(35, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'stopStunServer'
        QtMocHelpers::MethodData<void()>(36, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'sendStunRequest'
        QtMocHelpers::MethodData<void()>(37, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'getSocket'
        QtMocHelpers::MethodData<QObject *() const>(38, 2, QMC::AccessPublic, QMetaType::QObjectStar),
        // Method 'currentSocketInfo'
        QtMocHelpers::MethodData<QObject *() const>(39, 2, QMC::AccessPublic, QMetaType::QObjectStar),
        // Method 'takeStunSocket'
        QtMocHelpers::MethodData<UdpSocketInfo *()>(40, 2, QMC::AccessPublic, 0x80000000 | 32),
        // Method 'setChatClient'
        QtMocHelpers::MethodData<void(ChatClient *)>(41, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 42, 43 },
        }}),
        // Method 'addPlayer'
        QtMocHelpers::MethodData<void(PlayerNetwork *)>(44, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 45, 46 },
        }}),
        // Method 'removePlayer'
        QtMocHelpers::MethodData<void(PlayerNetwork *)>(47, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 45, 46 },
        }}),
        // Method 'playerAt'
        QtMocHelpers::MethodData<PlayerNetwork *(int) const>(48, 2, QMC::AccessPublic, 0x80000000 | 45, {{
            { QMetaType::Int, 49 },
        }}),
        // Method 'playersCount'
        QtMocHelpers::MethodData<int() const>(50, 2, QMC::AccessPublic, QMetaType::Int),
        // Method 'playerById'
        QtMocHelpers::MethodData<PlayerNetwork *(const QString &) const>(51, 2, QMC::AccessPublic, 0x80000000 | 45, {{
            { QMetaType::QString, 16 },
        }}),
        // Method 'localPortAt'
        QtMocHelpers::MethodData<QObject *(int) const>(52, 2, QMC::AccessPublic, QMetaType::QObjectStar, {{
            { QMetaType::Int, 49 },
        }}),
        // Method 'localPortCount'
        QtMocHelpers::MethodData<int() const>(53, 2, QMC::AccessPublic, QMetaType::Int),
        // Method 'lastLocalPort'
        QtMocHelpers::MethodData<QObject *() const>(54, 2, QMC::AccessPublic, QMetaType::QObjectStar),
        // Method 'initiateHolePunch'
        QtMocHelpers::MethodData<void(PlayerNetwork *)>(55, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 45, 46 },
        }}),
        // Method 'sendUdpMessageToPlayer'
        QtMocHelpers::MethodData<void(PlayerNetwork *, const QString &)>(56, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 45, 46 }, { QMetaType::QString, 3 },
        }}),
        // Method 'sendReliableToPlayer'
        QtMocHelpers::MethodData<void(PlayerNetwork *, const QByteArray &)>(57, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 45, 46 }, { QMetaType::QByteArray, 13 },
        }}),
        // Method 'broadcastReliable'
        QtMocHelpers::MethodData<void(const QByteArray &)>(58, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QByteArray, 13 },
        }}),
        // Method 'broadcastRaw'
        QtMocHelpers::MethodData<void(const QString &)>(59, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 3 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'localPorts'
        QtMocHelpers::PropertyData<QQmlListProperty<UdpSocketInfo>>(60, 0x80000000 | 61, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 4),
        // property 'players'
        QtMocHelpers::PropertyData<QQmlListProperty<PlayerNetwork>>(62, 0x80000000 | 63, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 5),
        // property 'chatClient'
        QtMocHelpers::PropertyData<ChatClient*>(64, 0x80000000 | 42, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet, 7),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<Catway, qt_meta_tag_ZN6CatwayE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject Catway::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN6CatwayE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN6CatwayE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN6CatwayE_t>.metaTypes,
    nullptr
} };

void Catway::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<Catway *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->log((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 1: _t->stunServerStarted((*reinterpret_cast<std::add_pointer_t<quint16>>(_a[1]))); break;
        case 2: _t->externalAddressReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[2]))); break;
        case 3: _t->udpMessageReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 4: _t->localPortsChanged(); break;
        case 5: _t->playersChanged(); break;
        case 6: _t->reliableMessageReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[2]))); break;
        case 7: _t->chatClientChanged(); break;
        case 8: _t->playerTimedOut((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 9: _t->setupNewPort(); break;
        case 10: _t->onAccountStunChanged(); break;
        case 11: _t->onExternalAddressReceivedTakePort((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[2]))); break;
        case 12: _t->onChatCommandReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[3]))); break;
        case 13: _t->onPendingCommandReady((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[2]))); break;
        case 14: _t->onDatagramReceived((*reinterpret_cast<std::add_pointer_t<QUdpSocket*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QHostAddress>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[4]))); break;
        case 15: _t->onStunRequestFailed(); break;
        case 16: _t->onCurrentSocketInfoChanged((*reinterpret_cast<std::add_pointer_t<UdpSocketInfo*>>(_a[1]))); break;
        case 17: _t->onPlayerNetworkPlayerIdChanged(); break;
        case 18: _t->startStunServer(); break;
        case 19: _t->stopStunServer(); break;
        case 20: _t->sendStunRequest(); break;
        case 21: { QObject* _r = _t->getSocket();
            if (_a[0]) *reinterpret_cast<QObject**>(_a[0]) = std::move(_r); }  break;
        case 22: { QObject* _r = _t->currentSocketInfo();
            if (_a[0]) *reinterpret_cast<QObject**>(_a[0]) = std::move(_r); }  break;
        case 23: { UdpSocketInfo* _r = _t->takeStunSocket();
            if (_a[0]) *reinterpret_cast<UdpSocketInfo**>(_a[0]) = std::move(_r); }  break;
        case 24: _t->setChatClient((*reinterpret_cast<std::add_pointer_t<ChatClient*>>(_a[1]))); break;
        case 25: _t->addPlayer((*reinterpret_cast<std::add_pointer_t<PlayerNetwork*>>(_a[1]))); break;
        case 26: _t->removePlayer((*reinterpret_cast<std::add_pointer_t<PlayerNetwork*>>(_a[1]))); break;
        case 27: { PlayerNetwork* _r = _t->playerAt((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast<PlayerNetwork**>(_a[0]) = std::move(_r); }  break;
        case 28: { int _r = _t->playersCount();
            if (_a[0]) *reinterpret_cast<int*>(_a[0]) = std::move(_r); }  break;
        case 29: { PlayerNetwork* _r = _t->playerById((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<PlayerNetwork**>(_a[0]) = std::move(_r); }  break;
        case 30: { QObject* _r = _t->localPortAt((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QObject**>(_a[0]) = std::move(_r); }  break;
        case 31: { int _r = _t->localPortCount();
            if (_a[0]) *reinterpret_cast<int*>(_a[0]) = std::move(_r); }  break;
        case 32: { QObject* _r = _t->lastLocalPort();
            if (_a[0]) *reinterpret_cast<QObject**>(_a[0]) = std::move(_r); }  break;
        case 33: _t->initiateHolePunch((*reinterpret_cast<std::add_pointer_t<PlayerNetwork*>>(_a[1]))); break;
        case 34: _t->sendUdpMessageToPlayer((*reinterpret_cast<std::add_pointer_t<PlayerNetwork*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 35: _t->sendReliableToPlayer((*reinterpret_cast<std::add_pointer_t<PlayerNetwork*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[2]))); break;
        case 36: _t->broadcastReliable((*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[1]))); break;
        case 37: _t->broadcastRaw((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 14:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< QUdpSocket* >(); break;
            }
            break;
        case 16:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< UdpSocketInfo* >(); break;
            }
            break;
        case 24:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ChatClient* >(); break;
            }
            break;
        case 25:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PlayerNetwork* >(); break;
            }
            break;
        case 26:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PlayerNetwork* >(); break;
            }
            break;
        case 33:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PlayerNetwork* >(); break;
            }
            break;
        case 34:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PlayerNetwork* >(); break;
            }
            break;
        case 35:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PlayerNetwork* >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (Catway::*)(QString )>(_a, &Catway::log, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (Catway::*)(quint16 )>(_a, &Catway::stunServerStarted, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (Catway::*)(QString , quint16 )>(_a, &Catway::externalAddressReceived, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (Catway::*)(QString , QString )>(_a, &Catway::udpMessageReceived, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (Catway::*)()>(_a, &Catway::localPortsChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (Catway::*)()>(_a, &Catway::playersChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (Catway::*)(QString , QByteArray )>(_a, &Catway::reliableMessageReceived, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (Catway::*)()>(_a, &Catway::chatClientChanged, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (Catway::*)(QString )>(_a, &Catway::playerTimedOut, 8))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 2:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< ChatClient* >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QQmlListProperty<UdpSocketInfo>*>(_v) = _t->localPorts(); break;
        case 1: *reinterpret_cast<QQmlListProperty<PlayerNetwork>*>(_v) = _t->players(); break;
        case 2: *reinterpret_cast<ChatClient**>(_v) = _t->chatClient(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 2: _t->setChatClient(*reinterpret_cast<ChatClient**>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *Catway::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *Catway::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN6CatwayE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int Catway::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 38)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 38;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 38)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 38;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 3;
    }
    return _id;
}

// SIGNAL 0
void Catway::log(QString _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void Catway::stunServerStarted(quint16 _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1);
}

// SIGNAL 2
void Catway::externalAddressReceived(QString _t1, quint16 _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 2, nullptr, _t1, _t2);
}

// SIGNAL 3
void Catway::udpMessageReceived(QString _t1, QString _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 3, nullptr, _t1, _t2);
}

// SIGNAL 4
void Catway::localPortsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void Catway::playersChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void Catway::reliableMessageReceived(QString _t1, QByteArray _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 6, nullptr, _t1, _t2);
}

// SIGNAL 7
void Catway::chatClientChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void Catway::playerTimedOut(QString _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 8, nullptr, _t1);
}
QT_WARNING_POP
