/****************************************************************************
** Meta object code from reading C++ file 'uistyle.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/tools/uistyle.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'uistyle.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN7UiStyleE_t {};
} // unnamed namespace

template <> constexpr inline auto UiStyle::qt_create_metaobjectdata<qt_meta_tag_ZN7UiStyleE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "UiStyle",
        "z_CHAT_DRAWERChanged",
        "",
        "z_CONFIG_PANEL",
        "z_HUD",
        "z_SELECTION_RECT",
        "z_TEMPLATE_PREVIEW",
        "z_CURSOR_TRACKER",
        "z_LINK_TRACKER",
        "z_WORKAREA",
        "z_BACKGROUND",
        "z_GRID",
        "z_GLOBAL_MA",
        "z_CHAT_DRAWER"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'z_CHAT_DRAWERChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'z_CONFIG_PANEL'
        QtMocHelpers::PropertyData<int>(3, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_HUD'
        QtMocHelpers::PropertyData<int>(4, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_SELECTION_RECT'
        QtMocHelpers::PropertyData<int>(5, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_TEMPLATE_PREVIEW'
        QtMocHelpers::PropertyData<int>(6, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_CURSOR_TRACKER'
        QtMocHelpers::PropertyData<int>(7, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_LINK_TRACKER'
        QtMocHelpers::PropertyData<int>(8, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_WORKAREA'
        QtMocHelpers::PropertyData<int>(9, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_BACKGROUND'
        QtMocHelpers::PropertyData<int>(10, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_GRID'
        QtMocHelpers::PropertyData<int>(11, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_GLOBAL_MA'
        QtMocHelpers::PropertyData<int>(12, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
        // property 'z_CHAT_DRAWER'
        QtMocHelpers::PropertyData<int>(13, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant | QMC::Final),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<UiStyle, qt_meta_tag_ZN7UiStyleE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject UiStyle::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN7UiStyleE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN7UiStyleE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN7UiStyleE_t>.metaTypes,
    nullptr
} };

void UiStyle::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<UiStyle *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->z_CHAT_DRAWERChanged(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (UiStyle::*)()>(_a, &UiStyle::z_CHAT_DRAWERChanged, 0))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<int*>(_v) = _t->z_CONFIG_PANEL(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->z_HUD(); break;
        case 2: *reinterpret_cast<int*>(_v) = _t->z_SELECTION_RECT(); break;
        case 3: *reinterpret_cast<int*>(_v) = _t->z_TEMPLATE_PREVIEW(); break;
        case 4: *reinterpret_cast<int*>(_v) = _t->z_CURSOR_TRACKER(); break;
        case 5: *reinterpret_cast<int*>(_v) = _t->z_LINK_TRACKER(); break;
        case 6: *reinterpret_cast<int*>(_v) = _t->z_WORKAREA(); break;
        case 7: *reinterpret_cast<int*>(_v) = _t->z_BACKGROUND(); break;
        case 8: *reinterpret_cast<int*>(_v) = _t->z_GRID(); break;
        case 9: *reinterpret_cast<int*>(_v) = _t->z_GLOBAL_MA(); break;
        case 10: *reinterpret_cast<int*>(_v) = _t->z_CHAT_DRAWER(); break;
        default: break;
        }
    }
}

const QMetaObject *UiStyle::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *UiStyle::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN7UiStyleE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int UiStyle::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 1)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 1;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 1)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 1;
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
void UiStyle::z_CHAT_DRAWERChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}
QT_WARNING_POP
