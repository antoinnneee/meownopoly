/****************************************************************************
** Meta object code from reading C++ file 'chat_session_manager.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/chat/chat_session_manager.h"
#include <QtNetwork/QSslPreSharedKeyAuthenticator>
#include <QtNetwork/QSslError>
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'chat_session_manager.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN18ChatSessionManagerE_t {};
} // unnamed namespace

template <> constexpr inline auto ChatSessionManager::qt_create_metaobjectdata<qt_meta_tag_ZN18ChatSessionManagerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "ChatSessionManager",
        "availableSessionsChanged",
        "",
        "statsChanged",
        "serverConnectedChanged",
        "sessionJoined",
        "ChatClient*",
        "client",
        "sessionId",
        "sessionLeft",
        "sessionError",
        "error",
        "errorType",
        "sessionNameForId",
        "serverClient",
        "joinSession",
        "password",
        "createAndJoinSession",
        "name",
        "leaveSession",
        "setActiveSession",
        "clientForSession",
        "requestSessionsRefresh",
        "availableSessions",
        "QVariantList",
        "totalPlayerCount",
        "activeSessionCount",
        "serverConnected"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'availableSessionsChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'statsChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'serverConnectedChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'sessionJoined'
        QtMocHelpers::SignalData<void(ChatClient *, const QString &)>(5, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 6, 7 }, { QMetaType::QString, 8 },
        }}),
        // Signal 'sessionLeft'
        QtMocHelpers::SignalData<void(const QString &)>(9, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 8 },
        }}),
        // Signal 'sessionError'
        QtMocHelpers::SignalData<void(const QString &, const QString &, int)>(10, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 8 }, { QMetaType::QString, 11 }, { QMetaType::Int, 12 },
        }}),
        // Method 'sessionNameForId'
        QtMocHelpers::MethodData<QString(const QString &) const>(13, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 8 },
        }}),
        // Method 'serverClient'
        QtMocHelpers::MethodData<ChatClient *() const>(14, 2, QMC::AccessPublic, 0x80000000 | 6),
        // Method 'joinSession'
        QtMocHelpers::MethodData<ChatClient *(const QString &, const QString &)>(15, 2, QMC::AccessPublic, 0x80000000 | 6, {{
            { QMetaType::QString, 8 }, { QMetaType::QString, 16 },
        }}),
        // Method 'createAndJoinSession'
        QtMocHelpers::MethodData<ChatClient *(const QString &, const QString &)>(17, 2, QMC::AccessPublic, 0x80000000 | 6, {{
            { QMetaType::QString, 18 }, { QMetaType::QString, 16 },
        }}),
        // Method 'leaveSession'
        QtMocHelpers::MethodData<void(ChatClient *)>(19, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 6, 7 },
        }}),
        // Method 'setActiveSession'
        QtMocHelpers::MethodData<void(ChatClient *)>(20, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 6, 7 },
        }}),
        // Method 'clientForSession'
        QtMocHelpers::MethodData<ChatClient *(const QString &) const>(21, 2, QMC::AccessPublic, 0x80000000 | 6, {{
            { QMetaType::QString, 8 },
        }}),
        // Method 'requestSessionsRefresh'
        QtMocHelpers::MethodData<void()>(22, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'availableSessions'
        QtMocHelpers::PropertyData<QVariantList>(23, 0x80000000 | 24, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'totalPlayerCount'
        QtMocHelpers::PropertyData<int>(25, QMetaType::Int, QMC::DefaultPropertyFlags, 1),
        // property 'activeSessionCount'
        QtMocHelpers::PropertyData<int>(26, QMetaType::Int, QMC::DefaultPropertyFlags, 1),
        // property 'serverConnected'
        QtMocHelpers::PropertyData<bool>(27, QMetaType::Bool, QMC::DefaultPropertyFlags, 2),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<ChatSessionManager, qt_meta_tag_ZN18ChatSessionManagerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject ChatSessionManager::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN18ChatSessionManagerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN18ChatSessionManagerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN18ChatSessionManagerE_t>.metaTypes,
    nullptr
} };

void ChatSessionManager::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<ChatSessionManager *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->availableSessionsChanged(); break;
        case 1: _t->statsChanged(); break;
        case 2: _t->serverConnectedChanged(); break;
        case 3: _t->sessionJoined((*reinterpret_cast<std::add_pointer_t<ChatClient*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 4: _t->sessionLeft((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 5: _t->sessionError((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[3]))); break;
        case 6: { QString _r = _t->sessionNameForId((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 7: { ChatClient* _r = _t->serverClient();
            if (_a[0]) *reinterpret_cast<ChatClient**>(_a[0]) = std::move(_r); }  break;
        case 8: { ChatClient* _r = _t->joinSession((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<ChatClient**>(_a[0]) = std::move(_r); }  break;
        case 9: { ChatClient* _r = _t->createAndJoinSession((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<ChatClient**>(_a[0]) = std::move(_r); }  break;
        case 10: _t->leaveSession((*reinterpret_cast<std::add_pointer_t<ChatClient*>>(_a[1]))); break;
        case 11: _t->setActiveSession((*reinterpret_cast<std::add_pointer_t<ChatClient*>>(_a[1]))); break;
        case 12: { ChatClient* _r = _t->clientForSession((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<ChatClient**>(_a[0]) = std::move(_r); }  break;
        case 13: _t->requestSessionsRefresh(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 3:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ChatClient* >(); break;
            }
            break;
        case 10:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ChatClient* >(); break;
            }
            break;
        case 11:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ChatClient* >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (ChatSessionManager::*)()>(_a, &ChatSessionManager::availableSessionsChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatSessionManager::*)()>(_a, &ChatSessionManager::statsChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatSessionManager::*)()>(_a, &ChatSessionManager::serverConnectedChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatSessionManager::*)(ChatClient * , const QString & )>(_a, &ChatSessionManager::sessionJoined, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatSessionManager::*)(const QString & )>(_a, &ChatSessionManager::sessionLeft, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatSessionManager::*)(const QString & , const QString & , int )>(_a, &ChatSessionManager::sessionError, 5))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QVariantList*>(_v) = _t->availableSessions(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->totalPlayerCount(); break;
        case 2: *reinterpret_cast<int*>(_v) = _t->activeSessionCount(); break;
        case 3: *reinterpret_cast<bool*>(_v) = _t->serverConnected(); break;
        default: break;
        }
    }
}

const QMetaObject *ChatSessionManager::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *ChatSessionManager::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN18ChatSessionManagerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int ChatSessionManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 14)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 14;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 14)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 14;
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
void ChatSessionManager::availableSessionsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void ChatSessionManager::statsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void ChatSessionManager::serverConnectedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void ChatSessionManager::sessionJoined(ChatClient * _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 3, nullptr, _t1, _t2);
}

// SIGNAL 4
void ChatSessionManager::sessionLeft(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 4, nullptr, _t1);
}

// SIGNAL 5
void ChatSessionManager::sessionError(const QString & _t1, const QString & _t2, int _t3)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 5, nullptr, _t1, _t2, _t3);
}
QT_WARNING_POP
