/****************************************************************************
** Meta object code from reading C++ file 'launcher_manager.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/launcher/launcher_manager.h"
#include <QtNetwork/QSslError>
#include <QtNetwork/QSslPreSharedKeyAuthenticator>
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'launcher_manager.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN15LauncherManagerE_t {};
} // unnamed namespace

template <> constexpr inline auto LauncherManager::qt_create_metaobjectdata<qt_meta_tag_ZN15LauncherManagerE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "LauncherManager",
        "currentVersionChanged",
        "",
        "latestVersionChanged",
        "isDownloadingChanged",
        "downloadProgressChanged",
        "downloadStatusChanged",
        "packageCreatedChanged",
        "modelsListChanged",
        "connectionTestResult",
        "success",
        "message",
        "logMessage",
        "updateAvailable",
        "downloadSucess",
        "onDownloadFinished",
        "onDownloadProgress",
        "bytesReceived",
        "bytesTotal",
        "onVersionCheckFinished",
        "onConnectionTestFinished",
        "onModelsListFinished",
        "testServerConnection",
        "serverUrl",
        "checkForUpdates",
        "downloadResources",
        "version",
        "forceDownloadResources",
        "createResourcePackage",
        "folderPath",
        "uploadPackageToServer",
        "resetDownloadState",
        "setUploadToken",
        "token",
        "fetchModelsList",
        "downloadModel",
        "name",
        "createModelPackage",
        "uploadModelPackage",
        "currentVersion",
        "latestVersion",
        "isDownloading",
        "downloadProgress",
        "downloadStatus",
        "packageCreated",
        "modelsList",
        "QVariantList",
        "versionDescription"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'currentVersionChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'latestVersionChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'isDownloadingChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'downloadProgressChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'downloadStatusChanged'
        QtMocHelpers::SignalData<void()>(6, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'packageCreatedChanged'
        QtMocHelpers::SignalData<void()>(7, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'modelsListChanged'
        QtMocHelpers::SignalData<void()>(8, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'connectionTestResult'
        QtMocHelpers::SignalData<void(bool, const QString &)>(9, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Bool, 10 }, { QMetaType::QString, 11 },
        }}),
        // Signal 'logMessage'
        QtMocHelpers::SignalData<void(const QString &)>(12, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 11 },
        }}),
        // Signal 'updateAvailable'
        QtMocHelpers::SignalData<void()>(13, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'downloadSucess'
        QtMocHelpers::SignalData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Slot 'onDownloadFinished'
        QtMocHelpers::SlotData<void()>(15, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onDownloadProgress'
        QtMocHelpers::SlotData<void(qint64, qint64)>(16, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::LongLong, 17 }, { QMetaType::LongLong, 18 },
        }}),
        // Slot 'onVersionCheckFinished'
        QtMocHelpers::SlotData<void()>(19, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onConnectionTestFinished'
        QtMocHelpers::SlotData<void()>(20, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onModelsListFinished'
        QtMocHelpers::SlotData<void()>(21, 2, QMC::AccessPrivate, QMetaType::Void),
        // Method 'testServerConnection'
        QtMocHelpers::MethodData<void(const QString &)>(22, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 23 },
        }}),
        // Method 'checkForUpdates'
        QtMocHelpers::MethodData<void(const QString &)>(24, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 23 },
        }}),
        // Method 'downloadResources'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(25, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 23 }, { QMetaType::QString, 26 },
        }}),
        // Method 'forceDownloadResources'
        QtMocHelpers::MethodData<void(const QString &)>(27, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 23 },
        }}),
        // Method 'createResourcePackage'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(28, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 29 }, { QMetaType::QString, 26 },
        }}),
        // Method 'uploadPackageToServer'
        QtMocHelpers::MethodData<void(const QString &)>(30, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 23 },
        }}),
        // Method 'resetDownloadState'
        QtMocHelpers::MethodData<void()>(31, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'setUploadToken'
        QtMocHelpers::MethodData<void(const QString &)>(32, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 33 },
        }}),
        // Method 'fetchModelsList'
        QtMocHelpers::MethodData<void(const QString &)>(34, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 23 },
        }}),
        // Method 'downloadModel'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &)>(35, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 23 }, { QMetaType::QString, 36 }, { QMetaType::QString, 26 },
        }}),
        // Method 'createModelPackage'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &)>(37, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 29 }, { QMetaType::QString, 36 }, { QMetaType::QString, 26 },
        }}),
        // Method 'uploadModelPackage'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &)>(38, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 23 }, { QMetaType::QString, 36 }, { QMetaType::QString, 26 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'currentVersion'
        QtMocHelpers::PropertyData<QString>(39, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'latestVersion'
        QtMocHelpers::PropertyData<QString>(40, QMetaType::QString, QMC::DefaultPropertyFlags, 1),
        // property 'isDownloading'
        QtMocHelpers::PropertyData<bool>(41, QMetaType::Bool, QMC::DefaultPropertyFlags, 2),
        // property 'downloadProgress'
        QtMocHelpers::PropertyData<double>(42, QMetaType::Double, QMC::DefaultPropertyFlags, 3),
        // property 'downloadStatus'
        QtMocHelpers::PropertyData<QString>(43, QMetaType::QString, QMC::DefaultPropertyFlags, 4),
        // property 'packageCreated'
        QtMocHelpers::PropertyData<bool>(44, QMetaType::Bool, QMC::DefaultPropertyFlags, 5),
        // property 'modelsList'
        QtMocHelpers::PropertyData<QVariantList>(45, 0x80000000 | 46, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 6),
        // property 'bytesReceived'
        QtMocHelpers::PropertyData<qint64>(17, QMetaType::LongLong, QMC::DefaultPropertyFlags, 3),
        // property 'bytesTotal'
        QtMocHelpers::PropertyData<qint64>(18, QMetaType::LongLong, QMC::DefaultPropertyFlags, 3),
        // property 'versionDescription'
        QtMocHelpers::PropertyData<QString>(47, QMetaType::QString, QMC::DefaultPropertyFlags, 1),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<LauncherManager, qt_meta_tag_ZN15LauncherManagerE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject LauncherManager::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15LauncherManagerE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15LauncherManagerE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN15LauncherManagerE_t>.metaTypes,
    nullptr
} };

void LauncherManager::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<LauncherManager *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->currentVersionChanged(); break;
        case 1: _t->latestVersionChanged(); break;
        case 2: _t->isDownloadingChanged(); break;
        case 3: _t->downloadProgressChanged(); break;
        case 4: _t->downloadStatusChanged(); break;
        case 5: _t->packageCreatedChanged(); break;
        case 6: _t->modelsListChanged(); break;
        case 7: _t->connectionTestResult((*reinterpret_cast<std::add_pointer_t<bool>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 8: _t->logMessage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 9: _t->updateAvailable(); break;
        case 10: _t->downloadSucess(); break;
        case 11: _t->onDownloadFinished(); break;
        case 12: _t->onDownloadProgress((*reinterpret_cast<std::add_pointer_t<qint64>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<qint64>>(_a[2]))); break;
        case 13: _t->onVersionCheckFinished(); break;
        case 14: _t->onConnectionTestFinished(); break;
        case 15: _t->onModelsListFinished(); break;
        case 16: _t->testServerConnection((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 17: _t->checkForUpdates((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 18: _t->downloadResources((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 19: _t->forceDownloadResources((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 20: _t->createResourcePackage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 21: _t->uploadPackageToServer((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 22: _t->resetDownloadState(); break;
        case 23: _t->setUploadToken((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 24: _t->fetchModelsList((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 25: _t->downloadModel((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 26: _t->createModelPackage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 27: _t->uploadModelPackage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)()>(_a, &LauncherManager::currentVersionChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)()>(_a, &LauncherManager::latestVersionChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)()>(_a, &LauncherManager::isDownloadingChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)()>(_a, &LauncherManager::downloadProgressChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)()>(_a, &LauncherManager::downloadStatusChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)()>(_a, &LauncherManager::packageCreatedChanged, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)()>(_a, &LauncherManager::modelsListChanged, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)(bool , const QString & )>(_a, &LauncherManager::connectionTestResult, 7))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)(const QString & )>(_a, &LauncherManager::logMessage, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)()>(_a, &LauncherManager::updateAvailable, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (LauncherManager::*)()>(_a, &LauncherManager::downloadSucess, 10))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QString*>(_v) = _t->currentVersion(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->latestVersion(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->isDownloading(); break;
        case 3: *reinterpret_cast<double*>(_v) = _t->downloadProgress(); break;
        case 4: *reinterpret_cast<QString*>(_v) = _t->downloadStatus(); break;
        case 5: *reinterpret_cast<bool*>(_v) = _t->packageCreated(); break;
        case 6: *reinterpret_cast<QVariantList*>(_v) = _t->modelsList(); break;
        case 7: *reinterpret_cast<qint64*>(_v) = _t->bytesReceived(); break;
        case 8: *reinterpret_cast<qint64*>(_v) = _t->bytesTotal(); break;
        case 9: *reinterpret_cast<QString*>(_v) = _t->versionDescription(); break;
        default: break;
        }
    }
}

const QMetaObject *LauncherManager::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *LauncherManager::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15LauncherManagerE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int LauncherManager::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 28)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 28;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 28)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 28;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 10;
    }
    return _id;
}

// SIGNAL 0
void LauncherManager::currentVersionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void LauncherManager::latestVersionChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void LauncherManager::isDownloadingChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void LauncherManager::downloadProgressChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void LauncherManager::downloadStatusChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void LauncherManager::packageCreatedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}

// SIGNAL 6
void LauncherManager::modelsListChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 6, nullptr);
}

// SIGNAL 7
void LauncherManager::connectionTestResult(bool _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 7, nullptr, _t1, _t2);
}

// SIGNAL 8
void LauncherManager::logMessage(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 8, nullptr, _t1);
}

// SIGNAL 9
void LauncherManager::updateAvailable()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}

// SIGNAL 10
void LauncherManager::downloadSucess()
{
    QMetaObject::activate(this, &staticMetaObject, 10, nullptr);
}
QT_WARNING_POP
