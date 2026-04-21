/****************************************************************************
** Meta object code from reading C++ file 'map.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/map/map.h"
#include <QtCore/qmetatype.h>
#include <QtCore/QList>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'map.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN3MapE_t {};
} // unnamed namespace

template <> constexpr inline auto Map::qt_create_metaobjectdata<qt_meta_tag_ZN3MapE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "Map",
        "caseTileCountChanged",
        "",
        "decorationTileCountChanged",
        "zoneTileCountChanged",
        "mapInfoChanged",
        "canSaveChanged",
        "mapLoaded",
        "Map*",
        "map",
        "foundItemSnapableTile",
        "ItemSnapable*",
        "itemSnapable",
        "tileRemovedFromHistory",
        "QUuid",
        "tileId",
        "tileRestoredFromHistory",
        "tile",
        "forceUnselectAll",
        "afterRestoration",
        "QList<QUuid>",
        "tileIds",
        "caseTileCount",
        "decorationTileCount",
        "zoneTileCount",
        "mapInfo",
        "MapInfo*",
        "canSave"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'caseTileCountChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'decorationTileCountChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'zoneTileCountChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'mapInfoChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'canSaveChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'mapLoaded'
        QtMocHelpers::SignalData<void(Map *)>(7, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 8, 9 },
        }}),
        // Signal 'foundItemSnapableTile'
        QtMocHelpers::SignalData<void(ItemSnapable *)>(10, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 11, 12 },
        }}),
        // Signal 'tileRemovedFromHistory'
        QtMocHelpers::SignalData<void(QUuid)>(13, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 14, 15 },
        }}),
        // Signal 'tileRestoredFromHistory'
        QtMocHelpers::SignalData<void(ItemSnapable *)>(16, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 11, 17 },
        }}),
        // Signal 'forceUnselectAll'
        QtMocHelpers::SignalData<void()>(18, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'afterRestoration'
        QtMocHelpers::SignalData<void(const QList<QUuid> &)>(19, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 20, 21 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'caseTileCount'
        QtMocHelpers::PropertyData<int>(22, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Final, 0),
        // property 'decorationTileCount'
        QtMocHelpers::PropertyData<int>(23, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Final, 1),
        // property 'zoneTileCount'
        QtMocHelpers::PropertyData<int>(24, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Final, 2),
        // property 'mapInfo'
        QtMocHelpers::PropertyData<MapInfo*>(25, 0x80000000 | 26, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 3),
        // property 'canSave'
        QtMocHelpers::PropertyData<bool>(27, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Final, 4),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<Map, qt_meta_tag_ZN3MapE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject Map::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN3MapE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN3MapE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN3MapE_t>.metaTypes,
    nullptr
} };

void Map::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<Map *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->caseTileCountChanged(); break;
        case 1: _t->decorationTileCountChanged(); break;
        case 2: _t->zoneTileCountChanged(); break;
        case 3: _t->mapInfoChanged(); break;
        case 4: _t->canSaveChanged(); break;
        case 5: _t->mapLoaded((*reinterpret_cast<std::add_pointer_t<Map*>>(_a[1]))); break;
        case 6: _t->foundItemSnapableTile((*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[1]))); break;
        case 7: _t->tileRemovedFromHistory((*reinterpret_cast<std::add_pointer_t<QUuid>>(_a[1]))); break;
        case 8: _t->tileRestoredFromHistory((*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[1]))); break;
        case 9: _t->forceUnselectAll(); break;
        case 10: _t->afterRestoration((*reinterpret_cast<std::add_pointer_t<QList<QUuid>>>(_a[1]))); break;
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
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< Map* >(); break;
            }
            break;
        case 6:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        case 8:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (Map::*)()>(_a, &Map::caseTileCountChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)()>(_a, &Map::decorationTileCountChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)()>(_a, &Map::zoneTileCountChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)()>(_a, &Map::mapInfoChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)()>(_a, &Map::canSaveChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)(Map * )>(_a, &Map::mapLoaded, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)(ItemSnapable * )>(_a, &Map::foundItemSnapableTile, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)(QUuid )>(_a, &Map::tileRemovedFromHistory, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)(ItemSnapable * )>(_a, &Map::tileRestoredFromHistory, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)()>(_a, &Map::forceUnselectAll, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (Map::*)(const QList<QUuid> & )>(_a, &Map::afterRestoration, 10))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 3:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< MapInfo* >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<int*>(_v) = _t->caseTileCount(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->decorationTileCount(); break;
        case 2: *reinterpret_cast<int*>(_v) = _t->zoneTileCount(); break;
        case 3: *reinterpret_cast<MapInfo**>(_v) = _t->getMapInfo(); break;
        case 4: *reinterpret_cast<bool*>(_v) = _t->canSave(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 3: _t->setMapInfo(*reinterpret_cast<MapInfo**>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *Map::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *Map::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN3MapE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int Map::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 11)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 11;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 11)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 11;
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
void Map::caseTileCountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void Map::decorationTileCountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void Map::zoneTileCountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void Map::mapInfoChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void Map::canSaveChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void Map::mapLoaded(Map * _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 5, nullptr, _t1);
}

// SIGNAL 6
void Map::foundItemSnapableTile(ItemSnapable * _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 6, nullptr, _t1);
}

// SIGNAL 7
void Map::tileRemovedFromHistory(QUuid _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 7, nullptr, _t1);
}

// SIGNAL 8
void Map::tileRestoredFromHistory(ItemSnapable * _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 8, nullptr, _t1);
}

// SIGNAL 9
void Map::forceUnselectAll()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}

// SIGNAL 10
void Map::afterRestoration(const QList<QUuid> & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 10, nullptr, _t1);
}
QT_WARNING_POP
