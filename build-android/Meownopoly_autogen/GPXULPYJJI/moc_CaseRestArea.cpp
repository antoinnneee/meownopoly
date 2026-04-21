/****************************************************************************
** Meta object code from reading C++ file 'CaseRestArea.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/case/CaseRestArea.h"
#include <QtCore/qmetatype.h>
#include <QtCore/QList>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'CaseRestArea.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN12CaseRestAreaE_t {};
} // unnamed namespace

template <> constexpr inline auto CaseRestArea::qt_create_metaobjectdata<qt_meta_tag_ZN12CaseRestAreaE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "CaseRestArea",
        "restQualityChanged",
        "",
        "familyChanged",
        "housePriceChanged",
        "hotelPriceChanged",
        "rentPriceChanged",
        "buyCase",
        "Player*",
        "buyer",
        "sellCase",
        "toJSON",
        "restQuality",
        "RestQuality",
        "family",
        "FamilyType",
        "housePrice",
        "hotelPrice",
        "rentPrice",
        "QList<int>",
        "RQ_NONE",
        "RQ_1STAR",
        "RQ_2STAR",
        "RQ_3STAR",
        "RQ_4STAR",
        "RQ_HOTEL",
        "RQ_COUNT",
        "FT_NONE",
        "FT_BROWN",
        "FT_LIGHTBLUE",
        "FT_PINK",
        "FT_ORANGE",
        "FT_RED",
        "FT_YELLOW",
        "FT_GREEN",
        "FT_DARKBLUE",
        "FT_COUNT"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'restQualityChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'familyChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'housePriceChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'hotelPriceChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'rentPriceChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'buyCase'
        QtMocHelpers::MethodData<bool(Player *)>(7, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { 0x80000000 | 8, 9 },
        }}),
        // Method 'sellCase'
        QtMocHelpers::MethodData<bool(Player *)>(10, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { 0x80000000 | 8, 9 },
        }}),
        // Method 'toJSON'
        QtMocHelpers::MethodData<QString()>(11, 2, QMC::AccessPublic, QMetaType::QString),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'restQuality'
        QtMocHelpers::PropertyData<enum RestQuality>(12, 0x80000000 | 13, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet, 0),
        // property 'family'
        QtMocHelpers::PropertyData<enum FamilyType>(14, 0x80000000 | 15, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet, 1),
        // property 'housePrice'
        QtMocHelpers::PropertyData<int>(16, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 2),
        // property 'hotelPrice'
        QtMocHelpers::PropertyData<int>(17, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 3),
        // property 'rentPrice'
        QtMocHelpers::PropertyData<QList<int>>(18, 0x80000000 | 19, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 4),
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'RestQuality'
        QtMocHelpers::EnumData<enum RestQuality>(13, 13, QMC::EnumFlags{}).add({
            {   20, RestQuality::RQ_NONE },
            {   21, RestQuality::RQ_1STAR },
            {   22, RestQuality::RQ_2STAR },
            {   23, RestQuality::RQ_3STAR },
            {   24, RestQuality::RQ_4STAR },
            {   25, RestQuality::RQ_HOTEL },
            {   26, RestQuality::RQ_COUNT },
        }),
        // enum 'FamilyType'
        QtMocHelpers::EnumData<enum FamilyType>(15, 15, QMC::EnumFlags{}).add({
            {   27, FamilyType::FT_NONE },
            {   28, FamilyType::FT_BROWN },
            {   29, FamilyType::FT_LIGHTBLUE },
            {   30, FamilyType::FT_PINK },
            {   31, FamilyType::FT_ORANGE },
            {   32, FamilyType::FT_RED },
            {   33, FamilyType::FT_YELLOW },
            {   34, FamilyType::FT_GREEN },
            {   35, FamilyType::FT_DARKBLUE },
            {   36, FamilyType::FT_COUNT },
        }),
    };
    return QtMocHelpers::metaObjectData<CaseRestArea, qt_meta_tag_ZN12CaseRestAreaE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject CaseRestArea::staticMetaObject = { {
    QMetaObject::SuperData::link<CaseCatPerks::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CaseRestAreaE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CaseRestAreaE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN12CaseRestAreaE_t>.metaTypes,
    nullptr
} };

void CaseRestArea::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<CaseRestArea *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->restQualityChanged(); break;
        case 1: _t->familyChanged(); break;
        case 2: _t->housePriceChanged(); break;
        case 3: _t->hotelPriceChanged(); break;
        case 4: _t->rentPriceChanged(); break;
        case 5: { bool _r = _t->buyCase((*reinterpret_cast<std::add_pointer_t<Player*>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 6: { bool _r = _t->sellCase((*reinterpret_cast<std::add_pointer_t<Player*>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 7: { QString _r = _t->toJSON();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 5:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< Player* >(); break;
            }
            break;
        case 6:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< Player* >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (CaseRestArea::*)()>(_a, &CaseRestArea::restQualityChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (CaseRestArea::*)()>(_a, &CaseRestArea::familyChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (CaseRestArea::*)()>(_a, &CaseRestArea::housePriceChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (CaseRestArea::*)()>(_a, &CaseRestArea::hotelPriceChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (CaseRestArea::*)()>(_a, &CaseRestArea::rentPriceChanged, 4))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 4:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< QList<int> >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<enum RestQuality*>(_v) = _t->restQuality(); break;
        case 1: *reinterpret_cast<enum FamilyType*>(_v) = _t->family(); break;
        case 2: *reinterpret_cast<int*>(_v) = _t->housePrice(); break;
        case 3: *reinterpret_cast<int*>(_v) = _t->hotelPrice(); break;
        case 4: *reinterpret_cast<QList<int>*>(_v) = _t->rentPrice(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setRestQuality(*reinterpret_cast<enum RestQuality*>(_v)); break;
        case 1: _t->setFamily(*reinterpret_cast<enum FamilyType*>(_v)); break;
        case 2: _t->setHousePrice(*reinterpret_cast<int*>(_v)); break;
        case 3: _t->setHotelPrice(*reinterpret_cast<int*>(_v)); break;
        case 4: _t->setRentPrice(*reinterpret_cast<QList<int>*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *CaseRestArea::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *CaseRestArea::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12CaseRestAreaE_t>.strings))
        return static_cast<void*>(this);
    return CaseCatPerks::qt_metacast(_clname);
}

int CaseRestArea::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = CaseCatPerks::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 8)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 8;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 8)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 8;
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
void CaseRestArea::restQualityChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void CaseRestArea::familyChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void CaseRestArea::housePriceChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void CaseRestArea::hotelPriceChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void CaseRestArea::rentPriceChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}
QT_WARNING_POP
