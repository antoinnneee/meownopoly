/****************************************************************************
** Meta object code from reading C++ file 'game_message_type.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/network/game_message_type.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'game_message_type.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN15GameMessageTypeE_t {};
} // unnamed namespace

template <> constexpr inline auto GameMessageType::qt_create_metaobjectdata<qt_meta_tag_ZN15GameMessageTypeE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "GameMessageType",
        "Value",
        "GameStart",
        "GameEnd",
        "TurnStart",
        "DiceRoll",
        "PlayerMove",
        "BuyProperty",
        "PayRent",
        "CardDraw",
        "JailEnter",
        "JailLeave",
        "PlayerJoined",
        "PlayerLeft",
        "MapSync",
        "MinigameInput",
        "MinigameSnapshot"
    };

    QtMocHelpers::UintData qt_methods {
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'Value'
        QtMocHelpers::EnumData<Value>(1, 1, QMC::EnumFlags{}).add({
            {    2, Value::GameStart },
            {    3, Value::GameEnd },
            {    4, Value::TurnStart },
            {    5, Value::DiceRoll },
            {    6, Value::PlayerMove },
            {    7, Value::BuyProperty },
            {    8, Value::PayRent },
            {    9, Value::CardDraw },
            {   10, Value::JailEnter },
            {   11, Value::JailLeave },
            {   12, Value::PlayerJoined },
            {   13, Value::PlayerLeft },
            {   14, Value::MapSync },
            {   15, Value::MinigameInput },
            {   16, Value::MinigameSnapshot },
        }),
    };
    return QtMocHelpers::metaObjectData<void, qt_meta_tag_ZN15GameMessageTypeE_t>(QMC::PropertyAccessInStaticMetaCall, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}

static constexpr auto qt_staticMetaObjectContent_ZN15GameMessageTypeE =
    GameMessageType::qt_create_metaobjectdata<qt_meta_tag_ZN15GameMessageTypeE_t>();
static constexpr auto qt_staticMetaObjectStaticContent_ZN15GameMessageTypeE =
    qt_staticMetaObjectContent_ZN15GameMessageTypeE.staticData;
static constexpr auto qt_staticMetaObjectRelocatingContent_ZN15GameMessageTypeE =
    qt_staticMetaObjectContent_ZN15GameMessageTypeE.relocatingData;

Q_CONSTINIT const QMetaObject GameMessageType::staticMetaObject = { {
    nullptr,
    qt_staticMetaObjectStaticContent_ZN15GameMessageTypeE.stringdata,
    qt_staticMetaObjectStaticContent_ZN15GameMessageTypeE.data,
    nullptr,
    nullptr,
    qt_staticMetaObjectRelocatingContent_ZN15GameMessageTypeE.metaTypes,
    nullptr
} };

QT_WARNING_POP
