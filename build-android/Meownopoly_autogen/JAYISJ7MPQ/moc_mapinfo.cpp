/****************************************************************************
** Meta object code from reading C++ file 'mapinfo.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/map/mapinfo.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'mapinfo.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN7MapInfoE_t {};
} // unnamed namespace

template <> constexpr inline auto MapInfo::qt_create_metaobjectdata<qt_meta_tag_ZN7MapInfoE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "MapInfo",
        "mapNameChanged",
        "",
        "mapName",
        "mapDescriptionChanged",
        "mapDescription",
        "mapLastModifiedChanged",
        "mapLastModified",
        "versionChanged",
        "version",
        "mapCreationDateChanged",
        "musicPathChanged",
        "backgroundPathChanged",
        "backgroundScalingChanged",
        "isBackgroundOnGrillChanged",
        "backgroundTileSizeChanged",
        "toJSON",
        "mapCreationDate",
        "musicPath",
        "backgroundPath",
        "backgroundScaling",
        "isBackgroundOnGrill",
        "backgroundTileSize",
        "autosaveMapName"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'mapNameChanged'
        QtMocHelpers::SignalData<void(const QString &)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 3 },
        }}),
        // Signal 'mapDescriptionChanged'
        QtMocHelpers::SignalData<void(const QString &)>(4, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 5 },
        }}),
        // Signal 'mapLastModifiedChanged'
        QtMocHelpers::SignalData<void(const QString &)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 7 },
        }}),
        // Signal 'versionChanged'
        QtMocHelpers::SignalData<void(int)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 9 },
        }}),
        // Signal 'mapCreationDateChanged'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'musicPathChanged'
        QtMocHelpers::SignalData<void()>(11, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'backgroundPathChanged'
        QtMocHelpers::SignalData<void()>(12, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'backgroundScalingChanged'
        QtMocHelpers::SignalData<void()>(13, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isBackgroundOnGrillChanged'
        QtMocHelpers::SignalData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'backgroundTileSizeChanged'
        QtMocHelpers::SignalData<void()>(15, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'toJSON'
        QtMocHelpers::MethodData<QString()>(16, 2, QMC::AccessPublic, QMetaType::QString),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'mapName'
        QtMocHelpers::PropertyData<QString>(3, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 0),
        // property 'mapDescription'
        QtMocHelpers::PropertyData<QString>(5, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'mapCreationDate'
        QtMocHelpers::PropertyData<QString>(17, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 4),
        // property 'mapLastModified'
        QtMocHelpers::PropertyData<QString>(7, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'version'
        QtMocHelpers::PropertyData<int>(9, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'musicPath'
        QtMocHelpers::PropertyData<QString>(18, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 5),
        // property 'backgroundPath'
        QtMocHelpers::PropertyData<QString>(19, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 6),
        // property 'backgroundScaling'
        QtMocHelpers::PropertyData<QString>(20, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 7),
        // property 'isBackgroundOnGrill'
        QtMocHelpers::PropertyData<bool>(21, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 8),
        // property 'backgroundTileSize'
        QtMocHelpers::PropertyData<int>(22, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 9),
        // property 'autosaveMapName'
        QtMocHelpers::PropertyData<QString>(23, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<MapInfo, qt_meta_tag_ZN7MapInfoE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject MapInfo::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN7MapInfoE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN7MapInfoE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN7MapInfoE_t>.metaTypes,
    nullptr
} };

void MapInfo::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<MapInfo *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->mapNameChanged((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 1: _t->mapDescriptionChanged((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 2: _t->mapLastModifiedChanged((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 3: _t->versionChanged((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 4: _t->mapCreationDateChanged(); break;
        case 5: _t->musicPathChanged(); break;
        case 6: _t->backgroundPathChanged(); break;
        case 7: _t->backgroundScalingChanged(); break;
        case 8: _t->isBackgroundOnGrillChanged(); break;
        case 9: _t->backgroundTileSizeChanged(); break;
        case 10: { QString _r = _t->toJSON();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)(const QString & )>(_a, &MapInfo::mapNameChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)(const QString & )>(_a, &MapInfo::mapDescriptionChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)(const QString & )>(_a, &MapInfo::mapLastModifiedChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)(int )>(_a, &MapInfo::versionChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)()>(_a, &MapInfo::mapCreationDateChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)()>(_a, &MapInfo::musicPathChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)()>(_a, &MapInfo::backgroundPathChanged, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)()>(_a, &MapInfo::backgroundScalingChanged, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)()>(_a, &MapInfo::isBackgroundOnGrillChanged, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (MapInfo::*)()>(_a, &MapInfo::backgroundTileSizeChanged, 9))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->getMapName(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->getMapDescription(); break;
        case 2: *reinterpret_cast<QString*>(_v) = _t->mapCreationDate(); break;
        case 3: *reinterpret_cast<QString*>(_v) = _t->getMapLastModified(); break;
        case 4: *reinterpret_cast<int*>(_v) = _t->getVersion(); break;
        case 5: *reinterpret_cast<QString*>(_v) = _t->getMusicPath(); break;
        case 6: *reinterpret_cast<QString*>(_v) = _t->getBackgroundPath(); break;
        case 7: *reinterpret_cast<QString*>(_v) = _t->getBackgroundScaling(); break;
        case 8: *reinterpret_cast<bool*>(_v) = _t->getIsBackgroundOnGrill(); break;
        case 9: *reinterpret_cast<int*>(_v) = _t->getBackgroundTileSize(); break;
        case 10: *reinterpret_cast<QString*>(_v) = _t->autosaveMapName(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setMapName(*reinterpret_cast<QString*>(_v)); break;
        case 1: _t->setMapDescription(*reinterpret_cast<QString*>(_v)); break;
        case 2: _t->setMapCreationDate(*reinterpret_cast<QString*>(_v)); break;
        case 3: _t->setMapLastModified(*reinterpret_cast<QString*>(_v)); break;
        case 4: _t->setVersion(*reinterpret_cast<int*>(_v)); break;
        case 5: _t->setMusicPath(*reinterpret_cast<QString*>(_v)); break;
        case 6: _t->setBackgroundPath(*reinterpret_cast<QString*>(_v)); break;
        case 7: _t->setBackgroundScaling(*reinterpret_cast<QString*>(_v)); break;
        case 8: _t->setIsBackgroundOnGrill(*reinterpret_cast<bool*>(_v)); break;
        case 9: _t->setBackgroundTileSize(*reinterpret_cast<int*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *MapInfo::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *MapInfo::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN7MapInfoE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int MapInfo::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
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
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 11;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 11;
    }
    return _id;
}

// SIGNAL 0
void MapInfo::mapNameChanged(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void MapInfo::mapDescriptionChanged(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1);
}

// SIGNAL 2
void MapInfo::mapLastModifiedChanged(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 2, nullptr, _t1);
}

// SIGNAL 3
void MapInfo::versionChanged(int _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 3, nullptr, _t1);
}

// SIGNAL 4
void MapInfo::mapCreationDateChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void MapInfo::musicPathChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void MapInfo::backgroundPathChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void MapInfo::backgroundScalingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void MapInfo::isBackgroundOnGrillChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}

// SIGNAL 9
void MapInfo::backgroundTileSizeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}
QT_WARNING_POP
