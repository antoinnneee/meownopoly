/****************************************************************************
** Meta object code from reading C++ file 'pattounx_engine.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/physics/pattounx_engine.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'pattounx_engine.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN15PattounX_engineE_t {};
} // unnamed namespace

template <> constexpr inline auto PattounX_engine::qt_create_metaobjectdata<qt_meta_tag_ZN15PattounX_engineE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "PattounX_engine",
        "bodyCountChanged",
        "",
        "zoneCountChanged",
        "enabledChanged",
        "debugModeChanged",
        "bodyCollided",
        "PattounX_body*",
        "body",
        "PattounX_zone*",
        "zone",
        "bodyEnteredZone",
        "bodyExitedZone",
        "createBody",
        "id",
        "removeBody",
        "getBody",
        "clearBodies",
        "createZone",
        "ItemSnapable*",
        "snapable",
        "removeZone",
        "getZone",
        "clearZones",
        "setZonesFromSnapables",
        "QVariantList",
        "snapables",
        "updateAll",
        "dt",
        "updateBody",
        "getZonesAtPoint",
        "QVector2D",
        "point",
        "bodyCount",
        "zoneCount",
        "enabled",
        "debugMode"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'bodyCountChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'zoneCountChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'enabledChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'debugModeChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'bodyCollided'
        QtMocHelpers::SignalData<void(PattounX_body *, PattounX_zone *)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 7, 8 }, { 0x80000000 | 9, 10 },
        }}),
        // Signal 'bodyEnteredZone'
        QtMocHelpers::SignalData<void(PattounX_body *, PattounX_zone *)>(11, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 7, 8 }, { 0x80000000 | 9, 10 },
        }}),
        // Signal 'bodyExitedZone'
        QtMocHelpers::SignalData<void(PattounX_body *, PattounX_zone *)>(12, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 7, 8 }, { 0x80000000 | 9, 10 },
        }}),
        // Method 'createBody'
        QtMocHelpers::MethodData<PattounX_body *(const QString &)>(13, 2, QMC::AccessPublic, 0x80000000 | 7, {{
            { QMetaType::QString, 14 },
        }}),
        // Method 'removeBody'
        QtMocHelpers::MethodData<bool(const QString &)>(15, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 14 },
        }}),
        // Method 'getBody'
        QtMocHelpers::MethodData<PattounX_body *(const QString &) const>(16, 2, QMC::AccessPublic, 0x80000000 | 7, {{
            { QMetaType::QString, 14 },
        }}),
        // Method 'clearBodies'
        QtMocHelpers::MethodData<void()>(17, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'createZone'
        QtMocHelpers::MethodData<PattounX_zone *(ItemSnapable *)>(18, 2, QMC::AccessPublic, 0x80000000 | 9, {{
            { 0x80000000 | 19, 20 },
        }}),
        // Method 'removeZone'
        QtMocHelpers::MethodData<bool(const QString &)>(21, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 14 },
        }}),
        // Method 'getZone'
        QtMocHelpers::MethodData<PattounX_zone *(const QString &) const>(22, 2, QMC::AccessPublic, 0x80000000 | 9, {{
            { QMetaType::QString, 14 },
        }}),
        // Method 'clearZones'
        QtMocHelpers::MethodData<void()>(23, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'setZonesFromSnapables'
        QtMocHelpers::MethodData<void(const QVariantList &)>(24, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 25, 26 },
        }}),
        // Method 'updateAll'
        QtMocHelpers::MethodData<void(qreal)>(27, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QReal, 28 },
        }}),
        // Method 'updateBody'
        QtMocHelpers::MethodData<void(PattounX_body *, qreal)>(29, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 7, 8 }, { QMetaType::QReal, 28 },
        }}),
        // Method 'getZonesAtPoint'
        QtMocHelpers::MethodData<QVariantList(const QVector2D &) const>(30, 2, QMC::AccessPublic, 0x80000000 | 25, {{
            { 0x80000000 | 31, 32 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'bodyCount'
        QtMocHelpers::PropertyData<int>(33, QMetaType::Int, QMC::DefaultPropertyFlags, 0),
        // property 'zoneCount'
        QtMocHelpers::PropertyData<int>(34, QMetaType::Int, QMC::DefaultPropertyFlags, 1),
        // property 'enabled'
        QtMocHelpers::PropertyData<bool>(35, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'debugMode'
        QtMocHelpers::PropertyData<bool>(36, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<PattounX_engine, qt_meta_tag_ZN15PattounX_engineE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject PattounX_engine::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15PattounX_engineE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15PattounX_engineE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN15PattounX_engineE_t>.metaTypes,
    nullptr
} };

void PattounX_engine::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<PattounX_engine *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->bodyCountChanged(); break;
        case 1: _t->zoneCountChanged(); break;
        case 2: _t->enabledChanged(); break;
        case 3: _t->debugModeChanged(); break;
        case 4: _t->bodyCollided((*reinterpret_cast<std::add_pointer_t<PattounX_body*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<PattounX_zone*>>(_a[2]))); break;
        case 5: _t->bodyEnteredZone((*reinterpret_cast<std::add_pointer_t<PattounX_body*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<PattounX_zone*>>(_a[2]))); break;
        case 6: _t->bodyExitedZone((*reinterpret_cast<std::add_pointer_t<PattounX_body*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<PattounX_zone*>>(_a[2]))); break;
        case 7: { PattounX_body* _r = _t->createBody((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<PattounX_body**>(_a[0]) = std::move(_r); }  break;
        case 8: { bool _r = _t->removeBody((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 9: { PattounX_body* _r = _t->getBody((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<PattounX_body**>(_a[0]) = std::move(_r); }  break;
        case 10: _t->clearBodies(); break;
        case 11: { PattounX_zone* _r = _t->createZone((*reinterpret_cast<std::add_pointer_t<ItemSnapable*>>(_a[1])));
            if (_a[0]) *reinterpret_cast<PattounX_zone**>(_a[0]) = std::move(_r); }  break;
        case 12: { bool _r = _t->removeZone((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 13: { PattounX_zone* _r = _t->getZone((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<PattounX_zone**>(_a[0]) = std::move(_r); }  break;
        case 14: _t->clearZones(); break;
        case 15: _t->setZonesFromSnapables((*reinterpret_cast<std::add_pointer_t<QVariantList>>(_a[1]))); break;
        case 16: _t->updateAll((*reinterpret_cast<std::add_pointer_t<qreal>>(_a[1]))); break;
        case 17: _t->updateBody((*reinterpret_cast<std::add_pointer_t<PattounX_body*>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2]))); break;
        case 18: { QVariantList _r = _t->getZonesAtPoint((*reinterpret_cast<std::add_pointer_t<QVector2D>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QVariantList*>(_a[0]) = std::move(_r); }  break;
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
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PattounX_body* >(); break;
            case 1:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PattounX_zone* >(); break;
            }
            break;
        case 5:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PattounX_body* >(); break;
            case 1:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PattounX_zone* >(); break;
            }
            break;
        case 6:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PattounX_body* >(); break;
            case 1:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PattounX_zone* >(); break;
            }
            break;
        case 11:
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
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< PattounX_body* >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (PattounX_engine::*)()>(_a, &PattounX_engine::bodyCountChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_engine::*)()>(_a, &PattounX_engine::zoneCountChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_engine::*)()>(_a, &PattounX_engine::enabledChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_engine::*)()>(_a, &PattounX_engine::debugModeChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_engine::*)(PattounX_body * , PattounX_zone * )>(_a, &PattounX_engine::bodyCollided, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_engine::*)(PattounX_body * , PattounX_zone * )>(_a, &PattounX_engine::bodyEnteredZone, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (PattounX_engine::*)(PattounX_body * , PattounX_zone * )>(_a, &PattounX_engine::bodyExitedZone, 6))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<int*>(_v) = _t->bodyCount(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->zoneCount(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->enabled(); break;
        case 3: *reinterpret_cast<bool*>(_v) = _t->debugMode(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 2: _t->setEnabled(*reinterpret_cast<bool*>(_v)); break;
        case 3: _t->setDebugMode(*reinterpret_cast<bool*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *PattounX_engine::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *PattounX_engine::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15PattounX_engineE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int PattounX_engine::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 19)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 19;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 19)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 19;
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
void PattounX_engine::bodyCountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void PattounX_engine::zoneCountChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void PattounX_engine::enabledChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void PattounX_engine::debugModeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void PattounX_engine::bodyCollided(PattounX_body * _t1, PattounX_zone * _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 4, nullptr, _t1, _t2);
}

// SIGNAL 5
void PattounX_engine::bodyEnteredZone(PattounX_body * _t1, PattounX_zone * _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 5, nullptr, _t1, _t2);
}

// SIGNAL 6
void PattounX_engine::bodyExitedZone(PattounX_body * _t1, PattounX_zone * _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 6, nullptr, _t1, _t2);
}
QT_WARNING_POP
