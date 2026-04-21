/****************************************************************************
** Meta object code from reading C++ file 'asset_manager.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/assetManager/asset_manager.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'asset_manager.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN10AssetModelE_t {};
} // unnamed namespace

template <> constexpr inline auto AssetModel::qt_create_metaobjectdata<qt_meta_tag_ZN10AssetModelE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "AssetModel",
        "createFilteredModel",
        "AssetModel*",
        "",
        "type"
    };

    QtMocHelpers::UintData qt_methods {
        // Method 'createFilteredModel'
        QtMocHelpers::MethodData<AssetModel *(const QString &) const>(1, 3, QMC::AccessPublic, 0x80000000 | 2, {{
            { QMetaType::QString, 4 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<AssetModel, qt_meta_tag_ZN10AssetModelE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject AssetModel::staticMetaObject = { {
    QMetaObject::SuperData::link<QAbstractListModel::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN10AssetModelE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN10AssetModelE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN10AssetModelE_t>.metaTypes,
    nullptr
} };

void AssetModel::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<AssetModel *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: { AssetModel* _r = _t->createFilteredModel((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<AssetModel**>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
}

const QMetaObject *AssetModel::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *AssetModel::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN10AssetModelE_t>.strings))
        return static_cast<void*>(this);
    return QAbstractListModel::qt_metacast(_clname);
}

int AssetModel::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QAbstractListModel::qt_metacall(_c, _id, _a);
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
    return _id;
}
namespace {
struct qt_meta_tag_ZN12AssetManagerE_t {};
} // unnamed namespace

template <> constexpr inline auto AssetManager::qt_create_metaobjectdata<qt_meta_tag_ZN12AssetManagerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "AssetManager",
        "assetsBasePathChanged",
        "",
        "categoriesChanged",
        "buildAssetPath",
        "category",
        "type",
        "filename",
        "getAssetPath",
        "id",
        "getAnimatedGifPath",
        "categories",
        "getAssetModel",
        "AssetModel*",
        "getAssetByFilename",
        "QVariantMap",
        "getAssetById",
        "getRandomAsset",
        "loadAssets",
        "setAssetsBasePath",
        "basePath",
        "getAvailableTypes",
        "getAvailableCategories",
        "hasMatchingAsset",
        "searchText",
        "isAssetValid",
        "reloadAssets",
        "getDefaultAssetPath",
        "generateMetadataForDirectory",
        "directoryPath",
        "generateAllMetadata",
        "scanAvailableAssets",
        "getAvailableBackgrounds",
        "getAvailableModels",
        "isTransparent",
        "px",
        "py",
        "path",
        "getAppDataPath",
        "assetsBasePath"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'assetsBasePathChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'categoriesChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'buildAssetPath'
        QtMocHelpers::MethodData<QString(const QString &, const QString &, const QString &) const>(4, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 6 }, { QMetaType::QString, 7 },
        }}),
        // Method 'getAssetPath'
        QtMocHelpers::MethodData<QString(const QString &, const QString &, const QString &)>(8, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 6 }, { QMetaType::QString, 9 },
        }}),
        // Method 'getAnimatedGifPath'
        QtMocHelpers::MethodData<QString(const QString &, const QString &, const QString &)>(10, 2, QMC::AccessPublic, QMetaType::QString, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 6 }, { QMetaType::QString, 9 },
        }}),
        // Method 'categories'
        QtMocHelpers::MethodData<QStringList() const>(11, 2, QMC::AccessPublic, QMetaType::QStringList),
        // Method 'getAssetModel'
        QtMocHelpers::MethodData<AssetModel *(const QString &, const QString &)>(12, 2, QMC::AccessPublic, 0x80000000 | 13, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 6 },
        }}),
        // Method 'getAssetByFilename'
        QtMocHelpers::MethodData<QVariantMap(const QString &, const QString &, const QString &)>(14, 2, QMC::AccessPublic, 0x80000000 | 15, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 6 }, { QMetaType::QString, 7 },
        }}),
        // Method 'getAssetById'
        QtMocHelpers::MethodData<QVariantMap(const QString &, const QString &, const QString &)>(16, 2, QMC::AccessPublic, 0x80000000 | 15, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 6 }, { QMetaType::QString, 9 },
        }}),
        // Method 'getRandomAsset'
        QtMocHelpers::MethodData<QVariantMap(const QString &, const QString &)>(17, 2, QMC::AccessPublic, 0x80000000 | 15, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 6 },
        }}),
        // Method 'loadAssets'
        QtMocHelpers::MethodData<void()>(18, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'setAssetsBasePath'
        QtMocHelpers::MethodData<void(const QString &)>(19, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 20 },
        }}),
        // Method 'getAvailableTypes'
        QtMocHelpers::MethodData<QStringList(const QString &) const>(21, 2, QMC::AccessPublic, QMetaType::QStringList, {{
            { QMetaType::QString, 5 },
        }}),
        // Method 'getAvailableCategories'
        QtMocHelpers::MethodData<QStringList() const>(22, 2, QMC::AccessPublic, QMetaType::QStringList),
        // Method 'hasMatchingAsset'
        QtMocHelpers::MethodData<bool(const QString &, const QString &, const QString &)>(23, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 6 }, { QMetaType::QString, 24 },
        }}),
        // Method 'isAssetValid'
        QtMocHelpers::MethodData<bool(const QString &, const QString &, const QString &)>(25, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 5 }, { QMetaType::QString, 6 }, { QMetaType::QString, 9 },
        }}),
        // Method 'reloadAssets'
        QtMocHelpers::MethodData<void()>(26, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'getDefaultAssetPath'
        QtMocHelpers::MethodData<QString() const>(27, 2, QMC::AccessPublic, QMetaType::QString),
        // Method 'generateMetadataForDirectory'
        QtMocHelpers::MethodData<bool(const QString &)>(28, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::QString, 29 },
        }}),
        // Method 'generateAllMetadata'
        QtMocHelpers::MethodData<bool()>(30, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'scanAvailableAssets'
        QtMocHelpers::MethodData<QStringList()>(31, 2, QMC::AccessPublic, QMetaType::QStringList),
        // Method 'getAvailableBackgrounds'
        QtMocHelpers::MethodData<QStringList() const>(32, 2, QMC::AccessPublic, QMetaType::QStringList),
        // Method 'getAvailableModels'
        QtMocHelpers::MethodData<QStringList() const>(33, 2, QMC::AccessPublic, QMetaType::QStringList),
        // Method 'isTransparent'
        QtMocHelpers::MethodData<bool(float, float, QString)>(34, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::Float, 35 }, { QMetaType::Float, 36 }, { QMetaType::QString, 37 },
        }}),
        // Method 'getAppDataPath'
        QtMocHelpers::MethodData<QString() const>(38, 2, QMC::AccessPublic, QMetaType::QString),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'categories'
        QtMocHelpers::PropertyData<QStringList>(11, QMetaType::QStringList, QMC::DefaultPropertyFlags, 1),
        // property 'assetsBasePath'
        QtMocHelpers::PropertyData<QString>(39, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<AssetManager, qt_meta_tag_ZN12AssetManagerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject AssetManager::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12AssetManagerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12AssetManagerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN12AssetManagerE_t>.metaTypes,
    nullptr
} };

void AssetManager::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<AssetManager *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->assetsBasePathChanged(); break;
        case 1: _t->categoriesChanged(); break;
        case 2: { QString _r = _t->buildAssetPath((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 3: { QString _r = _t->getAssetPath((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 4: { QString _r = _t->getAnimatedGifPath((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 5: { QStringList _r = _t->categories();
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 6: { AssetModel* _r = _t->getAssetModel((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<AssetModel**>(_a[0]) = std::move(_r); }  break;
        case 7: { QVariantMap _r = _t->getAssetByFilename((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QVariantMap*>(_a[0]) = std::move(_r); }  break;
        case 8: { QVariantMap _r = _t->getAssetById((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<QVariantMap*>(_a[0]) = std::move(_r); }  break;
        case 9: { QVariantMap _r = _t->getRandomAsset((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])));
            if (_a[0]) *reinterpret_cast<QVariantMap*>(_a[0]) = std::move(_r); }  break;
        case 10: _t->loadAssets(); break;
        case 11: _t->setAssetsBasePath((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 12: { QStringList _r = _t->getAvailableTypes((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 13: { QStringList _r = _t->getAvailableCategories();
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 14: { bool _r = _t->hasMatchingAsset((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 15: { bool _r = _t->isAssetValid((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 16: _t->reloadAssets(); break;
        case 17: { QString _r = _t->getDefaultAssetPath();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        case 18: { bool _r = _t->generateMetadataForDirectory((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 19: { bool _r = _t->generateAllMetadata();
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 20: { QStringList _r = _t->scanAvailableAssets();
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 21: { QStringList _r = _t->getAvailableBackgrounds();
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 22: { QStringList _r = _t->getAvailableModels();
            if (_a[0]) *reinterpret_cast<QStringList*>(_a[0]) = std::move(_r); }  break;
        case 23: { bool _r = _t->isTransparent((*reinterpret_cast<std::add_pointer_t<float>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<float>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 24: { QString _r = _t->getAppDataPath();
            if (_a[0]) *reinterpret_cast<QString*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (AssetManager::*)()>(_a, &AssetManager::assetsBasePathChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (AssetManager::*)()>(_a, &AssetManager::categoriesChanged, 1))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QStringList*>(_v) = _t->categories(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->assetsBasePath(); break;
        default: break;
        }
    }
}

const QMetaObject *AssetManager::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *AssetManager::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN12AssetManagerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int AssetManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 25)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 25;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 25)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 25;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 2;
    }
    return _id;
}

// SIGNAL 0
void AssetManager::assetsBasePathChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void AssetManager::categoriesChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}
QT_WARNING_POP
