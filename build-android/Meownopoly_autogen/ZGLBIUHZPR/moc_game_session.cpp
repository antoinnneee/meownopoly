/****************************************************************************
** Meta object code from reading C++ file 'game_session.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/network/game_session.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'game_session.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN11GameSessionE_t {};
} // unnamed namespace

template <> constexpr inline auto GameSession::qt_create_metaobjectdata<qt_meta_tag_ZN11GameSessionE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "GameSession",
        "boardEventReceived",
        "",
        "type",
        "senderId",
        "QJsonObject",
        "payload",
        "mapSyncReceived",
        "mapJson",
        "minigameInputReceived",
        "x",
        "y",
        "vx",
        "vy",
        "minigameSnapshotReceived",
        "snapshot",
        "activeChanged",
        "isHostChanged",
        "localPlayerIdChanged",
        "hostPlayerIdChanged",
        "onReliableReceived",
        "data",
        "onUdpReceived",
        "message",
        "startAsHost",
        "localPlayerId",
        "startAsClient",
        "hostPlayerId",
        "stop",
        "sendEvent",
        "broadcastEvent",
        "sendMapSync",
        "sendMinigameInput",
        "broadcastMinigameSnapshot",
        "active",
        "isHost"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'boardEventReceived'
        QtMocHelpers::SignalData<void(int, const QString &, const QJsonObject &)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 3 }, { QMetaType::QString, 4 }, { 0x80000000 | 5, 6 },
        }}),
        // Signal 'mapSyncReceived'
        QtMocHelpers::SignalData<void(const QString &, const QJsonObject &)>(7, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 4 }, { 0x80000000 | 5, 8 },
        }}),
        // Signal 'minigameInputReceived'
        QtMocHelpers::SignalData<void(const QString &, qreal, qreal, qreal, qreal)>(9, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 4 }, { QMetaType::QReal, 10 }, { QMetaType::QReal, 11 }, { QMetaType::QReal, 12 },
            { QMetaType::QReal, 13 },
        }}),
        // Signal 'minigameSnapshotReceived'
        QtMocHelpers::SignalData<void(const QString &, const QJsonObject &)>(14, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 4 }, { 0x80000000 | 5, 15 },
        }}),
        // Signal 'activeChanged'
        QtMocHelpers::SignalData<void()>(16, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isHostChanged'
        QtMocHelpers::SignalData<void()>(17, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'localPlayerIdChanged'
        QtMocHelpers::SignalData<void()>(18, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'hostPlayerIdChanged'
        QtMocHelpers::SignalData<void()>(19, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'onReliableReceived'
        QtMocHelpers::SlotData<void(const QString &, const QByteArray &)>(20, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 4 }, { QMetaType::QByteArray, 21 },
        }}),
        // Slot 'onUdpReceived'
        QtMocHelpers::SlotData<void(const QString &, const QString &)>(22, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 4 }, { QMetaType::QString, 23 },
        }}),
        // Method 'startAsHost'
        QtMocHelpers::MethodData<void(const QString &)>(24, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 25 },
        }}),
        // Method 'startAsClient'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(26, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 25 }, { QMetaType::QString, 27 },
        }}),
        // Method 'stop'
        QtMocHelpers::MethodData<void()>(28, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'sendEvent'
        QtMocHelpers::MethodData<void(int, const QJsonObject &)>(29, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 3 }, { 0x80000000 | 5, 6 },
        }}),
        // Method 'sendEvent'
        QtMocHelpers::MethodData<void(int)>(29, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::Int, 3 },
        }}),
        // Method 'broadcastEvent'
        QtMocHelpers::MethodData<void(int, const QJsonObject &)>(30, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 3 }, { 0x80000000 | 5, 6 },
        }}),
        // Method 'broadcastEvent'
        QtMocHelpers::MethodData<void(int)>(30, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::Int, 3 },
        }}),
        // Method 'sendMapSync'
        QtMocHelpers::MethodData<void(const QJsonObject &)>(31, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 5, 8 },
        }}),
        // Method 'sendMinigameInput'
        QtMocHelpers::MethodData<void(qreal, qreal, qreal, qreal)>(32, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QReal, 10 }, { QMetaType::QReal, 11 }, { QMetaType::QReal, 12 }, { QMetaType::QReal, 13 },
        }}),
        // Method 'broadcastMinigameSnapshot'
        QtMocHelpers::MethodData<void(const QJsonObject &)>(33, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 5, 15 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'active'
        QtMocHelpers::PropertyData<bool>(34, QMetaType::Bool, QMC::DefaultPropertyFlags, 4),
        // property 'isHost'
        QtMocHelpers::PropertyData<bool>(35, QMetaType::Bool, QMC::DefaultPropertyFlags, 5),
        // property 'localPlayerId'
        QtMocHelpers::PropertyData<QString>(25, QMetaType::QString, QMC::DefaultPropertyFlags, 6),
        // property 'hostPlayerId'
        QtMocHelpers::PropertyData<QString>(27, QMetaType::QString, QMC::DefaultPropertyFlags, 7),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<GameSession, qt_meta_tag_ZN11GameSessionE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject GameSession::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11GameSessionE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11GameSessionE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN11GameSessionE_t>.metaTypes,
    nullptr
} };

void GameSession::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<GameSession *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->boardEventReceived((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[3]))); break;
        case 1: _t->mapSyncReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 2: _t->minigameInputReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[5]))); break;
        case 3: _t->minigameSnapshotReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 4: _t->activeChanged(); break;
        case 5: _t->isHostChanged(); break;
        case 6: _t->localPlayerIdChanged(); break;
        case 7: _t->hostPlayerIdChanged(); break;
        case 8: _t->onReliableReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[2]))); break;
        case 9: _t->onUdpReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 10: _t->startAsHost((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 11: _t->startAsClient((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 12: _t->stop(); break;
        case 13: _t->sendEvent((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 14: _t->sendEvent((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 15: _t->broadcastEvent((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 16: _t->broadcastEvent((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 17: _t->sendMapSync((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 18: _t->sendMinigameInput((*reinterpret_cast<std::add_pointer_t<qreal>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[4]))); break;
        case 19: _t->broadcastMinigameSnapshot((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (GameSession::*)(int , const QString & , const QJsonObject & )>(_a, &GameSession::boardEventReceived, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (GameSession::*)(const QString & , const QJsonObject & )>(_a, &GameSession::mapSyncReceived, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (GameSession::*)(const QString & , qreal , qreal , qreal , qreal )>(_a, &GameSession::minigameInputReceived, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (GameSession::*)(const QString & , const QJsonObject & )>(_a, &GameSession::minigameSnapshotReceived, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (GameSession::*)()>(_a, &GameSession::activeChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (GameSession::*)()>(_a, &GameSession::isHostChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (GameSession::*)()>(_a, &GameSession::localPlayerIdChanged, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (GameSession::*)()>(_a, &GameSession::hostPlayerIdChanged, 7))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->active(); break;
        case 1: *reinterpret_cast<bool*>(_v) = _t->isHost(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->localPlayerId(); break;
        case 3: *reinterpret_cast<QString*>(_v) = _t->hostPlayerId(); break;
        default: break;
        }
    }
}

const QMetaObject *GameSession::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *GameSession::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11GameSessionE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int GameSession::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 20)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 20;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 20)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 20;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 4;
    }
    return _id;
}

// SIGNAL 0
void GameSession::boardEventReceived(int _t1, const QString & _t2, const QJsonObject & _t3)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1, _t2, _t3);
}

// SIGNAL 1
void GameSession::mapSyncReceived(const QString & _t1, const QJsonObject & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1, _t2);
}

// SIGNAL 2
void GameSession::minigameInputReceived(const QString & _t1, qreal _t2, qreal _t3, qreal _t4, qreal _t5)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 2, nullptr, _t1, _t2, _t3, _t4, _t5);
}

// SIGNAL 3
void GameSession::minigameSnapshotReceived(const QString & _t1, const QJsonObject & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 3, nullptr, _t1, _t2);
}

// SIGNAL 4
void GameSession::activeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void GameSession::isHostChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void GameSession::localPlayerIdChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void GameSession::hostPlayerIdChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}
QT_WARNING_POP
