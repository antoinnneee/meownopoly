/****************************************************************************
** Meta object code from reading C++ file 'game.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.9.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../game.h"
#include <QtCore/qmetatype.h>
#include <QtCore/QList>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'game.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.9.1. It"
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
struct qt_meta_tag_ZN4GameE_t {};
} // unnamed namespace

template <> constexpr inline auto Game::qt_create_metaobjectdata<qt_meta_tag_ZN4GameE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "Game",
        "gameStarted",
        "",
        "playersChanged",
        "currentPlayerIndexChanged",
        "propertyPurchased",
        "position",
        "Player*",
        "newOwner",
        "assetNumberChanged",
        "assetPathChanged",
        "init",
        "startGame",
        "createPlayer",
        "name",
        "color",
        "indexLogo",
        "kibbles",
        "setupPlayers",
        "QVariantList",
        "playerData",
        "nextPlayer",
        "getPlayer",
        "getNewCaseType",
        "Case*",
        "Case::CaseType",
        "type",
        "getNewPlayer",
        "saveCaseToJson",
        "QVariantMap",
        "caseData",
        "saveMultipleCasesToJson",
        "casesData",
        "checkDecorationAssets",
        "getAssetPath",
        "QVariant",
        "index",
        "boardSize",
        "currentPlayerIndex",
        "players",
        "QList<Player*>",
        "listPlayers",
        "listCases",
        "Case**",
        "listCards",
        "QList<Card*>",
        "assetNumber",
        "assetPath"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'gameStarted'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'playersChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'currentPlayerIndexChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'propertyPurchased'
        QtMocHelpers::SignalData<void(int, Player *)>(5, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 6 }, { 0x80000000 | 7, 8 },
        }}),
        // Signal 'assetNumberChanged'
        QtMocHelpers::SignalData<void()>(9, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'assetPathChanged'
        QtMocHelpers::SignalData<void()>(10, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'init'
        QtMocHelpers::MethodData<void()>(11, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'startGame'
        QtMocHelpers::MethodData<void()>(12, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'createPlayer'
        QtMocHelpers::MethodData<Player *(const QString, QColor, int, int)>(13, 2, QMC::AccessPublic, 0x80000000 | 7, {{
            { QMetaType::QString, 14 }, { QMetaType::QColor, 15 }, { QMetaType::Int, 16 }, { QMetaType::Int, 17 },
        }}),
        // Method 'setupPlayers'
        QtMocHelpers::MethodData<void(const QVariantList &)>(18, 2, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 19, 20 },
        }}),
        // Method 'nextPlayer'
        QtMocHelpers::MethodData<void()>(21, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'getPlayer'
        QtMocHelpers::MethodData<Player *()>(22, 2, QMC::AccessPublic, 0x80000000 | 7),
        // Method 'getNewCaseType'
        QtMocHelpers::MethodData<Case *(Case::CaseType)>(23, 2, QMC::AccessPublic, 0x80000000 | 24, {{
            { 0x80000000 | 25, 26 },
        }}),
        // Method 'getNewPlayer'
        QtMocHelpers::MethodData<Player *()>(27, 2, QMC::AccessPublic, 0x80000000 | 7),
        // Method 'saveCaseToJson'
        QtMocHelpers::MethodData<bool(const QVariantMap &)>(28, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { 0x80000000 | 29, 30 },
        }}),
        // Method 'saveMultipleCasesToJson'
        QtMocHelpers::MethodData<bool(const QVariantList &)>(31, 2, QMC::AccessPublic, QMetaType::Bool, {{
            { 0x80000000 | 19, 32 },
        }}),
        // Method 'checkDecorationAssets'
        QtMocHelpers::MethodData<bool()>(33, 2, QMC::AccessPublic, QMetaType::Bool),
        // Method 'getAssetPath'
        QtMocHelpers::MethodData<QVariant(int) const>(34, 2, QMC::AccessPublic, 0x80000000 | 35, {{
            { QMetaType::Int, 36 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'boardSize'
        QtMocHelpers::PropertyData<int>(37, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant),
        // property 'currentPlayerIndex'
        QtMocHelpers::PropertyData<int>(38, QMetaType::Int, QMC::DefaultPropertyFlags, 2),
        // property 'players'
        QtMocHelpers::PropertyData<QList<Player*>>(39, 0x80000000 | 40, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 1),
        // property 'listPlayers'
        QtMocHelpers::PropertyData<QList<Player*>>(41, 0x80000000 | 40, QMC::DefaultPropertyFlags | QMC::EnumOrFlag | QMC::Constant | QMC::Final),
        // property 'listCases'
        QtMocHelpers::PropertyData<Case**>(42, 0x80000000 | 43, QMC::DefaultPropertyFlags | QMC::EnumOrFlag | QMC::Constant | QMC::Final),
        // property 'listCards'
        QtMocHelpers::PropertyData<QList<Card*>>(44, 0x80000000 | 45, QMC::DefaultPropertyFlags | QMC::EnumOrFlag | QMC::Constant | QMC::Final),
        // property 'assetNumber'
        QtMocHelpers::PropertyData<int>(46, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet | QMC::Final, 4),
        // property 'assetPath'
        QtMocHelpers::PropertyData<QVariantList>(47, 0x80000000 | 19, QMC::DefaultPropertyFlags | QMC::Writable | QMC::EnumOrFlag | QMC::StdCppSet | QMC::Final, 5),
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<Game, qt_meta_tag_ZN4GameE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject Game::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4GameE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4GameE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN4GameE_t>.metaTypes,
    nullptr
} };

void Game::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<Game *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->gameStarted(); break;
        case 1: _t->playersChanged(); break;
        case 2: _t->currentPlayerIndexChanged(); break;
        case 3: _t->propertyPurchased((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<Player*>>(_a[2]))); break;
        case 4: _t->assetNumberChanged(); break;
        case 5: _t->assetPathChanged(); break;
        case 6: _t->init(); break;
        case 7: _t->startGame(); break;
        case 8: { Player* _r = _t->createPlayer((*reinterpret_cast< std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast< std::add_pointer_t<QColor>>(_a[2])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[3])),(*reinterpret_cast< std::add_pointer_t<int>>(_a[4])));
            if (_a[0]) *reinterpret_cast< Player**>(_a[0]) = std::move(_r); }  break;
        case 9: _t->setupPlayers((*reinterpret_cast< std::add_pointer_t<QVariantList>>(_a[1]))); break;
        case 10: _t->nextPlayer(); break;
        case 11: { Player* _r = _t->getPlayer();
            if (_a[0]) *reinterpret_cast< Player**>(_a[0]) = std::move(_r); }  break;
        case 12: { Case* _r = _t->getNewCaseType((*reinterpret_cast< std::add_pointer_t<Case::CaseType>>(_a[1])));
            if (_a[0]) *reinterpret_cast< Case**>(_a[0]) = std::move(_r); }  break;
        case 13: { Player* _r = _t->getNewPlayer();
            if (_a[0]) *reinterpret_cast< Player**>(_a[0]) = std::move(_r); }  break;
        case 14: { bool _r = _t->saveCaseToJson((*reinterpret_cast< std::add_pointer_t<QVariantMap>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 15: { bool _r = _t->saveMultipleCasesToJson((*reinterpret_cast< std::add_pointer_t<QVariantList>>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 16: { bool _r = _t->checkDecorationAssets();
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = std::move(_r); }  break;
        case 17: { QVariant _r = _t->getAssetPath((*reinterpret_cast< std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast< QVariant*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 3:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 1:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< Player* >(); break;
            }
            break;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (Game::*)()>(_a, &Game::gameStarted, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)()>(_a, &Game::playersChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)()>(_a, &Game::currentPlayerIndexChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)(int , Player * )>(_a, &Game::propertyPurchased, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)()>(_a, &Game::assetNumberChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (Game::*)()>(_a, &Game::assetPathChanged, 5))
            return;
    }
    if (_c == QMetaObject::RegisterPropertyMetaType) {
        switch (_id) {
        default: *reinterpret_cast<int*>(_a[0]) = -1; break;
        case 5:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< QList<Card*> >(); break;
        case 3:
        case 2:
            *reinterpret_cast<int*>(_a[0]) = qRegisterMetaType< QList<Player*> >(); break;
        }
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<int*>(_v) = _t->boardSize(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->currentPlayerIndex(); break;
        case 2: *reinterpret_cast<QList<Player*>*>(_v) = _t->players(); break;
        case 3: *reinterpret_cast<QList<Player*>*>(_v) = _t->listPlayers(); break;
        case 4: *reinterpret_cast<Case***>(_v) = _t->listCases(); break;
        case 5: *reinterpret_cast<QList<Card*>*>(_v) = _t->listCards(); break;
        case 6: *reinterpret_cast<int*>(_v) = _t->assetNumber(); break;
        case 7: *reinterpret_cast<QVariantList*>(_v) = _t->assetPath(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 6: _t->setAssetNumber(*reinterpret_cast<int*>(_v)); break;
        case 7: _t->setAssetPath(*reinterpret_cast<QVariantList*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *Game::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *Game::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4GameE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int Game::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 18)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 18;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 18)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 18;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 8;
    }
    return _id;
}

// SIGNAL 0
void Game::gameStarted()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void Game::playersChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void Game::currentPlayerIndexChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void Game::propertyPurchased(int _t1, Player * _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 3, nullptr, _t1, _t2);
}

// SIGNAL 4
void Game::assetNumberChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void Game::assetPathChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}
QT_WARNING_POP
