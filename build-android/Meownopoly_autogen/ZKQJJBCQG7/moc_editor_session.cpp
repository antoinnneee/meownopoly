/****************************************************************************
** Meta object code from reading C++ file 'editor_session.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/editor/network/editor_session.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'editor_session.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN13EditorSessionE_t {};
} // unnamed namespace

template <> constexpr inline auto EditorSession::qt_create_metaobjectdata<qt_meta_tag_ZN13EditorSessionE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "EditorSession",
        "opReceived",
        "",
        "senderId",
        "QJsonObject",
        "op",
        "opRejected",
        "reject",
        "editorEventReceived",
        "type",
        "payload",
        "selectionReceived",
        "cursorReceived",
        "x",
        "y",
        "hostLost",
        "electedHostId",
        "promotedToHost",
        "knownRosterChanged",
        "peerLeft",
        "playerId",
        "opRateLimited",
        "dropped",
        "activeChanged",
        "isHostChanged",
        "localPlayerIdChanged",
        "hostPlayerIdChanged",
        "sessionIdChanged",
        "remoteSelectionsChanged",
        "onReliableReceived",
        "data",
        "onUdpReceived",
        "message",
        "onPlayerTimedOut",
        "electNewHost",
        "promoteToHost",
        "announceHostLeaving",
        "startAsHost",
        "localPlayerId",
        "sessionId",
        "startAsClient",
        "hostPlayerId",
        "stop",
        "sendOp",
        "broadcastOp",
        "sendEvent",
        "broadcastEvent",
        "sendEventTo",
        "sendCursor",
        "active",
        "isHost",
        "remoteSelections",
        "QVariantMap",
        "knownRoster"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'opReceived'
        QtMocHelpers::SignalData<void(const QString &, const QJsonObject &)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 3 }, { 0x80000000 | 4, 5 },
        }}),
        // Signal 'opRejected'
        QtMocHelpers::SignalData<void(const QJsonObject &)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 4, 7 },
        }}),
        // Signal 'editorEventReceived'
        QtMocHelpers::SignalData<void(int, const QString &, const QJsonObject &)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 9 }, { QMetaType::QString, 3 }, { 0x80000000 | 4, 10 },
        }}),
        // Signal 'selectionReceived'
        QtMocHelpers::SignalData<void(const QString &, const QJsonObject &)>(11, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 3 }, { 0x80000000 | 4, 10 },
        }}),
        // Signal 'cursorReceived'
        QtMocHelpers::SignalData<void(const QString &, qreal, qreal)>(12, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 3 }, { QMetaType::QReal, 13 }, { QMetaType::QReal, 14 },
        }}),
        // Signal 'hostLost'
        QtMocHelpers::SignalData<void(const QString &)>(15, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 16 },
        }}),
        // Signal 'promotedToHost'
        QtMocHelpers::SignalData<void()>(17, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'knownRosterChanged'
        QtMocHelpers::SignalData<void()>(18, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'peerLeft'
        QtMocHelpers::SignalData<void(const QString &)>(19, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 20 },
        }}),
        // Signal 'opRateLimited'
        QtMocHelpers::SignalData<void(const QString &, int)>(21, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 3 }, { QMetaType::Int, 22 },
        }}),
        // Signal 'activeChanged'
        QtMocHelpers::SignalData<void()>(23, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isHostChanged'
        QtMocHelpers::SignalData<void()>(24, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'localPlayerIdChanged'
        QtMocHelpers::SignalData<void()>(25, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'hostPlayerIdChanged'
        QtMocHelpers::SignalData<void()>(26, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'sessionIdChanged'
        QtMocHelpers::SignalData<void()>(27, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'remoteSelectionsChanged'
        QtMocHelpers::SignalData<void()>(28, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'onReliableReceived'
        QtMocHelpers::SlotData<void(const QString &, const QByteArray &)>(29, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 3 }, { QMetaType::QByteArray, 30 },
        }}),
        // Slot 'onUdpReceived'
        QtMocHelpers::SlotData<void(const QString &, const QString &)>(31, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 3 }, { QMetaType::QString, 32 },
        }}),
        // Slot 'onPlayerTimedOut'
        QtMocHelpers::SlotData<void(const QString &)>(33, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 20 },
        }}),
        // Method 'electNewHost'
        QtMocHelpers::MethodData<QString() const>(34, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'promoteToHost'
        QtMocHelpers::MethodData<bool()>(35, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'announceHostLeaving'
        QtMocHelpers::MethodData<void()>(36, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'startAsHost'
        QtMocHelpers::MethodData<bool(const QString &, const QString &)>(37, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 38 }, { QMetaType::QString, 39 },
        }}),
        // Method 'startAsHost'
        QtMocHelpers::MethodData<bool(const QString &)>(37, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Bool, {{
            { QMetaType::QString, 38 },
        }}),
        // Method 'startAsClient'
        QtMocHelpers::MethodData<bool(const QString &, const QString &, const QString &)>(40, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 38 }, { QMetaType::QString, 41 }, { QMetaType::QString, 39 },
        }}),
        // Method 'startAsClient'
        QtMocHelpers::MethodData<bool(const QString &, const QString &)>(40, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Bool, {{
            { QMetaType::QString, 38 }, { QMetaType::QString, 41 },
        }}),
        // Method 'stop'
        QtMocHelpers::MethodData<void()>(42, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'sendOp'
        QtMocHelpers::MethodData<void(const QJsonObject &)>(43, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 4, 5 },
        }}),
        // Method 'broadcastOp'
        QtMocHelpers::MethodData<void(const QJsonObject &)>(44, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 4, 5 },
        }}),
        // Method 'sendEvent'
        QtMocHelpers::MethodData<void(int, const QJsonObject &)>(45, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 9 }, { 0x80000000 | 4, 10 },
        }}),
        // Method 'sendEvent'
        QtMocHelpers::MethodData<void(int)>(45, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::Int, 9 },
        }}),
        // Method 'broadcastEvent'
        QtMocHelpers::MethodData<void(int, const QJsonObject &)>(46, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 9 }, { 0x80000000 | 4, 10 },
        }}),
        // Method 'broadcastEvent'
        QtMocHelpers::MethodData<void(int)>(46, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::Int, 9 },
        }}),
        // Method 'sendEventTo'
        QtMocHelpers::MethodData<void(const QString &, int, const QJsonObject &)>(47, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 20 }, { QMetaType::Int, 9 }, { 0x80000000 | 4, 10 },
        }}),
        // Method 'sendEventTo'
        QtMocHelpers::MethodData<void(const QString &, int)>(47, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 20 }, { QMetaType::Int, 9 },
        }}),
        // Method 'sendCursor'
        QtMocHelpers::MethodData<void(qreal, qreal)>(48, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QReal, 13 }, { QMetaType::QReal, 14 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'active'
        QtMocHelpers::PropertyData<bool>(49, QMetaType::Bool, QMC::DefaultPropertyFlags, 10),
        // property 'isHost'
        QtMocHelpers::PropertyData<bool>(50, QMetaType::Bool, QMC::DefaultPropertyFlags, 11),
        // property 'localPlayerId'
        QtMocHelpers::PropertyData<QString>(38, QMetaType::QString, QMC::DefaultPropertyFlags, 12),
        // property 'hostPlayerId'
        QtMocHelpers::PropertyData<QString>(41, QMetaType::QString, QMC::DefaultPropertyFlags, 13),
        // property 'sessionId'
        QtMocHelpers::PropertyData<QString>(39, QMetaType::QString, QMC::DefaultPropertyFlags, 14),
        // property 'remoteSelections'
        QtMocHelpers::PropertyData<QVariantMap>(51, 0x80000000 | 52, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 15),
        // property 'knownRoster'
        QtMocHelpers::PropertyData<QStringList>(53, QMetaType::QStringList, QMC::DefaultPropertyFlags, 7),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<EditorSession, qt_meta_tag_ZN13EditorSessionE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject EditorSession::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13EditorSessionE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13EditorSessionE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN13EditorSessionE_t>.metaTypes,
    nullptr
} };

void EditorSession::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<EditorSession *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->opReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 1: _t->opRejected((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 2: _t->editorEventReceived((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[3]))); break;
        case 3: _t->selectionReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 4: _t->cursorReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[3]))); break;
        case 5: _t->hostLost((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 6: _t->promotedToHost(); break;
        case 7: _t->knownRosterChanged(); break;
        case 8: _t->peerLeft((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 9: _t->opRateLimited((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2]))); break;
        case 10: _t->activeChanged(); break;
        case 11: _t->isHostChanged(); break;
        case 12: _t->localPlayerIdChanged(); break;
        case 13: _t->hostPlayerIdChanged(); break;
        case 14: _t->sessionIdChanged(); break;
        case 15: _t->remoteSelectionsChanged(); break;
        case 16: _t->onReliableReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[2]))); break;
        case 17: _t->onUdpReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 18: _t->onPlayerTimedOut((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 19: { QString _r = _t->electNewHost();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 20: { bool _r = _t->promoteToHost();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 21: _t->announceHostLeaving(); break;
        case 22: { bool _r = _t->startAsHost((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 23: { bool _r = _t->startAsHost((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 24: { bool _r = _t->startAsClient((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 25: { bool _r = _t->startAsClient((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 26: _t->stop(); break;
        case 27: _t->sendOp((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 28: _t->broadcastOp((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 29: _t->sendEvent((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 30: _t->sendEvent((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 31: _t->broadcastEvent((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 32: _t->broadcastEvent((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 33: _t->sendEventTo((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[3]))); break;
        case 34: _t->sendEventTo((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2]))); break;
        case 35: _t->sendCursor((*reinterpret_cast<std::add_pointer_t<qreal>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)(const QString & , const QJsonObject & )>(_a, &EditorSession::opReceived, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)(const QJsonObject & )>(_a, &EditorSession::opRejected, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)(int , const QString & , const QJsonObject & )>(_a, &EditorSession::editorEventReceived, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)(const QString & , const QJsonObject & )>(_a, &EditorSession::selectionReceived, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)(const QString & , qreal , qreal )>(_a, &EditorSession::cursorReceived, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)(const QString & )>(_a, &EditorSession::hostLost, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)()>(_a, &EditorSession::promotedToHost, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)()>(_a, &EditorSession::knownRosterChanged, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)(const QString & )>(_a, &EditorSession::peerLeft, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)(const QString & , int )>(_a, &EditorSession::opRateLimited, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)()>(_a, &EditorSession::activeChanged, 10))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)()>(_a, &EditorSession::isHostChanged, 11))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)()>(_a, &EditorSession::localPlayerIdChanged, 12))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)()>(_a, &EditorSession::hostPlayerIdChanged, 13))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)()>(_a, &EditorSession::sessionIdChanged, 14))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorSession::*)()>(_a, &EditorSession::remoteSelectionsChanged, 15))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->active(); break;
        case 1: *reinterpret_cast<bool*>(_v) = _t->isHost(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->localPlayerId(); break;
        case 3: *reinterpret_cast<QString*>(_v) = _t->hostPlayerId(); break;
        case 4: *reinterpret_cast<QString*>(_v) = _t->sessionId(); break;
        case 5: *reinterpret_cast<QVariantMap*>(_v) = _t->remoteSelections(); break;
        case 6: *reinterpret_cast<QStringList*>(_v) = _t->knownRoster(); break;
        default: break;
        }
    }
}

const QMetaObject *EditorSession::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *EditorSession::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13EditorSessionE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int EditorSession::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 36)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 36;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 36)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 36;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 7;
    }
    return _id;
}

// SIGNAL 0
void EditorSession::opReceived(const QString & _t1, const QJsonObject & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1, _t2);
}

// SIGNAL 1
void EditorSession::opRejected(const QJsonObject & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1);
}

// SIGNAL 2
void EditorSession::editorEventReceived(int _t1, const QString & _t2, const QJsonObject & _t3)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 2, nullptr, _t1, _t2, _t3);
}

// SIGNAL 3
void EditorSession::selectionReceived(const QString & _t1, const QJsonObject & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 3, nullptr, _t1, _t2);
}

// SIGNAL 4
void EditorSession::cursorReceived(const QString & _t1, qreal _t2, qreal _t3)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 4, nullptr, _t1, _t2, _t3);
}

// SIGNAL 5
void EditorSession::hostLost(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 5, nullptr, _t1);
}

// SIGNAL 6
void EditorSession::promotedToHost()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void EditorSession::knownRosterChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void EditorSession::peerLeft(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 8, nullptr, _t1);
}

// SIGNAL 9
void EditorSession::opRateLimited(const QString & _t1, int _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 9, nullptr, _t1, _t2);
}

// SIGNAL 10
void EditorSession::activeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 10, nullptr);
}

// SIGNAL 11
void EditorSession::isHostChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 11, nullptr);
}

// SIGNAL 12
void EditorSession::localPlayerIdChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 12, nullptr);
}

// SIGNAL 13
void EditorSession::hostPlayerIdChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 13, nullptr);
}

// SIGNAL 14
void EditorSession::sessionIdChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 14, nullptr);
}

// SIGNAL 15
void EditorSession::remoteSelectionsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 15, nullptr);
}
QT_WARNING_POP
