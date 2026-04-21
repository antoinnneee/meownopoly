/****************************************************************************
** Meta object code from reading C++ file 'ItemSnapable.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/item_snapable/ItemSnapable.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'ItemSnapable.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN12ItemSnapableE_t {};
} // unnamed namespace

template <> constexpr inline auto ItemSnapable::qt_create_metaobjectdata<qt_meta_tag_ZN12ItemSnapableE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "ItemSnapable",
        "caseDataChanged",
        "",
        "displayParameterChanged",
        "decorationParameterChanged",
        "zoneParameterChanged",
        "uniqueIdChanged",
        "tileTypeChanged",
        "toJSON",
        "print",
        "changeCaseDataType",
        "Case::CaseType",
        "caseType",
        "addNext",
        "ItemSnapable*",
        "newNext",
        "removeNext",
        "caseToRemove",
        "removeNextAt",
        "index",
        "addPrev",
        "newPrev",
        "removePrev",
        "removePrevAt",
        "getNextList",
        "QList<ItemSnapable*>",
        "getPrevList",
        "copyFrom",
        "source",
        "caseData",
        "Case*",
        "displayParameter",
        "DisplayParameter*",
        "decorationParameter",
        "DecorationParameter*",
        "zoneParameter",
        "ZoneParameter*",
        "uniqueId",
        "QUuid",
        "tileType",
        "TileType",
        "CaseTile",
        "DecorationTile",
        "PhysicZoneTile"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'caseDataChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'displayParameterChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'decorationParameterChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'zoneParameterChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'uniqueIdChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'tileTypeChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'toJSON'
        QtMocHelpers::MethodData<QString()>(8, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'print'
        QtMocHelpers::MethodData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'changeCaseDataType'
        QtMocHelpers::MethodData<void(Case::CaseType)>(10, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 11, 12 },
        }}),
        // Method 'addNext'
        QtMocHelpers::MethodData<void(ItemSnapable *)>(13, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 14, 15 },
        }}),
        // Method 'removeNext'
        QtMocHelpers::MethodData<bool(ItemSnapable *)>(16, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { 0x80000000 | 14, 17 },
        }}),
        // Method 'removeNextAt'
        QtMocHelpers::MethodData<bool(int)>(18, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::Int, 19 },
        }}),
        // Method 'addPrev'
        QtMocHelpers::MethodData<void(ItemSnapable *)>(20, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 14, 21 },
        }}),
        // Method 'removePrev'
        QtMocHelpers::MethodData<bool(ItemSnapable *)>(22, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { 0x80000000 | 14, 17 },
        }}),
        // Method 'removePrevAt'
        QtMocHelpers::MethodData<bool(int)>(23, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::Int, 19 },
        }}),
        // Method 'getNextList'
        QtMocHelpers::MethodData<QList<ItemSnapable*>()>(24, 2, QMC::AccessPublic, 0x80000000 | 25),
        // Method 'getPrevList'
        QtMocHelpers::MethodData<QList<ItemSnapable*>()>(26, 2, QMC::AccessPublic, 0x80000000 | 25),
        // Method 'copyFrom'
        QtMocHelpers::MethodData<void(ItemSnapable *)>(27, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 14, 28 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'caseData'
        QtMocHelpers::PropertyData<Case*>(29, 0x80000000 | 30, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 0),
        // property 'displayParameter'
        QtMocHelpers::PropertyData<DisplayParameter*>(31, 0x80000000 | 32, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 1),
        // property 'decorationParameter'
        QtMocHelpers::PropertyData<DecorationParameter*>(33, 0x80000000 | 34, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 2),
        // property 'zoneParameter'
        QtMocHelpers::PropertyData<ZoneParameter*>(35, 0x80000000 | 36, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 3),
        // property 'uniqueId'
        QtMocHelpers::PropertyData<QUuid>(37, 0x80000000 | 38, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 4),
        // property 'tileType'
        QtMocHelpers::PropertyData<enum TileType>(39, 0x80000000 | 40, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 5),
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'TileType'
        QtMocHelpers::EnumData<enum TileType>(40, 40, QMC::EnumFlags{}).add({
            {   41, TileType::CaseTile },
            {   42, TileType::DecorationTile },
            {   43, TileType::PhysicZoneTile },
        }),
    };
    return QtMocHelpers::metaObjectData<ItemSnapable, qt_meta_tag_ZN12ItemSnapableE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject ItemSnapable::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12ItemSnapableE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12ItemSnapableE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN12ItemSnapableE_t>.metaTypes,
    nullptr
} };

void ItemSnapable::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<ItemSnapable *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->caseDataChanged(); break;
        case 1: _t->displayParameterChanged(); break;
        case 2: _t->decorationParameterChanged(); break;
        case 3: _t->zoneParameterChanged(); break;
        case 4: _t->uniqueIdChanged(); break;
        case 5: _t->tileTypeChanged(); break;
        case 6: { QString _r = _t->toJSON();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 7: _t->print(); break;
        case 8: _t->changeCaseDataType((*reinterpret_cast<std::add_pointer_t<Case::CaseType>>(_a[1]))); break;
        case 9: _t->addNext((*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[1]))); break;
        case 10: { bool _r = _t->removeNext((*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 11: { bool _r = _t->removeNextAt((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 12: _t->addPrev((*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[1]))); break;
        case 13: { bool _r = _t->removePrev((*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 14: { bool _r = _t->removePrevAt((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 15: { QList<ItemSnapable*> _r = _t->getNextList();
            if (_a[0]) *reinterpret_cast<QList<ItemSnapable*>*>(_a[0]) = std::move(_r); }  break;
        case 16: { QList<ItemSnapable*> _r = _t->getPrevList();
            if (_a[0]) *reinterpret_cast<QList<ItemSnapable*>*>(_a[0]) = std::move(_r); }  break;
        case 17: _t->copyFrom((*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 9:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        case 10:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        case 12:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        case 13:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        case 17:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (ItemSnapable::*)()>(_a, &ItemSnapable::caseDataChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (ItemSnapable::*)()>(_a, &ItemSnapable::displayParameterChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (ItemSnapable::*)()>(_a, &ItemSnapable::decorationParameterChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (ItemSnapable::*)()>(_a, &ItemSnapable::zoneParameterChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (ItemSnapable::*)()>(_a, &ItemSnapable::uniqueIdChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (ItemSnapable::*)()>(_a, &ItemSnapable::tileTypeChanged, 5))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 0:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< Case* >(); break;
        case 2:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< DecorationParameter* >(); break;
        case 1:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< DisplayParameter* >(); break;
        case 3:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< ZoneParameter* >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<Case**>(_v) = _t->caseData(); break;
        case 1: *reinterpret_cast<DisplayParameter**>(_v) = _t->displayParameter(); break;
        case 2: *reinterpret_cast<DecorationParameter**>(_v) = _t->decorationParameter(); break;
        case 3: *reinterpret_cast<ZoneParameter**>(_v) = _t->zoneParameter(); break;
        case 4: *reinterpret_cast<QUuid*>(_v) = _t->uniqueId(); break;
        case 5: *reinterpret_cast<enum TileType*>(_v) = _t->tileType(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setCaseData(*reinterpret_cast<Case**>(_v)); break;
        case 1: _t->setDisplayParameter(*reinterpret_cast<DisplayParameter**>(_v)); break;
        case 2: _t->setDecorationParameter(*reinterpret_cast<DecorationParameter**>(_v)); break;
        case 3: _t->setZoneParameter(*reinterpret_cast<ZoneParameter**>(_v)); break;
        case 4: _t->setUniqueId(*reinterpret_cast<QUuid*>(_v)); break;
        case 5: _t->setTileType(*reinterpret_cast<enum TileType*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *ItemSnapable::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *ItemSnapable::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12ItemSnapableE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int ItemSnapable::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
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
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    }
    return _id;
}

// SIGNAL 0
void ItemSnapable::caseDataChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void ItemSnapable::displayParameterChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void ItemSnapable::decorationParameterChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void ItemSnapable::zoneParameterChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void ItemSnapable::uniqueIdChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void ItemSnapable::tileTypeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}
QT_WARNING_POP
