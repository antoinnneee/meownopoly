/****************************************************************************
** Meta object code from reading C++ file 'ZoneParameter.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/item_snapable/ZoneParameter.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'ZoneParameter.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN13ZoneParameterE_t {};
} // unnamed namespace

template <> constexpr inline auto ZoneParameter::qt_create_metaobjectdata<qt_meta_tag_ZN13ZoneParameterE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "ZoneParameter",
        "polygonPointsChanged",
        "",
        "zoneColorChanged",
        "zoneNameChanged",
        "velocityDirectionChanged",
        "velocityStrenghtChanged",
        "frictionStrenghtChanged",
        "exclusionChanged",
        "speedMultiplierChanged",
        "accelerationMultiplierChanged",
        "addPoint",
        "x",
        "y",
        "removeLastPoint",
        "clearPoints",
        "pointCount",
        "zoneColor",
        "zoneName",
        "polygonPoints",
        "QVariantList",
        "velocityDirection",
        "QVector2D",
        "velocityStrenght",
        "frictionStrenght",
        "speedMultiplier",
        "exclusion",
        "accelerationMultiplier"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'polygonPointsChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'zoneColorChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'zoneNameChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'velocityDirectionChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'velocityStrenghtChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'frictionStrenghtChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'exclusionChanged'
        QtMocHelpers::SignalData<void()>(8, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'speedMultiplierChanged'
        QtMocHelpers::SignalData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'accelerationMultiplierChanged'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'addPoint'
        QtMocHelpers::MethodData<void(qreal, qreal)>(11, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QReal, 12 }, { QMetaType::QReal, 13 },
        }}),
        // Method 'removeLastPoint'
        QtMocHelpers::MethodData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'clearPoints'
        QtMocHelpers::MethodData<void()>(15, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'pointCount'
        QtMocHelpers::MethodData<int() const>(16, 2, QMC::AccessPublic, QMetaType::Int),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'zoneColor'
        QtMocHelpers::PropertyData<QString>(17, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'zoneName'
        QtMocHelpers::PropertyData<QString>(18, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'polygonPoints'
        QtMocHelpers::PropertyData<QVariantList>(19, 0x80000000 | 20, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet, 0),
        // property 'velocityDirection'
        QtMocHelpers::PropertyData<QVector2D>(21, 0x80000000 | 22, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 3),
        // property 'velocityStrenght'
        QtMocHelpers::PropertyData<qreal>(23, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 4),
        // property 'frictionStrenght'
        QtMocHelpers::PropertyData<qreal>(24, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 5),
        // property 'speedMultiplier'
        QtMocHelpers::PropertyData<qreal>(25, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 7),
        // property 'exclusion'
        QtMocHelpers::PropertyData<bool>(26, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 6),
        // property 'accelerationMultiplier'
        QtMocHelpers::PropertyData<qreal>(27, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 8),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<ZoneParameter, qt_meta_tag_ZN13ZoneParameterE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject ZoneParameter::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13ZoneParameterE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13ZoneParameterE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN13ZoneParameterE_t>.metaTypes,
    nullptr
} };

void ZoneParameter::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<ZoneParameter *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->polygonPointsChanged(); break;
        case 1: _t->zoneColorChanged(); break;
        case 2: _t->zoneNameChanged(); break;
        case 3: _t->velocityDirectionChanged(); break;
        case 4: _t->velocityStrenghtChanged(); break;
        case 5: _t->frictionStrenghtChanged(); break;
        case 6: _t->exclusionChanged(); break;
        case 7: _t->speedMultiplierChanged(); break;
        case 8: _t->accelerationMultiplierChanged(); break;
        case 9: _t->addPoint((*reinterpret_cast<std::add_pointer_t<qreal>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2]))); break;
        case 10: _t->removeLastPoint(); break;
        case 11: _t->clearPoints(); break;
        case 12: { int _r = _t->pointCount();
            if (_a[0]) *reinterpret_cast<int*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (ZoneParameter::*)()>(_a, &ZoneParameter::polygonPointsChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (ZoneParameter::*)()>(_a, &ZoneParameter::zoneColorChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (ZoneParameter::*)()>(_a, &ZoneParameter::zoneNameChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (ZoneParameter::*)()>(_a, &ZoneParameter::velocityDirectionChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (ZoneParameter::*)()>(_a, &ZoneParameter::velocityStrenghtChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (ZoneParameter::*)()>(_a, &ZoneParameter::frictionStrenghtChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (ZoneParameter::*)()>(_a, &ZoneParameter::exclusionChanged, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (ZoneParameter::*)()>(_a, &ZoneParameter::speedMultiplierChanged, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (ZoneParameter::*)()>(_a, &ZoneParameter::accelerationMultiplierChanged, 8))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->zoneColor(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->zoneName(); break;
        case 2: *reinterpret_cast<QVariantList*>(_v) = _t->polygonPoints(); break;
        case 3: *reinterpret_cast<QVector2D*>(_v) = _t->velocityDirection(); break;
        case 4: *reinterpret_cast<qreal*>(_v) = _t->velocityStrenght(); break;
        case 5: *reinterpret_cast<qreal*>(_v) = _t->frictionStrenght(); break;
        case 6: *reinterpret_cast<qreal*>(_v) = _t->speedMultiplier(); break;
        case 7: *reinterpret_cast<bool*>(_v) = _t->exclusion(); break;
        case 8: *reinterpret_cast<qreal*>(_v) = _t->accelerationMultiplier(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setZoneColor(*reinterpret_cast<QString*>(_v)); break;
        case 1: _t->setZoneName(*reinterpret_cast<QString*>(_v)); break;
        case 2: _t->setPolygonPoints(*reinterpret_cast<QVariantList*>(_v)); break;
        case 3: _t->setVelocityDirection(*reinterpret_cast<QVector2D*>(_v)); break;
        case 4: _t->setVelocityStrenght(*reinterpret_cast<qreal*>(_v)); break;
        case 5: _t->setFrictionStrenght(*reinterpret_cast<qreal*>(_v)); break;
        case 6: _t->setSpeedMultiplier(*reinterpret_cast<qreal*>(_v)); break;
        case 7: _t->setExclusion(*reinterpret_cast<bool*>(_v)); break;
        case 8: _t->setAccelerationMultiplier(*reinterpret_cast<qreal*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *ZoneParameter::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *ZoneParameter::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13ZoneParameterE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int ZoneParameter::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 13)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 13;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 13)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 13;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 9;
    }
    return _id;
}

// SIGNAL 0
void ZoneParameter::polygonPointsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void ZoneParameter::zoneColorChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void ZoneParameter::zoneNameChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void ZoneParameter::velocityDirectionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void ZoneParameter::velocityStrenghtChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void ZoneParameter::frictionStrenghtChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void ZoneParameter::exclusionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void ZoneParameter::speedMultiplierChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void ZoneParameter::accelerationMultiplierChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}
QT_WARNING_POP
