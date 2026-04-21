/****************************************************************************
** Meta object code from reading C++ file 'game.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/game.h"
#include <QtCore/qmetatype.h>
#include <QtCore/QList>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'game.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN4GameE_t {};
} // unnamed namespace

template <> constexpr inline auto Game::qt_create_metaobjectdata<qt_meta_tag_ZN4GameE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "Game",
        "gameStarted",
        "",
        "clearCurrentMap",
        "mapLoaded",
        "Map*",
        "map",
        "foundItemSnapableTile",
        "ItemSnapable*",
        "itemSnapable",
        "tileRemoved",
        "QUuid",
        "tileId",
        "forceUnselectAll",
        "afterRestoration",
        "QList<QUuid>",
        "tileIds",
        "startGame",
        "saveCurrentMap",
        "saveMap",
        "MapInfo*",
        "mapInfo",
        "QVariantList",
        "itemSnapableList",
        "MapTypes::MapType",
        "mapType",
        "deleteMap",
        "mapName",
        "loadMap",
        "generateItems",
        "QList<ItemSnapable*>",
        "QJsonObject",
        "jsonObject",
        "askPreview",
        "askNext",
        "updateMap",
        "type",
        "tile",
        "groupId",
        "updateMapMetadata",
        "beforeJson",
        "afterJson",
        "beginTransaction",
        "commitTransaction",
        "finalizeDeletedTile",
        "applyRemoteDelta",
        "before",
        "after",
        "applyBefore",
        "initEmptyCollabMap",
        "saveTemplate",
        "name",
        "QJsonArray",
        "elementsJson",
        "deleteTemplate",
        "loadTemplate",
        "getTemplateElementsForPlacement",
        "targetX",
        "targetY"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'gameStarted'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'clearCurrentMap'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'mapLoaded'
        QtMocHelpers::SignalData<void(Map *)>(4, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 5, 6 },
        }}),
        // Signal 'foundItemSnapableTile'
        QtMocHelpers::SignalData<void(ItemSnapable *)>(7, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 8, 9 },
        }}),
        // Signal 'tileRemoved'
        QtMocHelpers::SignalData<void(QUuid)>(10, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 11, 12 },
        }}),
        // Signal 'forceUnselectAll'
        QtMocHelpers::SignalData<void()>(13, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'afterRestoration'
        QtMocHelpers::SignalData<void(const QList<QUuid> &)>(14, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 15, 16 },
        }}),
        // Method 'startGame'
        QtMocHelpers::MethodData<void()>(17, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'saveCurrentMap'
        QtMocHelpers::MethodData<bool()>(18, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'saveMap'
        QtMocHelpers::MethodData<bool(MapInfo *, QVariantList, MapTypes::MapType)>(19, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { 0x80000000 | 20, 21 }, { 0x80000000 | 22, 23 }, { 0x80000000 | 24, 25 },
        }}),
        // Method 'deleteMap'
        QtMocHelpers::MethodData<bool(QString, MapTypes::MapType)>(26, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 27 }, { 0x80000000 | 24, 25 },
        }}),
        // Method 'loadMap'
        QtMocHelpers::MethodData<Map *(QString, MapTypes::MapType)>(28, 2, QMC::AccessPublic, 0x80000000 | 5, {{
            { QMetaType::QString, 27 }, { 0x80000000 | 24, 25 },
        }}),
        // Method 'generateItems'
        QtMocHelpers::MethodData<QList<ItemSnapable*>(QJsonObject)>(29, 2, QMC::AccessPublic, 0x80000000 | 30, {{
            { 0x80000000 | 31, 32 },
        }}),
        // Method 'askPreview'
        QtMocHelpers::MethodData<void()>(33, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'askNext'
        QtMocHelpers::MethodData<void()>(34, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'updateMap'
        QtMocHelpers::MethodData<void(int, ItemSnapable *, QUuid)>(35, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 36 }, { 0x80000000 | 8, 37 }, { 0x80000000 | 11, 38 },
        }}),
        // Method 'updateMap'
        QtMocHelpers::MethodData<void(int, ItemSnapable *)>(35, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::Int, 36 }, { 0x80000000 | 8, 37 },
        }}),
        // Method 'updateMapMetadata'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(39, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 40 }, { QMetaType::QString, 41 },
        }}),
        // Method 'beginTransaction'
        QtMocHelpers::MethodData<QUuid()>(42, 2, QMC::AccessPublic, 0x80000000 | 11),
        // Method 'commitTransaction'
        QtMocHelpers::MethodData<void()>(43, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'finalizeDeletedTile'
        QtMocHelpers::MethodData<void(const QUuid &)>(44, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 11, 12 },
        }}),
        // Method 'applyRemoteDelta'
        QtMocHelpers::MethodData<void(int, const QString &, const QString &, const QJsonObject &, const QJsonObject &, bool)>(45, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 36 }, { QMetaType::QString, 12 }, { QMetaType::QString, 38 }, { 0x80000000 | 31, 46 },
            { 0x80000000 | 31, 47 }, { QMetaType::Bool, 48 },
        }}),
        // Method 'initEmptyCollabMap'
        QtMocHelpers::MethodData<void()>(49, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'saveTemplate'
        QtMocHelpers::MethodData<bool(QString, QJsonArray)>(50, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 51 }, { 0x80000000 | 52, 53 },
        }}),
        // Method 'deleteTemplate'
        QtMocHelpers::MethodData<bool(QString)>(54, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 51 },
        }}),
        // Method 'loadTemplate'
        QtMocHelpers::MethodData<QJsonObject(QString)>(55, 2, QMC::AccessPublic, 0x80000000 | 31, {{
            { QMetaType::QString, 51 },
        }}),
        // Method 'getTemplateElementsForPlacement'
        QtMocHelpers::MethodData<QJsonArray(QString, int, int)>(56, 2, QMC::AccessPublic, 0x80000000 | 52, {{
            { QMetaType::QString, 51 }, { QMetaType::Int, 57 }, { QMetaType::Int, 58 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<Game, qt_meta_tag_ZN4GameE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject Game::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4GameE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4GameE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN4GameE_t>.metaTypes,
    nullptr
} };

void Game::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<Game *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->gameStarted(); break;
        case 1: _t->clearCurrentMap(); break;
        case 2: _t->mapLoaded((*reinterpret_cast<std::add_pointer_t<Map*>>(_a[1]))); break;
        case 3: _t->foundItemSnapableTile((*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[1]))); break;
        case 4: _t->tileRemoved((*reinterpret_cast<std::add_pointer_t<QUuid>>(_a[1]))); break;
        case 5: _t->forceUnselectAll(); break;
        case 6: _t->afterRestoration((*reinterpret_cast<std::add_pointer_t<QList<QUuid>>>(_a[1]))); break;
        case 7: _t->startGame(); break;
        case 8: { bool _r = _t->saveCurrentMap();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 9: { bool _r = _t->saveMap((*reinterpret_cast<std::add_pointer_t<MapInfo*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QVariantList>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<MapTypes::MapType>>(_a[3])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 10: { bool _r = _t->deleteMap((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<MapTypes::MapType>>(_a[2])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 11: { Map* _r = _t->loadMap((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<MapTypes::MapType>>(_a[2])));
            if (_a[0]) *reinterpret_cast<Map**>(_a[0]) = std::move(_r); }  break;
        case 12: { QList<ItemSnapable*> _r = _t->generateItems((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QList<ItemSnapable*>*>(_a[0]) = std::move(_r); }  break;
        case 13: _t->askPreview(); break;
        case 14: _t->askNext(); break;
        case 15: _t->updateMap((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QUuid>>(_a[3]))); break;
        case 16: _t->updateMap((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[2]))); break;
        case 17: _t->updateMapMetadata((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 18: { QUuid _r = _t->beginTransaction();
            if (_a[0]) *reinterpret_cast<QUuid*>(_a[0]) = std::move(_r); }  break;
        case 19: _t->commitTransaction(); break;
        case 20: _t->finalizeDeletedTile((*reinterpret_cast<std::add_pointer_t<QUuid>>(_a[1]))); break;
        case 21: _t->applyRemoteDelta((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<bool>>(_a[6]))); break;
        case 22: _t->initEmptyCollabMap(); break;
        case 23: { bool _r = _t->saveTemplate((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonArray>>(_a[2])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 24: { bool _r = _t->deleteTemplate((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 25: { QJsonObject _r = _t->loadTemplate((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QJsonObject*>(_a[0]) = std::move(_r); }  break;
        case 26: { QJsonArray _r = _t->getTemplateElementsForPlacement((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QJsonArray*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 2:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< Map* >(); break;
            }
            break;
        case 3:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        case 9:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< MapInfo* >(); break;
            }
            break;
        case 15:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 1:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        case 16:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 1:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< ItemSnapable* >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (Game::*)()>(_a, &Game::gameStarted, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)()>(_a, &Game::clearCurrentMap, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)(Map * )>(_a, &Game::mapLoaded, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)(ItemSnapable * )>(_a, &Game::foundItemSnapableTile, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)(QUuid )>(_a, &Game::tileRemoved, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)()>(_a, &Game::forceUnselectAll, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)(const QList<QUuid> & )>(_a, &Game::afterRestoration, 6))
            return;
    }
}

const QMetaObject *Game::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *Game::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4GameE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int Game::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 27)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 27;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 27)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 27;
    }
    return _id;
}

// SIGNAL 0
void Game::gameStarted()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void Game::clearCurrentMap()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void Game::mapLoaded(Map * _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 2, nullptr, _t1);
}

// SIGNAL 3
void Game::foundItemSnapableTile(ItemSnapable * _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 3, nullptr, _t1);
}

// SIGNAL 4
void Game::tileRemoved(QUuid _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 4, nullptr, _t1);
}

// SIGNAL 5
void Game::forceUnselectAll()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void Game::afterRestoration(const QList<QUuid> & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 6, nullptr, _t1);
}
QT_WARNING_POP
