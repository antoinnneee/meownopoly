/****************************************************************************
** Meta object code from reading C++ file 'player_network.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/communication/player_network.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'player_network.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN13PlayerNetworkE_t {};
} // unnamed namespace

template <> constexpr inline auto PlayerNetwork::qt_create_metaobjectdata<qt_meta_tag_ZN13PlayerNetworkE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "PlayerNetwork",
        "playerIdChanged",
        "",
        "nicknameChanged",
        "socketInfoChanged",
        "ipChanged",
        "portChanged",
        "p2pConnectedChanged",
        "stats",
        "QVariantMap",
        "playerId",
        "nickname",
        "socketInfo",
        "UdpSocketInfo*",
        "ip",
        "port",
        "p2pConnected"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'playerIdChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'nicknameChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'socketInfoChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'ipChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'portChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'p2pConnectedChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'stats'
        QtMocHelpers::MethodData<QVariantMap() const>(8, 2, QMC::AccessPublic, 0x80000000 | 9),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'playerId'
        QtMocHelpers::PropertyData<QString>(10, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 0),
        // property 'nickname'
        QtMocHelpers::PropertyData<QString>(11, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'socketInfo'
        QtMocHelpers::PropertyData<UdpSocketInfo*>(12, 0x80000000 | 13, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet, 2),
        // property 'ip'
        QtMocHelpers::PropertyData<QString>(14, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'port'
        QtMocHelpers::PropertyData<quint16>(15, QMetaType::UShort, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 4),
        // property 'p2pConnected'
        QtMocHelpers::PropertyData<bool>(16, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 5),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<PlayerNetwork, qt_meta_tag_ZN13PlayerNetworkE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject PlayerNetwork::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13PlayerNetworkE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13PlayerNetworkE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN13PlayerNetworkE_t>.metaTypes,
    nullptr
} };

void PlayerNetwork::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<PlayerNetwork *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->playerIdChanged(); break;
        case 1: _t->nicknameChanged(); break;
        case 2: _t->socketInfoChanged(); break;
        case 3: _t->ipChanged(); break;
        case 4: _t->portChanged(); break;
        case 5: _t->p2pConnectedChanged(); break;
        case 6: { QVariantMap _r = _t->stats();
            if (_a[0]) *reinterpret_cast<QVariantMap*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (PlayerNetwork::*)()>(_a, &PlayerNetwork::playerIdChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlayerNetwork::*)()>(_a, &PlayerNetwork::nicknameChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlayerNetwork::*)()>(_a, &PlayerNetwork::socketInfoChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlayerNetwork::*)()>(_a, &PlayerNetwork::ipChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlayerNetwork::*)()>(_a, &PlayerNetwork::portChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (PlayerNetwork::*)()>(_a, &PlayerNetwork::p2pConnectedChanged, 5))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 2:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< UdpSocketInfo* >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->playerId(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->nickname(); break;
        case 2: *reinterpret_cast<UdpSocketInfo**>(_v) = _t->socketInfo(); break;
        case 3: *reinterpret_cast<QString*>(_v) = _t->ip(); break;
        case 4: *reinterpret_cast<quint16*>(_v) = _t->port(); break;
        case 5: *reinterpret_cast<bool*>(_v) = _t->isP2pConnected(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setPlayerId(*reinterpret_cast<QString*>(_v)); break;
        case 1: _t->setNickname(*reinterpret_cast<QString*>(_v)); break;
        case 2: _t->setSocketInfo(*reinterpret_cast<UdpSocketInfo**>(_v)); break;
        case 3: _t->setIp(*reinterpret_cast<QString*>(_v)); break;
        case 4: _t->setPort(*reinterpret_cast<quint16*>(_v)); break;
        case 5: _t->setP2pConnected(*reinterpret_cast<bool*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *PlayerNetwork::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *PlayerNetwork::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13PlayerNetworkE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int PlayerNetwork::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 7)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 7;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 7)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 7;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void PlayerNetwork::playerIdChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void PlayerNetwork::nicknameChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void PlayerNetwork::socketInfoChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void PlayerNetwork::ipChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void PlayerNetwork::portChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void PlayerNetwork::p2pConnectedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}
QT_WARNING_POP
