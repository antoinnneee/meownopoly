/****************************************************************************
** Meta object code from reading C++ file 'CaseCatPerks.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/case/CaseCatPerks.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'CaseCatPerks.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN12CaseCatPerksE_t {};
} // unnamed namespace

template <> constexpr inline auto CaseCatPerks::qt_create_metaobjectdata<qt_meta_tag_ZN12CaseCatPerksE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "CaseCatPerks",
        "priceChanged",
        "",
        "sellPriceChanged",
        "morgagePriceChanged",
        "ownerChanged",
        "setOwner",
        "Player*",
        "newOwner",
        "toJSON",
        "price",
        "sellPrice",
        "morgagePrice",
        "owner"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'priceChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'sellPriceChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'morgagePriceChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'ownerChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'setOwner'
        QtMocHelpers::MethodData<void(Player *)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 7, 8 },
        }}),
        // Method 'toJSON'
        QtMocHelpers::MethodData<QString()>(9, 2, QMC::AccessPublic, QMetaType::QString),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'price'
        QtMocHelpers::PropertyData<int>(10, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 0),
        // property 'sellPrice'
        QtMocHelpers::PropertyData<int>(11, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::Final, 1),
        // property 'morgagePrice'
        QtMocHelpers::PropertyData<int>(12, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::Final, 2),
        // property 'owner'
        QtMocHelpers::PropertyData<Player*>(13, 0x80000000 | 7, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 3),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<CaseCatPerks, qt_meta_tag_ZN12CaseCatPerksE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject CaseCatPerks::staticMetaObject = { {
    QMetaObject::SuperData::link<Case::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CaseCatPerksE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CaseCatPerksE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN12CaseCatPerksE_t>.metaTypes,
    nullptr
} };

void CaseCatPerks::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<CaseCatPerks *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->priceChanged(); break;
        case 1: _t->sellPriceChanged(); break;
        case 2: _t->morgagePriceChanged(); break;
        case 3: _t->ownerChanged(); break;
        case 4: _t->setOwner((*reinterpret_cast<std::add_pointer_t<Player*>>(_a[1]))); break;
        case 5: { QString _r = _t->toJSON();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 4:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< Player* >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (CaseCatPerks::*)()>(_a, &CaseCatPerks::priceChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (CaseCatPerks::*)()>(_a, &CaseCatPerks::sellPriceChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (CaseCatPerks::*)()>(_a, &CaseCatPerks::morgagePriceChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (CaseCatPerks::*)()>(_a, &CaseCatPerks::ownerChanged, 3))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 3:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< Player* >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<int*>(_v) = _t->price(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->sellPrice(); break;
        case 2: *reinterpret_cast<int*>(_v) = _t->morgagePrice(); break;
        case 3: *reinterpret_cast<Player**>(_v) = _t->owner(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setPrice(*reinterpret_cast<int*>(_v)); break;
        case 1: _t->setsellPrice(*reinterpret_cast<int*>(_v)); break;
        case 2: _t->setmorgagePrice(*reinterpret_cast<int*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *CaseCatPerks::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *CaseCatPerks::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CaseCatPerksE_t>.strings))
        return static_cast<void*>(this);
    return Case::qt_metacast(_clname);
}

int CaseCatPerks::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = Case::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 6)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 6)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
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
void CaseCatPerks::priceChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void CaseCatPerks::sellPriceChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void CaseCatPerks::morgagePriceChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void CaseCatPerks::ownerChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}
QT_WARNING_POP
