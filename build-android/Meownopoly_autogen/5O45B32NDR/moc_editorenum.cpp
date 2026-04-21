/****************************************************************************
** Meta object code from reading C++ file 'editorenum.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/tools/editorenum.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'editorenum.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN10EditorEnumE_t {};
} // unnamed namespace

template <> constexpr inline auto EditorEnum::qt_create_metaobjectdata<qt_meta_tag_ZN10EditorEnumE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "EditorEnum",
        "EditorMouseMode",
        "EM_NORMAL",
        "EM_POSE",
        "EM_SELECTION_LINK",
        "EM_TEMPLATE",
        "EM_GAME",
        "EM_DRAW_POLYGON"
    };

    QtMocHelpers::UintData qt_methods {
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'EditorMouseMode'
        QtMocHelpers::EnumData<enum EditorMouseMode>(1, 1, QMC::EnumFlags{}).add({
            {    2, EditorMouseMode::EM_NORMAL },
            {    3, EditorMouseMode::EM_POSE },
            {    4, EditorMouseMode::EM_SELECTION_LINK },
            {    5, EditorMouseMode::EM_TEMPLATE },
            {    6, EditorMouseMode::EM_GAME },
            {    7, EditorMouseMode::EM_DRAW_POLYGON },
        }),
    };
    return QtMocHelpers::metaObjectData<EditorEnum, qt_meta_tag_ZN10EditorEnumE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject EditorEnum::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN10EditorEnumE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN10EditorEnumE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN10EditorEnumE_t>.metaTypes,
    nullptr
} };

void EditorEnum::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<EditorEnum *>(_o);
    (void)_t;
    (void)_c;
    (void)_id;
    (void)_a;
}

const QMetaObject *EditorEnum::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *EditorEnum::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN10EditorEnumE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int EditorEnum::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    return _id;
}
QT_WARNING_POP
