/****************************************************************************
** Meta object code from reading C++ file 'editdelta.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/game/map/editdelta.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'editdelta.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN13EditDeltaTypeE_t {};
} // unnamed namespace

template <> constexpr inline auto EditDeltaType::qt_create_metaobjectdata<qt_meta_tag_ZN13EditDeltaTypeE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "EditDeltaType",
        "Type",
        "TileModified",
        "TileAdded",
        "TileDeleted",
        "MetadataChanged"
    };

    QtMocHelpers::UintData qt_methods {
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'Type'
        QtMocHelpers::EnumData<Type>(1, 1, QMC::EnumFlags{}).add({
            {    2, Type::TileModified },
            {    3, Type::TileAdded },
            {    4, Type::TileDeleted },
            {    5, Type::MetadataChanged },
        }),
    };
    return QtMocHelpers::metaObjectData<void, qt_meta_tag_ZN13EditDeltaTypeE_t>(QMC::PropertyAccessInStaticMetaCall, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}

static constexpr auto qt_staticMetaObjectContent_ZN13EditDeltaTypeE =
    EditDeltaType::qt_create_metaobjectdata<qt_meta_tag_ZN13EditDeltaTypeE_t>();
static constexpr auto qt_staticMetaObjectStaticContent_ZN13EditDeltaTypeE =
    qt_staticMetaObjectContent_ZN13EditDeltaTypeE.staticData;
static constexpr auto qt_staticMetaObjectRelocatingContent_ZN13EditDeltaTypeE =
    qt_staticMetaObjectContent_ZN13EditDeltaTypeE.relocatingData;

Q_CONSTINIT const QMetaObject EditDeltaType::staticMetaObject = { {
    nullptr,
    qt_staticMetaObjectStaticContent_ZN13EditDeltaTypeE.stringdata,
    qt_staticMetaObjectStaticContent_ZN13EditDeltaTypeE.data,
    nullptr,
    nullptr,
    qt_staticMetaObjectRelocatingContent_ZN13EditDeltaTypeE.metaTypes,
    nullptr
} };

QT_WARNING_POP
