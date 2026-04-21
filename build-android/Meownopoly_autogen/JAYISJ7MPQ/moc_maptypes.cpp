/****************************************************************************
** Meta object code from reading C++ file 'maptypes.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/map/maptypes.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'maptypes.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN8MapTypesE_t {};
} // unnamed namespace

template <> constexpr inline auto MapTypes::qt_create_metaobjectdata<qt_meta_tag_ZN8MapTypesE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "MapTypes",
        "MapType",
        "AUTOSAVE",
        "CUSTOM",
        "UNDOREDO"
    };

    QtMocHelpers::UintData qt_methods {
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'MapType'
        QtMocHelpers::EnumData<MapType>(1, 1, QMC::EnumFlags{}).add({
            {    2, MapType::AUTOSAVE },
            {    3, MapType::CUSTOM },
            {    4, MapType::UNDOREDO },
        }),
    };
    return QtMocHelpers::metaObjectData<void, qt_meta_tag_ZN8MapTypesE_t>(QMC::PropertyAccessInStaticMetaCall, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}

static constexpr auto qt_staticMetaObjectContent_ZN8MapTypesE =
    MapTypes::qt_create_metaobjectdata<qt_meta_tag_ZN8MapTypesE_t>();
static constexpr auto qt_staticMetaObjectStaticContent_ZN8MapTypesE =
    qt_staticMetaObjectContent_ZN8MapTypesE.staticData;
static constexpr auto qt_staticMetaObjectRelocatingContent_ZN8MapTypesE =
    qt_staticMetaObjectContent_ZN8MapTypesE.relocatingData;

Q_CONSTINIT const QMetaObject MapTypes::staticMetaObject = { {
    nullptr,
    qt_staticMetaObjectStaticContent_ZN8MapTypesE.stringdata,
    qt_staticMetaObjectStaticContent_ZN8MapTypesE.data,
    nullptr,
    nullptr,
    qt_staticMetaObjectRelocatingContent_ZN8MapTypesE.metaTypes,
    nullptr
} };

QT_WARNING_POP
