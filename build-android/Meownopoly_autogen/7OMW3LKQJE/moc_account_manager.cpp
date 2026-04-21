/****************************************************************************
** Meta object code from reading C++ file 'account_manager.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/account/account_manager.h"
#include <QtNetwork/QSslPreSharedKeyAuthenticator>
#include <QtNetwork/QSslError>
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'account_manager.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN14AccountManagerE_t {};
} // unnamed namespace

template <> constexpr inline auto AccountManager::qt_create_metaobjectdata<qt_meta_tag_ZN14AccountManagerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "AccountManager",
        "uniqueIdChanged",
        "",
        "nicknameChanged",
        "stunServerChanged",
        "stunPortChanged",
        "hasAccountChanged",
        "accountCreated",
        "setStunServerURL",
        "server",
        "setStunPort",
        "port",
        "createAccount",
        "nickname",
        "regenerateUniqueId",
        "loadAccount",
        "saveAccount",
        "uniqueId",
        "stunServer",
        "stunPort",
        "hasAccount"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'uniqueIdChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'nicknameChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'stunServerChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'stunPortChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'hasAccountChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'accountCreated'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'setStunServerURL'
        QtMocHelpers::MethodData<void(const QString &)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 9 },
        }}),
        // Method 'setStunPort'
        QtMocHelpers::MethodData<void(quint16)>(10, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::UShort, 11 },
        }}),
        // Method 'createAccount'
        QtMocHelpers::MethodData<void(const QString &)>(12, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 13 },
        }}),
        // Method 'regenerateUniqueId'
        QtMocHelpers::MethodData<bool()>(14, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'loadAccount'
        QtMocHelpers::MethodData<void()>(15, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'saveAccount'
        QtMocHelpers::MethodData<void()>(16, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'uniqueId'
        QtMocHelpers::PropertyData<QString>(17, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'nickname'
        QtMocHelpers::PropertyData<QString>(13, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'stunServer'
        QtMocHelpers::PropertyData<QString>(18, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable, 2),
        // property 'stunPort'
        QtMocHelpers::PropertyData<quint16>(19, QMetaType::UShort, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'hasAccount'
        QtMocHelpers::PropertyData<bool>(20, QMetaType::Bool, QMC::DefaultPropertyFlags, 4),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<AccountManager, qt_meta_tag_ZN14AccountManagerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject AccountManager::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14AccountManagerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14AccountManagerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN14AccountManagerE_t>.metaTypes,
    nullptr
} };

void AccountManager::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<AccountManager *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->uniqueIdChanged(); break;
        case 1: _t->nicknameChanged(); break;
        case 2: _t->stunServerChanged(); break;
        case 3: _t->stunPortChanged(); break;
        case 4: _t->hasAccountChanged(); break;
        case 5: _t->accountCreated(); break;
        case 6: _t->setStunServerURL((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 7: _t->setStunPort((*reinterpret_cast<std::add_pointer_t<quint16>>(_a[1]))); break;
        case 8: _t->createAccount((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 9: { bool _r = _t->regenerateUniqueId();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 10: _t->loadAccount(); break;
        case 11: _t->saveAccount(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (AccountManager::*)()>(_a, &AccountManager::uniqueIdChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (AccountManager::*)()>(_a, &AccountManager::nicknameChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (AccountManager::*)()>(_a, &AccountManager::stunServerChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (AccountManager::*)()>(_a, &AccountManager::stunPortChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (AccountManager::*)()>(_a, &AccountManager::hasAccountChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (AccountManager::*)()>(_a, &AccountManager::accountCreated, 5))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->uniqueId(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->nickname(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->stunServer(); break;
        case 3: *reinterpret_cast<quint16*>(_v) = _t->stunPort(); break;
        case 4: *reinterpret_cast<bool*>(_v) = _t->hasAccount(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 1: _t->setNickname(*reinterpret_cast<QString*>(_v)); break;
        case 2: _t->setStunServerURL(*reinterpret_cast<QString*>(_v)); break;
        case 3: _t->setStunPort(*reinterpret_cast<quint16*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *AccountManager::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *AccountManager::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN14AccountManagerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int AccountManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 12)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 12;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 12)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 12;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 5;
    }
    return _id;
}

// SIGNAL 0
void AccountManager::uniqueIdChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void AccountManager::nicknameChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void AccountManager::stunServerChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void AccountManager::stunPortChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void AccountManager::hasAccountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void AccountManager::accountCreated()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}
QT_WARNING_POP
