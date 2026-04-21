/****************************************************************************
** Meta object code from reading C++ file 'minigame_sync.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/network/minigame_sync.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'minigame_sync.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN12MinigameSyncE_t {};
} // unnamed namespace

template <> constexpr inline auto MinigameSync::qt_create_metaobjectdata<qt_meta_tag_ZN12MinigameSyncE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "MinigameSync",
        "playerPositionUpdated",
        "",
        "playerId",
        "x",
        "y",
        "vx",
        "vy",
        "snapshotReceived",
        "senderId",
        "QJsonObject",
        "snapshot",
        "inputRateChanged",
        "snapshotRateChanged",
        "runningChanged",
        "onInputTick",
        "onSnapshotTick",
        "onRemotePosition",
        "onRenderTick",
        "start",
        "stop",
        "setLocalPosition",
        "setSnapshot",
        "inputRate",
        "snapshotRate",
        "running"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'playerPositionUpdated'
        QtMocHelpers::SignalData<void(const QString &, qreal, qreal, qreal, qreal)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 3 }, { QMetaType::QReal, 4 }, { QMetaType::QReal, 5 }, { QMetaType::QReal, 6 },
            { QMetaType::QReal, 7 },
        }}),
        // Signal 'snapshotReceived'
        QtMocHelpers::SignalData<void(const QString &, const QJsonObject &)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 9 }, { 0x80000000 | 10, 11 },
        }}),
        // Signal 'inputRateChanged'
        QtMocHelpers::SignalData<void()>(12, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'snapshotRateChanged'
        QtMocHelpers::SignalData<void()>(13, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'runningChanged'
        QtMocHelpers::SignalData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'onInputTick'
        QtMocHelpers::SlotData<void()>(15, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onSnapshotTick'
        QtMocHelpers::SlotData<void()>(16, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onRemotePosition'
        QtMocHelpers::SlotData<void(const QString &, qreal, qreal, qreal, qreal)>(17, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 3 }, { QMetaType::QReal, 4 }, { QMetaType::QReal, 5 }, { QMetaType::QReal, 6 },
            { QMetaType::QReal, 7 },
        }}),
        // Slot 'onRenderTick'
        QtMocHelpers::SlotData<void()>(18, 2, QMC::AccessPrivate, QMetaType::Void),
        // Method 'start'
        QtMocHelpers::MethodData<void()>(19, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'stop'
        QtMocHelpers::MethodData<void()>(20, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'setLocalPosition'
        QtMocHelpers::MethodData<void(qreal, qreal, qreal, qreal)>(21, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QReal, 4 }, { QMetaType::QReal, 5 }, { QMetaType::QReal, 6 }, { QMetaType::QReal, 7 },
        }}),
        // Method 'setSnapshot'
        QtMocHelpers::MethodData<void(const QJsonObject &)>(22, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 10, 11 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'inputRate'
        QtMocHelpers::PropertyData<int>(23, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'snapshotRate'
        QtMocHelpers::PropertyData<int>(24, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
        // property 'running'
        QtMocHelpers::PropertyData<bool>(25, QMetaType::Bool, QMC::DefaultPropertyFlags, 4),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<MinigameSync, qt_meta_tag_ZN12MinigameSyncE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject MinigameSync::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12MinigameSyncE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12MinigameSyncE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN12MinigameSyncE_t>.metaTypes,
    nullptr
} };

void MinigameSync::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<MinigameSync *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->playerPositionUpdated((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[5]))); break;
        case 1: _t->snapshotReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 2: _t->inputRateChanged(); break;
        case 3: _t->snapshotRateChanged(); break;
        case 4: _t->runningChanged(); break;
        case 5: _t->onInputTick(); break;
        case 6: _t->onSnapshotTick(); break;
        case 7: _t->onRemotePosition((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[5]))); break;
        case 8: _t->onRenderTick(); break;
        case 9: _t->start(); break;
        case 10: _t->stop(); break;
        case 11: _t->setLocalPosition((*reinterpret_cast<std::add_pointer_t<qreal>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[4]))); break;
        case 12: _t->setSnapshot((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (MinigameSync::*)(const QString & , qreal , qreal , qreal , qreal )>(_a, &MinigameSync::playerPositionUpdated, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (MinigameSync::*)(const QString & , const QJsonObject & )>(_a, &MinigameSync::snapshotReceived, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (MinigameSync::*)()>(_a, &MinigameSync::inputRateChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (MinigameSync::*)()>(_a, &MinigameSync::snapshotRateChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (MinigameSync::*)()>(_a, &MinigameSync::runningChanged, 4))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<int*>(_v) = _t->inputRate(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->snapshotRate(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->running(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setInputRate(*reinterpret_cast<int*>(_v)); break;
        case 1: _t->setSnapshotRate(*reinterpret_cast<int*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *MinigameSync::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *MinigameSync::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12MinigameSyncE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int MinigameSync::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
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
        _id -= 3;
    }
    return _id;
}

// SIGNAL 0
void MinigameSync::playerPositionUpdated(const QString & _t1, qreal _t2, qreal _t3, qreal _t4, qreal _t5)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1, _t2, _t3, _t4, _t5);
}

// SIGNAL 1
void MinigameSync::snapshotReceived(const QString & _t1, const QJsonObject & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1, _t2);
}

// SIGNAL 2
void MinigameSync::inputRateChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void MinigameSync::snapshotRateChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void MinigameSync::runningChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}
QT_WARNING_POP
