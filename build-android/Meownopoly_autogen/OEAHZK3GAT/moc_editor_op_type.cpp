/****************************************************************************
** Meta object code from reading C++ file 'editor_op_type.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/editor/ops/editor_op_type.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'editor_op_type.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN12EditorOpTypeE_t {};
} // unnamed namespace

template <> constexpr inline auto EditorOpType::qt_create_metaobjectdata<qt_meta_tag_ZN12EditorOpTypeE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "EditorOpType",
        "Value",
        "CreateItem",
        "DeleteItem",
        "MoveItem",
        "ResizeItem",
        "SetDisplayParameter",
        "SetCaseData",
        "SetDecorationParameter",
        "SetZoneParameter",
        "LinkItems",
        "UnlinkItems",
        "ApplyState"
    };

    QtMocHelpers::UintData qt_methods {
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'Value'
        QtMocHelpers::EnumData<Value>(1, 1, QMC::EnumFlags{}).add({
            {    2, Value::CreateItem },
            {    3, Value::DeleteItem },
            {    4, Value::MoveItem },
            {    5, Value::ResizeItem },
            {    6, Value::SetDisplayParameter },
            {    7, Value::SetCaseData },
            {    8, Value::SetDecorationParameter },
            {    9, Value::SetZoneParameter },
            {   10, Value::LinkItems },
            {   11, Value::UnlinkItems },
            {   12, Value::ApplyState },
        }),
    };
    return QtMocHelpers::metaObjectData<void, qt_meta_tag_ZN12EditorOpTypeE_t>(QMC::PropertyAccessInStaticMetaCall, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}

static constexpr auto qt_staticMetaObjectContent_ZN12EditorOpTypeE =
    EditorOpType::qt_create_metaobjectdata<qt_meta_tag_ZN12EditorOpTypeE_t>();
static constexpr auto qt_staticMetaObjectStaticContent_ZN12EditorOpTypeE =
    qt_staticMetaObjectContent_ZN12EditorOpTypeE.staticData;
static constexpr auto qt_staticMetaObjectRelocatingContent_ZN12EditorOpTypeE =
    qt_staticMetaObjectContent_ZN12EditorOpTypeE.relocatingData;

Q_CONSTINIT const QMetaObject EditorOpType::staticMetaObject = { {
    nullptr,
    qt_staticMetaObjectStaticContent_ZN12EditorOpTypeE.stringdata,
    qt_staticMetaObjectStaticContent_ZN12EditorOpTypeE.data,
    nullptr,
    nullptr,
    qt_staticMetaObjectRelocatingContent_ZN12EditorOpTypeE.metaTypes,
    nullptr
} };

QT_WARNING_POP
