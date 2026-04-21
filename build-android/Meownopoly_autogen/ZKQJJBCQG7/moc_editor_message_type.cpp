/****************************************************************************
** Meta object code from reading C++ file 'editor_message_type.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/editor/network/editor_message_type.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'editor_message_type.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN17EditorMessageTypeE_t {};
} // unnamed namespace

template <> constexpr inline auto EditorMessageType::qt_create_metaobjectdata<qt_meta_tag_ZN17EditorMessageTypeE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "EditorMessageType",
        "Value",
        "Hello",
        "Welcome",
        "FullSync",
        "Op",
        "OpAck",
        "OpReject",
        "CursorUpdate",
        "SelectionUpdate",
        "PlayerRoster",
        "OpChunk",
        "HostLeaving"
    };

    QtMocHelpers::UintData qt_methods {
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'Value'
        QtMocHelpers::EnumData<Value>(1, 1, QMC::EnumFlags{}).add({
            {    2, Value::Hello },
            {    3, Value::Welcome },
            {    4, Value::FullSync },
            {    5, Value::Op },
            {    6, Value::OpAck },
            {    7, Value::OpReject },
            {    8, Value::CursorUpdate },
            {    9, Value::SelectionUpdate },
            {   10, Value::PlayerRoster },
            {   11, Value::OpChunk },
            {   12, Value::HostLeaving },
        }),
    };
    return QtMocHelpers::metaObjectData<void, qt_meta_tag_ZN17EditorMessageTypeE_t>(QMC::PropertyAccessInStaticMetaCall, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}

static constexpr auto qt_staticMetaObjectContent_ZN17EditorMessageTypeE =
    EditorMessageType::qt_create_metaobjectdata<qt_meta_tag_ZN17EditorMessageTypeE_t>();
static constexpr auto qt_staticMetaObjectStaticContent_ZN17EditorMessageTypeE =
    qt_staticMetaObjectContent_ZN17EditorMessageTypeE.staticData;
static constexpr auto qt_staticMetaObjectRelocatingContent_ZN17EditorMessageTypeE =
    qt_staticMetaObjectContent_ZN17EditorMessageTypeE.relocatingData;

Q_CONSTINIT const QMetaObject EditorMessageType::staticMetaObject = { {
    nullptr,
    qt_staticMetaObjectStaticContent_ZN17EditorMessageTypeE.stringdata,
    qt_staticMetaObjectStaticContent_ZN17EditorMessageTypeE.data,
    nullptr,
    nullptr,
    qt_staticMetaObjectRelocatingContent_ZN17EditorMessageTypeE.metaTypes,
    nullptr
} };

QT_WARNING_POP
