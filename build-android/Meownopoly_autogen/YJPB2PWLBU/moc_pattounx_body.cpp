/****************************************************************************
** Meta object code from reading C++ file 'pattounx_body.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/physics/pattounx_body.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'pattounx_body.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN13PattounX_bodyE_t {};
} // unnamed namespace

template <> constexpr inline auto PattounX_body::qt_create_metaobjectdata<qt_meta_tag_ZN13PattounX_bodyE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "PattounX_body",
        "positionChanged",
        "",
        "velocityChanged",
        "collisionRadiusChanged",
        "bounceFactorChanged",
        "slideFactorChanged",
        "accelerationChanged",
        "maxSpeedChanged",
        "massChanged",
        "isStaticChanged",
        "collisionEnabledChanged",
        "isCollidingChanged",
        "lastCollisionNormalChanged",
        "collisionOccurred",
        "PattounX_zone*",
        "zone",
        "enteredZone",
        "exitedZone",
        "inputVectorChanged",
        "isSleepingChanged",
        "invMassChanged",
        "restitutionChanged",
        "staticFrictionChanged",
        "dynamicFrictionChanged",
        "linearDampingChanged",
        "applyForce",
        "QVector2D",
        "inputVector",
        "inputForce",
        "applyImpulse",
        "impulse",
        "stop",
        "reset",
        "bodyId",
        "position",
        "velocity",
        "collisionRadius",
        "bounceFactor",
        "slideFactor",
        "acceleration",
        "maxSpeed",
        "mass",
        "invMass",
        "restitution",
        "staticFriction",
        "dynamicFriction",
        "linearDamping",
        "isStatic",
        "collisionEnabled",
        "isColliding",
        "lastCollisionNormal",
        "isSleeping"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'positionChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'velocityChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'collisionRadiusChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'bounceFactorChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'slideFactorChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'accelerationChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'maxSpeedChanged'
        QtMocHelpers::SignalData<void()>(8, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'massChanged'
        QtMocHelpers::SignalData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isStaticChanged'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'collisionEnabledChanged'
        QtMocHelpers::SignalData<void()>(11, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isCollidingChanged'
        QtMocHelpers::SignalData<void()>(12, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'lastCollisionNormalChanged'
        QtMocHelpers::SignalData<void()>(13, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'collisionOccurred'
        QtMocHelpers::SignalData<void(PattounX_zone *)>(14, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 15, 16 },
        }}),
        // Signal 'enteredZone'
        QtMocHelpers::SignalData<void(PattounX_zone *)>(17, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 15, 16 },
        }}),
        // Signal 'exitedZone'
        QtMocHelpers::SignalData<void(PattounX_zone *)>(18, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 15, 16 },
        }}),
        // Signal 'inputVectorChanged'
        QtMocHelpers::SignalData<void()>(19, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isSleepingChanged'
        QtMocHelpers::SignalData<void()>(20, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'invMassChanged'
        QtMocHelpers::SignalData<void()>(21, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'restitutionChanged'
        QtMocHelpers::SignalData<void()>(22, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'staticFrictionChanged'
        QtMocHelpers::SignalData<void()>(23, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'dynamicFrictionChanged'
        QtMocHelpers::SignalData<void()>(24, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'linearDampingChanged'
        QtMocHelpers::SignalData<void()>(25, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'applyForce'
        QtMocHelpers::MethodData<void(const QVector2D &, qreal)>(26, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 27, 28 }, { QMetaType::QReal, 29 },
        }}),
        // Method 'applyForce'
        QtMocHelpers::MethodData<void(const QVector2D &)>(26, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 27, 28 },
        }}),
        // Method 'applyImpulse'
        QtMocHelpers::MethodData<void(const QVector2D &)>(30, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 27, 31 },
        }}),
        // Method 'stop'
        QtMocHelpers::MethodData<void()>(32, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'reset'
        QtMocHelpers::MethodData<void()>(33, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'bodyId'
        QtMocHelpers::PropertyData<QString>(34, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Constant),
        // property 'position'
        QtMocHelpers::PropertyData<QVector2D>(35, 0x80000000 | 27, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet, 0),
        // property 'velocity'
        QtMocHelpers::PropertyData<QVector2D>(36, 0x80000000 | 27, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet, 1),
        // property 'collisionRadius'
        QtMocHelpers::PropertyData<qreal>(37, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'bounceFactor'
        QtMocHelpers::PropertyData<qreal>(38, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'slideFactor'
        QtMocHelpers::PropertyData<qreal>(39, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 4),
        // property 'acceleration'
        QtMocHelpers::PropertyData<qreal>(40, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 5),
        // property 'maxSpeed'
        QtMocHelpers::PropertyData<qreal>(41, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 6),
        // property 'mass'
        QtMocHelpers::PropertyData<qreal>(42, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 7),
        // property 'invMass'
        QtMocHelpers::PropertyData<qreal>(43, QMetaType::QReal, QMC::DefaultPropertyFlags, 17),
        // property 'restitution'
        QtMocHelpers::PropertyData<qreal>(44, QMetaType::QReal, QMC::DefaultPropertyFlags, 18),
        // property 'staticFriction'
        QtMocHelpers::PropertyData<qreal>(45, QMetaType::QReal, QMC::DefaultPropertyFlags, 19),
        // property 'dynamicFriction'
        QtMocHelpers::PropertyData<qreal>(46, QMetaType::QReal, QMC::DefaultPropertyFlags, 20),
        // property 'linearDamping'
        QtMocHelpers::PropertyData<qreal>(47, QMetaType::QReal, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 21),
        // property 'isStatic'
        QtMocHelpers::PropertyData<bool>(48, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 8),
        // property 'collisionEnabled'
        QtMocHelpers::PropertyData<bool>(49, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 9),
        // property 'isColliding'
        QtMocHelpers::PropertyData<bool>(50, QMetaType::Bool, QMC::DefaultPropertyFlags, 10),
        // property 'lastCollisionNormal'
        QtMocHelpers::PropertyData<QVector2D>(51, 0x80000000 | 27, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 11),
        // property 'inputVector'
        QtMocHelpers::PropertyData<QVector2D>(28, 0x80000000 | 27, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet, 15),
        // property 'isSleeping'
        QtMocHelpers::PropertyData<bool>(52, QMetaType::Bool, QMC::DefaultPropertyFlags, 16),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<PattounX_body, qt_meta_tag_ZN13PattounX_bodyE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject PattounX_body::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13PattounX_bodyE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13PattounX_bodyE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN13PattounX_bodyE_t>.metaTypes,
    nullptr
} };

void PattounX_body::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<PattounX_body *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->positionChanged(); break;
        case 1: _t->velocityChanged(); break;
        case 2: _t->collisionRadiusChanged(); break;
        case 3: _t->bounceFactorChanged(); break;
        case 4: _t->slideFactorChanged(); break;
        case 5: _t->accelerationChanged(); break;
        case 6: _t->maxSpeedChanged(); break;
        case 7: _t->massChanged(); break;
        case 8: _t->isStaticChanged(); break;
        case 9: _t->collisionEnabledChanged(); break;
        case 10: _t->isCollidingChanged(); break;
        case 11: _t->lastCollisionNormalChanged(); break;
        case 12: _t->collisionOccurred((*reinterpret_cast<std::add_pointer_t<PattounX_zone*>>(_a[1]))); break;
        case 13: _t->enteredZone((*reinterpret_cast<std::add_pointer_t<PattounX_zone*>>(_a[1]))); break;
        case 14: _t->exitedZone((*reinterpret_cast<std::add_pointer_t<PattounX_zone*>>(_a[1]))); break;
        case 15: _t->inputVectorChanged(); break;
        case 16: _t->isSleepingChanged(); break;
        case 17: _t->invMassChanged(); break;
        case 18: _t->restitutionChanged(); break;
        case 19: _t->staticFrictionChanged(); break;
        case 20: _t->dynamicFrictionChanged(); break;
        case 21: _t->linearDampingChanged(); break;
        case 22: _t->applyForce((*reinterpret_cast<std::add_pointer_t<QVector2D>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2]))); break;
        case 23: _t->applyForce((*reinterpret_cast<std::add_pointer_t<QVector2D>>(_a[1]))); break;
        case 24: _t->applyImpulse((*reinterpret_cast<std::add_pointer_t<QVector2D>>(_a[1]))); break;
        case 25: _t->stop(); break;
        case 26: _t->reset(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::positionChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::velocityChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::collisionRadiusChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::bounceFactorChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::slideFactorChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::accelerationChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::maxSpeedChanged, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::massChanged, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::isStaticChanged, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::collisionEnabledChanged, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::isCollidingChanged, 10))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::lastCollisionNormalChanged, 11))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)(PattounX_zone * )>(_a, &PattounX_body::collisionOccurred, 12))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)(PattounX_zone * )>(_a, &PattounX_body::enteredZone, 13))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)(PattounX_zone * )>(_a, &PattounX_body::exitedZone, 14))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::inputVectorChanged, 15))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::isSleepingChanged, 16))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::invMassChanged, 17))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::restitutionChanged, 18))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::staticFrictionChanged, 19))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::dynamicFrictionChanged, 20))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_body::*)()>(_a, &PattounX_body::linearDampingChanged, 21))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->bodyId(); break;
        case 1: *reinterpret_cast<QVector2D*>(_v) = _t->position(); break;
        case 2: *reinterpret_cast<QVector2D*>(_v) = _t->velocity(); break;
        case 3: *reinterpret_cast<qreal*>(_v) = _t->collisionRadius(); break;
        case 4: *reinterpret_cast<qreal*>(_v) = _t->bounceFactor(); break;
        case 5: *reinterpret_cast<qreal*>(_v) = _t->slideFactor(); break;
        case 6: *reinterpret_cast<qreal*>(_v) = _t->acceleration(); break;
        case 7: *reinterpret_cast<qreal*>(_v) = _t->maxSpeed(); break;
        case 8: *reinterpret_cast<qreal*>(_v) = _t->mass(); break;
        case 9: *reinterpret_cast<qreal*>(_v) = _t->invMass(); break;
        case 10: *reinterpret_cast<qreal*>(_v) = _t->restitution(); break;
        case 11: *reinterpret_cast<qreal*>(_v) = _t->staticFriction(); break;
        case 12: *reinterpret_cast<qreal*>(_v) = _t->dynamicFriction(); break;
        case 13: *reinterpret_cast<qreal*>(_v) = _t->linearDamping(); break;
        case 14: *reinterpret_cast<bool*>(_v) = _t->isStatic(); break;
        case 15: *reinterpret_cast<bool*>(_v) = _t->collisionEnabled(); break;
        case 16: *reinterpret_cast<bool*>(_v) = _t->isColliding(); break;
        case 17: *reinterpret_cast<QVector2D*>(_v) = _t->lastCollisionNormal(); break;
        case 18: *reinterpret_cast<QVector2D*>(_v) = _t->inputVector(); break;
        case 19: *reinterpret_cast<bool*>(_v) = _t->isSleeping(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 1: _t->setPosition(*reinterpret_cast<QVector2D*>(_v)); break;
        case 2: _t->setVelocity(*reinterpret_cast<QVector2D*>(_v)); break;
        case 3: _t->setCollisionRadius(*reinterpret_cast<qreal*>(_v)); break;
        case 4: _t->setBounceFactor(*reinterpret_cast<qreal*>(_v)); break;
        case 5: _t->setSlideFactor(*reinterpret_cast<qreal*>(_v)); break;
        case 6: _t->setAcceleration(*reinterpret_cast<qreal*>(_v)); break;
        case 7: _t->setMaxSpeed(*reinterpret_cast<qreal*>(_v)); break;
        case 8: _t->setMass(*reinterpret_cast<qreal*>(_v)); break;
        case 13: _t->setLinearDamping(*reinterpret_cast<qreal*>(_v)); break;
        case 14: _t->setIsStatic(*reinterpret_cast<bool*>(_v)); break;
        case 15: _t->setCollisionEnabled(*reinterpret_cast<bool*>(_v)); break;
        case 18: _t->setInputVector(*reinterpret_cast<QVector2D*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *PattounX_body::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *PattounX_body::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13PattounX_bodyE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int PattounX_body::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
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
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 27;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 20;
    }
    return _id;
}

// SIGNAL 0
void PattounX_body::positionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void PattounX_body::velocityChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void PattounX_body::collisionRadiusChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void PattounX_body::bounceFactorChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void PattounX_body::slideFactorChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void PattounX_body::accelerationChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void PattounX_body::maxSpeedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void PattounX_body::massChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 7, nullptr);
}

// SIGNAL 8
void PattounX_body::isStaticChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}

// SIGNAL 9
void PattounX_body::collisionEnabledChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}

// SIGNAL 10
void PattounX_body::isCollidingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 10, nullptr);
}

// SIGNAL 11
void PattounX_body::lastCollisionNormalChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 11, nullptr);
}

// SIGNAL 12
void PattounX_body::collisionOccurred(PattounX_zone * _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 12, nullptr, _t1);
}

// SIGNAL 13
void PattounX_body::enteredZone(PattounX_zone * _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 13, nullptr, _t1);
}

// SIGNAL 14
void PattounX_body::exitedZone(PattounX_zone * _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 14, nullptr, _t1);
}

// SIGNAL 15
void PattounX_body::inputVectorChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 15, nullptr);
}

// SIGNAL 16
void PattounX_body::isSleepingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 16, nullptr);
}

// SIGNAL 17
void PattounX_body::invMassChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 17, nullptr);
}

// SIGNAL 18
void PattounX_body::restitutionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 18, nullptr);
}

// SIGNAL 19
void PattounX_body::staticFrictionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 19, nullptr);
}

// SIGNAL 20
void PattounX_body::dynamicFrictionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 20, nullptr);
}

// SIGNAL 21
void PattounX_body::linearDampingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 21, nullptr);
}
QT_WARNING_POP
