/****************************************************************************
** Meta object code from reading C++ file 'itemsnapablefactory.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/item_snapable/itemsnapablefactory.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'itemsnapablefactory.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN19ItemSnapableFactoryE_t {};
} // unnamed namespace

template <> constexpr inline auto ItemSnapableFactory::qt_create_metaobjectdata<qt_meta_tag_ZN19ItemSnapableFactoryE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "ItemSnapableFactory",
        "createItemRequested",
        "",
        "QJsonObject",
        "jsonData",
        "createItemsRequested",
        "QJsonArray",
        "jsonArray",
        "createItemSnapable",
        "ItemSnapable*",
        "Case::CaseType",
        "caseType",
        "createItemSnapableFromJson",
        "json",
        "createPhysicZone",
        "requestCreateItem",
        "requestCreateItems"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'createItemRequested'
        QtMocHelpers::SignalData<void(const QJsonObject &)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 },
        }}),
        // Signal 'createItemsRequested'
        QtMocHelpers::SignalData<void(const QJsonArray &)>(5, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 6, 7 },
        }}),
        // Method 'createItemSnapable'
        QtMocHelpers::MethodData<ItemSnapable *()>(8, 2, QMC::AccessPublic, 0x80000000 | 9),
        // Method 'createItemSnapable'
        QtMocHelpers::MethodData<ItemSnapable *(Case::CaseType)>(8, 2, QMC::AccessPublic, 0x80000000 | 9, {{
            { 0x80000000 | 10, 11 },
        }}),
        // Method 'createItemSnapableFromJson'
        QtMocHelpers::MethodData<ItemSnapable *(const QJsonObject &)>(12, 2, QMC::AccessPublic, 0x80000000 | 9, {{
            { 0x80000000 | 3, 13 },
        }}),
        // Method 'createPhysicZone'
        QtMocHelpers::MethodData<ItemSnapable *()>(14, 2, QMC::AccessPublic, 0x80000000 | 9),
        // Method 'requestCreateItem'
        QtMocHelpers::MethodData<void(const QJsonObject &)>(15, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 },
        }}),
        // Method 'requestCreateItems'
        QtMocHelpers::MethodData<void(const QJsonArray &)>(16, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 6, 7 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<ItemSnapableFactory, qt_meta_tag_ZN19ItemSnapableFactoryE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject ItemSnapableFactory::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN19ItemSnapableFactoryE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN19ItemSnapableFactoryE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN19ItemSnapableFactoryE_t>.metaTypes,
    nullptr
} };

void ItemSnapableFactory::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<ItemSnapableFactory *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->createItemRequested((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 1: _t->createItemsRequested((*reinterpret_cast<std::add_pointer_t<QJsonArray>>(_a[1]))); break;
        case 2: { ItemSnapable* _r = _t->createItemSnapable();
            if (_a[0]) *reinterpret_cast<ItemSnapable**>(_a[0]) = std::move(_r); }  break;
        case 3: { ItemSnapable* _r = _t->createItemSnapable((*reinterpret_cast<std::add_pointer_t<Case::CaseType>>(_a[1])));
            if (_a[0]) *reinterpret_cast<ItemSnapable**>(_a[0]) = std::move(_r); }  break;
        case 4: { ItemSnapable* _r = _t->createItemSnapableFromJson((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1])));
            if (_a[0]) *reinterpret_cast<ItemSnapable**>(_a[0]) = std::move(_r); }  break;
        case 5: { ItemSnapable* _r = _t->createPhysicZone();
            if (_a[0]) *reinterpret_cast<ItemSnapable**>(_a[0]) = std::move(_r); }  break;
        case 6: _t->requestCreateItem((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 7: _t->requestCreateItems((*reinterpret_cast<std::add_pointer_t<QJsonArray>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (ItemSnapableFactory::*)(const QJsonObject & )>(_a, &ItemSnapableFactory::createItemRequested, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (ItemSnapableFactory::*)(const QJsonArray & )>(_a, &ItemSnapableFactory::createItemsRequested, 1))
            return;
    }
}

const QMetaObject *ItemSnapableFactory::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *ItemSnapableFactory::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN19ItemSnapableFactoryE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int ItemSnapableFactory::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 8)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 8;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 8)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 8;
    }
    return _id;
}

// SIGNAL 0
void ItemSnapableFactory::createItemRequested(const QJsonObject & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void ItemSnapableFactory::createItemsRequested(const QJsonArray & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1);
}
QT_WARNING_POP
