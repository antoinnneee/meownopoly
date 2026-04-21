/****************************************************************************
** Meta object code from reading C++ file 'stun_manager.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/communication/stun_manager.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'stun_manager.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN11StunManagerE_t {};
} // unnamed namespace

template <> constexpr inline auto StunManager::qt_create_metaobjectdata<qt_meta_tag_ZN11StunManagerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "StunManager",
        "log",
        "",
        "message",
        "serverStarted",
        "localPort",
        "externalAddressReceived",
        "ip",
        "port",
        "stunFailed",
        "currentSocketInfoChanged",
        "UdpSocketInfo*",
        "info",
        "handleStunResponse",
        "datagram",
        "QHostAddress",
        "sender",
        "senderPort",
        "onReadyRead",
        "onStunTimeout",
        "startServer",
        "stopServer",
        "sendStunRequest",
        "setStunServer",
        "getStunServer",
        "getStunPort",
        "setPublicPort",
        "setStunSenderAddress",
        "setStunSenderPort",
        "getExternalIp",
        "getExternalPort",
        "getSocket",
        "QUdpSocket*",
        "currentSocketInfo",
        "takeSocket"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'log'
        QtMocHelpers::SignalData<void(QString)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 3 },
        }}),
        // Signal 'serverStarted'
        QtMocHelpers::SignalData<void(quint16)>(4, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::UShort, 5 },
        }}),
        // Signal 'externalAddressReceived'
        QtMocHelpers::SignalData<void(QString, quint16)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::UShort, 8 },
        }}),
        // Signal 'stunFailed'
        QtMocHelpers::SignalData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'currentSocketInfoChanged'
        QtMocHelpers::SignalData<void(UdpSocketInfo *)>(10, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 11, 12 },
        }}),
        // Slot 'handleStunResponse'
        QtMocHelpers::SlotData<void(const QByteArray &, const QHostAddress &, quint16)>(13, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QByteArray, 14 }, { 0x80000000 | 15, 16 }, { QMetaType::UShort, 17 },
        }}),
        // Slot 'onReadyRead'
        QtMocHelpers::SlotData<void()>(18, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onStunTimeout'
        QtMocHelpers::SlotData<void()>(19, 2, QMC::AccessPrivate, QMetaType::Void),
        // Method 'startServer'
        QtMocHelpers::MethodData<bool()>(20, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'stopServer'
        QtMocHelpers::MethodData<void()>(21, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'sendStunRequest'
        QtMocHelpers::MethodData<void()>(22, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'setStunServer'
        QtMocHelpers::MethodData<void(QString, quint16)>(23, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::UShort, 8 },
        }}),
        // Method 'getStunServer'
        QtMocHelpers::MethodData<QString() const>(24, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'getStunPort'
        QtMocHelpers::MethodData<quint16() const>(25, 2, QMC::AccessPublic, QMetaType::UShort),
        // Method 'setPublicPort'
        QtMocHelpers::MethodData<void(quint16)>(26, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::UShort, 8 },
        }}),
        // Method 'setStunSenderAddress'
        QtMocHelpers::MethodData<void(QString)>(27, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 7 },
        }}),
        // Method 'setStunSenderPort'
        QtMocHelpers::MethodData<void(quint16)>(28, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::UShort, 8 },
        }}),
        // Method 'getExternalIp'
        QtMocHelpers::MethodData<QString() const>(29, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'getExternalPort'
        QtMocHelpers::MethodData<quint16() const>(30, 2, QMC::AccessPublic, QMetaType::UShort),
        // Method 'getSocket'
        QtMocHelpers::MethodData<QUdpSocket *() const>(31, 2, QMC::AccessPublic, 0x80000000 | 32),
        // Method 'currentSocketInfo'
        QtMocHelpers::MethodData<UdpSocketInfo *() const>(33, 2, QMC::AccessPublic, 0x80000000 | 11),
        // Method 'takeSocket'
        QtMocHelpers::MethodData<UdpSocketInfo *()>(34, 2, QMC::AccessPublic, 0x80000000 | 11),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<StunManager, qt_meta_tag_ZN11StunManagerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject StunManager::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11StunManagerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11StunManagerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN11StunManagerE_t>.metaTypes,
    nullptr
} };

void StunManager::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<StunManager *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->log((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 1: _t->serverStarted((*reinterpret_cast<std::add_pointer_t<quint16>>(_a[1]))); break;
        case 2: _t->externalAddressReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[2]))); break;
        case 3: _t->stunFailed(); break;
        case 4: _t->currentSocketInfoChanged((*reinterpret_cast<std::add_pointer_t<UdpSocketInfo*>>(_a[1]))); break;
        case 5: _t->handleStunResponse((*reinterpret_cast<std::add_pointer_t<QByteArray>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QHostAddress>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[3]))); break;
        case 6: _t->onReadyRead(); break;
        case 7: _t->onStunTimeout(); break;
        case 8: { bool _r = _t->startServer();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 9: _t->stopServer(); break;
        case 10: _t->sendStunRequest(); break;
        case 11: _t->setStunServer((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[2]))); break;
        case 12: { QString _r = _t->getStunServer();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 13: { quint16 _r = _t->getStunPort();
            if (_a[0]) *reinterpret_cast<quint16*>(_a[0]) = std::move(_r); }  break;
        case 14: _t->setPublicPort((*reinterpret_cast<std::add_pointer_t<quint16>>(_a[1]))); break;
        case 15: _t->setStunSenderAddress((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 16: _t->setStunSenderPort((*reinterpret_cast<std::add_pointer_t<quint16>>(_a[1]))); break;
        case 17: { QString _r = _t->getExternalIp();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 18: { quint16 _r = _t->getExternalPort();
            if (_a[0]) *reinterpret_cast<quint16*>(_a[0]) = std::move(_r); }  break;
        case 19: { QUdpSocket* _r = _t->getSocket();
            if (_a[0]) *reinterpret_cast<QUdpSocket**>(_a[0]) = std::move(_r); }  break;
        case 20: { UdpSocketInfo* _r = _t->currentSocketInfo();
            if (_a[0]) *reinterpret_cast<UdpSocketInfo**>(_a[0]) = std::move(_r); }  break;
        case 21: { UdpSocketInfo* _r = _t->takeSocket();
            if (_a[0]) *reinterpret_cast<UdpSocketInfo**>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (StunManager::*)(QString )>(_a, &StunManager::log, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (StunManager::*)(quint16 )>(_a, &StunManager::serverStarted, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (StunManager::*)(QString , quint16 )>(_a, &StunManager::externalAddressReceived, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (StunManager::*)()>(_a, &StunManager::stunFailed, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (StunManager::*)(UdpSocketInfo * )>(_a, &StunManager::currentSocketInfoChanged, 4))
            return;
    }
}

const QMetaObject *StunManager::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *StunManager::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11StunManagerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int StunManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 22)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 22;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 22)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 22;
    }
    return _id;
}

// SIGNAL 0
void StunManager::log(QString _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void StunManager::serverStarted(quint16 _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1);
}

// SIGNAL 2
void StunManager::externalAddressReceived(QString _t1, quint16 _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 2, nullptr, _t1, _t2);
}

// SIGNAL 3
void StunManager::stunFailed()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void StunManager::currentSocketInfoChanged(UdpSocketInfo * _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 4, nullptr, _t1);
}
QT_WARNING_POP
