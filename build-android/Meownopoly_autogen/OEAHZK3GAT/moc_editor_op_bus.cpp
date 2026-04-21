/****************************************************************************
** Meta object code from reading C++ file 'editor_op_bus.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/editor/ops/editor_op_bus.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'editor_op_bus.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN11EditorOpBusE_t {};
} // unnamed namespace

template <> constexpr inline auto EditorOpBus::qt_create_metaobjectdata<qt_meta_tag_ZN11EditorOpBusE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "EditorOpBus",
        "opRecorded",
        "",
        "QJsonObject",
        "op",
        "localThrottled",
        "remoteOpReceived",
        "isApplyingRemoteChanged",
        "submitOp",
        "recordOp",
        "beginApplyRemote",
        "endApplyRemote",
        "submitOpWithUndo",
        "inverseOp",
        "undo",
        "redo",
        "clearUndo",
        "undoDepth",
        "redoDepth",
        "newUuid",
        "makeCreateOp",
        "itemJson",
        "makeDeleteOp",
        "uuid",
        "makeMoveOp",
        "gridX",
        "gridY",
        "zOrder",
        "makeLinkOp",
        "source",
        "target",
        "kind",
        "makeUnlinkOp",
        "isApplyingRemote"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'opRecorded'
        QtMocHelpers::SignalData<void(const QJsonObject &)>(1, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 },
        }}),
        // Signal 'localThrottled'
        QtMocHelpers::SignalData<void(const QJsonObject &)>(5, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 },
        }}),
        // Signal 'remoteOpReceived'
        QtMocHelpers::SignalData<void(const QJsonObject &)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 },
        }}),
        // Signal 'isApplyingRemoteChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'submitOp'
        QtMocHelpers::MethodData<void(const QJsonObject &)>(8, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 },
        }}),
        // Method 'recordOp'
        QtMocHelpers::MethodData<void(const QJsonObject &)>(9, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 },
        }}),
        // Method 'beginApplyRemote'
        QtMocHelpers::MethodData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'endApplyRemote'
        QtMocHelpers::MethodData<void()>(11, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'submitOpWithUndo'
        QtMocHelpers::MethodData<void(const QJsonObject &, const QJsonObject &)>(12, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 3, 4 }, { 0x80000000 | 3, 13 },
        }}),
        // Method 'undo'
        QtMocHelpers::MethodData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'redo'
        QtMocHelpers::MethodData<void()>(15, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'clearUndo'
        QtMocHelpers::MethodData<void()>(16, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'undoDepth'
        QtMocHelpers::MethodData<int() const>(17, 2, QMC::AccessPublic, QMetaType::Int),
        // Method 'redoDepth'
        QtMocHelpers::MethodData<int() const>(18, 2, QMC::AccessPublic, QMetaType::Int),
        // Method 'newUuid'
        QtMocHelpers::MethodData<QString() const>(19, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'makeCreateOp'
        QtMocHelpers::MethodData<QJsonObject(const QJsonObject &) const>(20, 2, QMC::AccessPublic, 0x80000000 | 3, {{
            { 0x80000000 | 3, 21 },
        }}),
        // Method 'makeDeleteOp'
        QtMocHelpers::MethodData<QJsonObject(const QString &) const>(22, 2, QMC::AccessPublic, 0x80000000 | 3, {{
            { QMetaType::QString, 23 },
        }}),
        // Method 'makeMoveOp'
        QtMocHelpers::MethodData<QJsonObject(const QString &, qreal, qreal, int) const>(24, 2, QMC::AccessPublic, 0x80000000 | 3, {{
            { QMetaType::QString, 23 }, { QMetaType::QReal, 25 }, { QMetaType::QReal, 26 }, { QMetaType::Int, 27 },
        }}),
        // Method 'makeMoveOp'
        QtMocHelpers::MethodData<QJsonObject(const QString &, qreal, qreal) const>(24, 2, QMC::AccessPublic | QMC::MethodCloned, 0x80000000 | 3, {{
            { QMetaType::QString, 23 }, { QMetaType::QReal, 25 }, { QMetaType::QReal, 26 },
        }}),
        // Method 'makeLinkOp'
        QtMocHelpers::MethodData<QJsonObject(const QString &, const QString &, const QString &) const>(28, 2, QMC::AccessPublic, 0x80000000 | 3, {{
            { QMetaType::QString, 29 }, { QMetaType::QString, 30 }, { QMetaType::QString, 31 },
        }}),
        // Method 'makeUnlinkOp'
        QtMocHelpers::MethodData<QJsonObject(const QString &, const QString &, const QString &) const>(32, 2, QMC::AccessPublic, 0x80000000 | 3, {{
            { QMetaType::QString, 29 }, { QMetaType::QString, 30 }, { QMetaType::QString, 31 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'isApplyingRemote'
        QtMocHelpers::PropertyData<bool>(33, QMetaType::Bool, QMC::DefaultPropertyFlags, 3),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<EditorOpBus, qt_meta_tag_ZN11EditorOpBusE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject EditorOpBus::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11EditorOpBusE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11EditorOpBusE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN11EditorOpBusE_t>.metaTypes,
    nullptr
} };

void EditorOpBus::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<EditorOpBus *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->opRecorded((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 1: _t->localThrottled((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 2: _t->remoteOpReceived((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 3: _t->isApplyingRemoteChanged(); break;
        case 4: _t->submitOp((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 5: _t->recordOp((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1]))); break;
        case 6: _t->beginApplyRemote(); break;
        case 7: _t->endApplyRemote(); break;
        case 8: _t->submitOpWithUndo((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        case 9: _t->undo(); break;
        case 10: _t->redo(); break;
        case 11: _t->clearUndo(); break;
        case 12: { int _r = _t->undoDepth();
            if (_a[0]) *reinterpret_cast<int*>(_a[0]) = std::move(_r); }  break;
        case 13: { int _r = _t->redoDepth();
            if (_a[0]) *reinterpret_cast<int*>(_a[0]) = std::move(_r); }  break;
        case 14: { QString _r = _t->newUuid();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 15: { QJsonObject _r = _t->makeCreateOp((*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QJsonObject*>(_a[0]) = std::move(_r); }  break;
        case 16: { QJsonObject _r = _t->makeDeleteOp((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QJsonObject*>(_a[0]) = std::move(_r); }  break;
        case 17: { QJsonObject _r = _t->makeMoveOp((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[4])));
            if (_a[0]) *reinterpret_cast<QJsonObject*>(_a[0]) = std::move(_r); }  break;
        case 18: { QJsonObject _r = _t->makeMoveOp((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<qreal>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QJsonObject*>(_a[0]) = std::move(_r); }  break;
        case 19: { QJsonObject _r = _t->makeLinkOp((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QJsonObject*>(_a[0]) = std::move(_r); }  break;
        case 20: { QJsonObject _r = _t->makeUnlinkOp((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QJsonObject*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (EditorOpBus::*)(const QJsonObject & )>(_a, &EditorOpBus::opRecorded, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorOpBus::*)(const QJsonObject & )>(_a, &EditorOpBus::localThrottled, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorOpBus::*)(const QJsonObject & )>(_a, &EditorOpBus::remoteOpReceived, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (EditorOpBus::*)()>(_a, &EditorOpBus::isApplyingRemoteChanged, 3))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->isApplyingRemote(); break;
        default: break;
        }
    }
}

const QMetaObject *EditorOpBus::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *EditorOpBus::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11EditorOpBusE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int EditorOpBus::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 21)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 21;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 21)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 21;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 1;
    }
    return _id;
}

// SIGNAL 0
void EditorOpBus::opRecorded(const QJsonObject & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void EditorOpBus::localThrottled(const QJsonObject & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 1, nullptr, _t1);
}

// SIGNAL 2
void EditorOpBus::remoteOpReceived(const QJsonObject & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 2, nullptr, _t1);
}

// SIGNAL 3
void EditorOpBus::isApplyingRemoteChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}
QT_WARNING_POP
