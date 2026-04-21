/****************************************************************************
** Meta object code from reading C++ file 'chat_client.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.10.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../Meownopoly/cpp/chat/chat_client.h"
#include <QtNetwork/QSslPreSharedKeyAuthenticator>
#include <QtNetwork/QSslError>
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'chat_client.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN10ChatClientE_t {};
} // unnamed namespace

template <> constexpr inline auto ChatClient::qt_create_metaobjectdata<qt_meta_tag_ZN10ChatClientE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "ChatClient",
        "connectedChanged",
        "",
        "sessionIdChanged",
        "messagesChanged",
        "participantsChanged",
        "participantJoined",
        "playerId",
        "playerNickname",
        "participantLeft",
        "errorOccurred",
        "error",
        "ChatClient::ErrorSession",
        "errorType",
        "availableSessionsChanged",
        "pingMsChanged",
        "commandReceived",
        "senderId",
        "commandType",
        "QJsonObject",
        "data",
        "sessionCreated",
        "sessionId",
        "sessionName",
        "sessionCreatedBroadcast",
        "sessionRenamed",
        "hostChanged",
        "hostPlayerId",
        "kicked",
        "reason",
        "participantKicked",
        "sessionEnded",
        "leftSession",
        "serverReset",
        "message",
        "onConnected",
        "onDisconnected",
        "onTextMessageReceived",
        "onWorkerError",
        "onPongReceived",
        "elapsedMs",
        "connectToServer",
        "url",
        "createSession",
        "nameSession",
        "pwdSession",
        "idSession",
        "renameSession",
        "newName",
        "transferHost",
        "newHostId",
        "connectToSessionDirect",
        "password",
        "connectToSession",
        "nickname",
        "joinSession",
        "sendMessage",
        "text",
        "recipientId",
        "recipientNickname",
        "sendImage",
        "filePath",
        "sendTextFile",
        "saveTextToFile",
        "content",
        "loadHistory",
        "requestHistory",
        "beforeId",
        "clearHistory",
        "saveImageToFile",
        "imageId",
        "copyImageToClipboard",
        "requestParticipants",
        "requestSessionsList",
        "kickPlayer",
        "targetPlayerId",
        "sendPing",
        "sendRequestConnectionInfo",
        "ip",
        "port",
        "localPort",
        "sendShareConnection",
        "sendCommand",
        "connected",
        "messages",
        "QVariantList",
        "participants",
        "participantCount",
        "availableSessions",
        "pingMs",
        "ErrorSession",
        "SESSION_DOES_NOT_EXIST",
        "INVALID_PASSWORD",
        "OTHER"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'connectedChanged'
        QtMocHelpers::SignalData<void()>(1, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'sessionIdChanged'
        QtMocHelpers::SignalData<void()>(3, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'messagesChanged'
        QtMocHelpers::SignalData<void()>(4, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'participantsChanged'
        QtMocHelpers::SignalData<void()>(5, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'participantJoined'
        QtMocHelpers::SignalData<void(const QString &, const QString &)>(6, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::QString, 8 },
        }}),
        // Signal 'participantLeft'
        QtMocHelpers::SignalData<void(const QString &)>(9, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 7 },
        }}),
        // Signal 'errorOccurred'
        QtMocHelpers::SignalData<void(const QString &, ChatClient::ErrorSession)>(10, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 11 }, { 0x80000000 | 12, 13 },
        }}),
        // Signal 'errorOccurred'
        QtMocHelpers::SignalData<void(const QString &)>(10, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 11 },
        }}),
        // Signal 'availableSessionsChanged'
        QtMocHelpers::SignalData<void()>(14, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'pingMsChanged'
        QtMocHelpers::SignalData<void()>(15, 2, QMC::AccessPublic, QMetaType::Void),
        // Signal 'commandReceived'
        QtMocHelpers::SignalData<void(const QString &, const QString &, const QJsonObject &)>(16, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 17 }, { QMetaType::QString, 18 }, { 0x80000000 | 19, 20 },
        }}),
        // Signal 'sessionCreated'
        QtMocHelpers::SignalData<void(const QString &, const QString &)>(21, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 22 }, { QMetaType::QString, 23 },
        }}),
        // Signal 'sessionCreatedBroadcast'
        QtMocHelpers::SignalData<void(const QString &, const QString &)>(24, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 22 }, { QMetaType::QString, 23 },
        }}),
        // Signal 'sessionRenamed'
        QtMocHelpers::SignalData<void(const QString &, const QString &)>(25, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 22 }, { QMetaType::QString, 23 },
        }}),
        // Signal 'hostChanged'
        QtMocHelpers::SignalData<void(const QString &, const QString &)>(26, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 22 }, { QMetaType::QString, 27 },
        }}),
        // Signal 'kicked'
        QtMocHelpers::SignalData<void(const QString &, const QString &)>(28, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 22 }, { QMetaType::QString, 29 },
        }}),
        // Signal 'participantKicked'
        QtMocHelpers::SignalData<void(const QString &, const QString &)>(30, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 22 }, { QMetaType::QString, 7 },
        }}),
        // Signal 'sessionEnded'
        QtMocHelpers::SignalData<void(const QString &, const QString &)>(31, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 22 }, { QMetaType::QString, 29 },
        }}),
        // Signal 'leftSession'
        QtMocHelpers::SignalData<void(const QString &)>(32, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 22 },
        }}),
        // Signal 'serverReset'
        QtMocHelpers::SignalData<void(const QString &)>(33, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 34 },
        }}),
        // Slot 'onConnected'
        QtMocHelpers::SlotData<void()>(35, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onDisconnected'
        QtMocHelpers::SlotData<void()>(36, 2, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onTextMessageReceived'
        QtMocHelpers::SlotData<void(const QString &)>(37, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 34 },
        }}),
        // Slot 'onWorkerError'
        QtMocHelpers::SlotData<void(const QString &)>(38, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::QString, 11 },
        }}),
        // Slot 'onPongReceived'
        QtMocHelpers::SlotData<void(quint64)>(39, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::ULongLong, 40 },
        }}),
        // Method 'connectToServer'
        QtMocHelpers::MethodData<void(const QString &)>(41, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 42 },
        }}),
        // Method 'createSession'
        QtMocHelpers::MethodData<void(QString, QString, QString)>(43, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 44 }, { QMetaType::QString, 45 }, { QMetaType::QString, 46 },
        }}),
        // Method 'createSession'
        QtMocHelpers::MethodData<void(QString, QString)>(43, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 44 }, { QMetaType::QString, 45 },
        }}),
        // Method 'renameSession'
        QtMocHelpers::MethodData<void(const QString &)>(47, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 48 },
        }}),
        // Method 'transferHost'
        QtMocHelpers::MethodData<void(const QString &)>(49, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 50 },
        }}),
        // Method 'connectToSessionDirect'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(51, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 22 }, { QMetaType::QString, 52 },
        }}),
        // Method 'connectToSession'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &)>(53, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::QString, 52 }, { QMetaType::QString, 54 },
        }}),
        // Method 'connectToSession'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(53, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 7 }, { QMetaType::QString, 52 },
        }}),
        // Method 'joinSession'
        QtMocHelpers::MethodData<void()>(55, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'sendMessage'
        QtMocHelpers::MethodData<void(const QString &, const QString &, const QString &)>(56, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 57 }, { QMetaType::QString, 58 }, { QMetaType::QString, 59 },
        }}),
        // Method 'sendMessage'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(56, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 57 }, { QMetaType::QString, 58 },
        }}),
        // Method 'sendMessage'
        QtMocHelpers::MethodData<void(const QString &)>(56, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 57 },
        }}),
        // Method 'sendImage'
        QtMocHelpers::MethodData<void(const QString &)>(60, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 61 },
        }}),
        // Method 'sendTextFile'
        QtMocHelpers::MethodData<void(const QString &)>(62, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 61 },
        }}),
        // Method 'saveTextToFile'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(63, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 61 }, { QMetaType::QString, 64 },
        }}),
        // Method 'loadHistory'
        QtMocHelpers::MethodData<void()>(65, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'requestHistory'
        QtMocHelpers::MethodData<void(int)>(66, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::Int, 67 },
        }}),
        // Method 'requestHistory'
        QtMocHelpers::MethodData<void()>(66, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void),
        // Method 'clearHistory'
        QtMocHelpers::MethodData<void()>(68, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'saveImageToFile'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(69, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 70 }, { QMetaType::QString, 61 },
        }}),
        // Method 'copyImageToClipboard'
        QtMocHelpers::MethodData<void(const QString &)>(71, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 70 },
        }}),
        // Method 'requestParticipants'
        QtMocHelpers::MethodData<void()>(72, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'requestSessionsList'
        QtMocHelpers::MethodData<void()>(73, 2, QMC::AccessPublic, QMetaType::Void),
        // Method 'kickPlayer'
        QtMocHelpers::MethodData<void(const QString &)>(74, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 75 },
        }}),
        // Method 'sendPing'
        QtMocHelpers::MethodData<void(const QString &)>(76, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 75 },
        }}),
        // Method 'sendPing'
        QtMocHelpers::MethodData<void()>(76, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void),
        // Method 'sendRequestConnectionInfo'
        QtMocHelpers::MethodData<void(const QString &, const QString &, quint16, quint16)>(77, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 58 }, { QMetaType::QString, 78 }, { QMetaType::UShort, 79 }, { QMetaType::UShort, 80 },
        }}),
        // Method 'sendRequestConnectionInfo'
        QtMocHelpers::MethodData<void(const QString &, const QString &, quint16)>(77, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 58 }, { QMetaType::QString, 78 }, { QMetaType::UShort, 79 },
        }}),
        // Method 'sendRequestConnectionInfo'
        QtMocHelpers::MethodData<void(const QString &, const QString &)>(77, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 58 }, { QMetaType::QString, 78 },
        }}),
        // Method 'sendRequestConnectionInfo'
        QtMocHelpers::MethodData<void(const QString &)>(77, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 58 },
        }}),
        // Method 'sendRequestConnectionInfo'
        QtMocHelpers::MethodData<void()>(77, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void),
        // Method 'sendShareConnection'
        QtMocHelpers::MethodData<void(const QString &)>(81, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 58 },
        }}),
        // Method 'sendShareConnection'
        QtMocHelpers::MethodData<void()>(81, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void),
        // Method 'sendCommand'
        QtMocHelpers::MethodData<void(const QString &, const QJsonObject &, const QString &)>(82, 2, QMC::AccessPublic, QMetaType::Void, {{
            { QMetaType::QString, 18 }, { 0x80000000 | 19, 20 }, { QMetaType::QString, 58 },
        }}),
        // Method 'sendCommand'
        QtMocHelpers::MethodData<void(const QString &, const QJsonObject &)>(82, 2, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Void, {{
            { QMetaType::QString, 18 }, { 0x80000000 | 19, 20 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'connected'
        QtMocHelpers::PropertyData<bool>(83, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'sessionId'
        QtMocHelpers::PropertyData<QString>(22, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'messages'
        QtMocHelpers::PropertyData<QVariantList>(84, 0x80000000 | 85, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 2),
        // property 'participants'
        QtMocHelpers::PropertyData<QVariantList>(86, 0x80000000 | 85, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 3),
        // property 'participantCount'
        QtMocHelpers::PropertyData<int>(87, QMetaType::Int, QMC::DefaultPropertyFlags, 3),
        // property 'availableSessions'
        QtMocHelpers::PropertyData<QVariantList>(88, 0x80000000 | 85, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 8),
        // property 'pingMs'
        QtMocHelpers::PropertyData<int>(89, QMetaType::Int, QMC::DefaultPropertyFlags, 9),
    };
    QtMocHelpers::UintData qt_enums {
        // enum 'ErrorSession'
        QtMocHelpers::EnumData<enum ErrorSession>(90, 90, QMC::EnumFlags{}).add({
            {   91, ErrorSession::SESSION_DOES_NOT_EXIST },
            {   92, ErrorSession::INVALID_PASSWORD },
            {   93, ErrorSession::OTHER },
        }),
    };
    return QtMocHelpers::metaObjectData<ChatClient, qt_meta_tag_ZN10ChatClientE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject ChatClient::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN10ChatClientE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN10ChatClientE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN10ChatClientE_t>.metaTypes,
    nullptr
} };

void ChatClient::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<ChatClient *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->connectedChanged(); break;
        case 1: _t->sessionIdChanged(); break;
        case 2: _t->messagesChanged(); break;
        case 3: _t->participantsChanged(); break;
        case 4: _t->participantJoined((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 5: _t->participantLeft((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 6: _t->errorOccurred((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<ChatClient::ErrorSession>>(_a[2]))); break;
        case 7: _t->errorOccurred((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 8: _t->availableSessionsChanged(); break;
        case 9: _t->pingMsChanged(); break;
        case 10: _t->commandReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[3]))); break;
        case 11: _t->sessionCreated((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 12: _t->sessionCreatedBroadcast((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 13: _t->sessionRenamed((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 14: _t->hostChanged((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 15: _t->kicked((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 16: _t->participantKicked((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 17: _t->sessionEnded((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 18: _t->leftSession((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 19: _t->serverReset((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 20: _t->onConnected(); break;
        case 21: _t->onDisconnected(); break;
        case 22: _t->onTextMessageReceived((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 23: _t->onWorkerError((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 24: _t->onPongReceived((*reinterpret_cast<std::add_pointer_t<quint64>>(_a[1]))); break;
        case 25: _t->connectToServer((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 26: _t->createSession((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 27: _t->createSession((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 28: _t->renameSession((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 29: _t->transferHost((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 30: _t->connectToSessionDirect((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 31: _t->connectToSession((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 32: _t->connectToSession((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 33: _t->joinSession(); break;
        case 34: _t->sendMessage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 35: _t->sendMessage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 36: _t->sendMessage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 37: _t->sendImage((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 38: _t->sendTextFile((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 39: _t->saveTextToFile((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 40: _t->loadHistory(); break;
        case 41: _t->requestHistory((*reinterpret_cast<std::add_pointer_t<int>>(_a[1]))); break;
        case 42: _t->requestHistory(); break;
        case 43: _t->clearHistory(); break;
        case 44: _t->saveImageToFile((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 45: _t->copyImageToClipboard((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 46: _t->requestParticipants(); break;
        case 47: _t->requestSessionsList(); break;
        case 48: _t->kickPlayer((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 49: _t->sendPing((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 50: _t->sendPing(); break;
        case 51: _t->sendRequestConnectionInfo((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[4]))); break;
        case 52: _t->sendRequestConnectionInfo((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<quint16>>(_a[3]))); break;
        case 53: _t->sendRequestConnectionInfo((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[2]))); break;
        case 54: _t->sendRequestConnectionInfo((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 55: _t->sendRequestConnectionInfo(); break;
        case 56: _t->sendShareConnection((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1]))); break;
        case 57: _t->sendShareConnection(); break;
        case 58: _t->sendCommand((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[3]))); break;
        case 59: _t->sendCommand((*reinterpret_cast<std::add_pointer_t<QString>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QJsonObject>>(_a[2]))); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)()>(_a, &ChatClient::connectedChanged, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)()>(_a, &ChatClient::sessionIdChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)()>(_a, &ChatClient::messagesChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)()>(_a, &ChatClient::participantsChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , const QString & )>(_a, &ChatClient::participantJoined, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & )>(_a, &ChatClient::participantLeft, 5))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , ChatClient::ErrorSession )>(_a, &ChatClient::errorOccurred, 6))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)()>(_a, &ChatClient::availableSessionsChanged, 8))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)()>(_a, &ChatClient::pingMsChanged, 9))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , const QString & , const QJsonObject & )>(_a, &ChatClient::commandReceived, 10))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , const QString & )>(_a, &ChatClient::sessionCreated, 11))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , const QString & )>(_a, &ChatClient::sessionCreatedBroadcast, 12))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , const QString & )>(_a, &ChatClient::sessionRenamed, 13))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , const QString & )>(_a, &ChatClient::hostChanged, 14))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , const QString & )>(_a, &ChatClient::kicked, 15))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , const QString & )>(_a, &ChatClient::participantKicked, 16))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & , const QString & )>(_a, &ChatClient::sessionEnded, 17))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & )>(_a, &ChatClient::leftSession, 18))
            return;
        if (QtMocHelpers::indexOfMethod<void (ChatClient::*)(const QString & )>(_a, &ChatClient::serverReset, 19))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<bool*>(_v) = _t->isConnected(); break;
        case 1: *reinterpret_cast<QString*>(_v) = _t->sessionId(); break;
        case 2: *reinterpret_cast<QVariantList*>(_v) = _t->messages(); break;
        case 3: *reinterpret_cast<QVariantList*>(_v) = _t->participants(); break;
        case 4: *reinterpret_cast<int*>(_v) = _t->participantCount(); break;
        case 5: *reinterpret_cast<QVariantList*>(_v) = _t->availableSessions(); break;
        case 6: *reinterpret_cast<int*>(_v) = _t->pingMs(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 1: _t->setSessionId(*reinterpret_cast<QString*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *ChatClient::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *ChatClient::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN10ChatClientE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int ChatClient::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 60)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 60;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 60)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 60;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 7;
    }
    return _id;
}

// SIGNAL 0
void ChatClient::connectedChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void ChatClient::sessionIdChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void ChatClient::messagesChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void ChatClient::participantsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void ChatClient::participantJoined(const QString & _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 4, nullptr, _t1, _t2);
}

// SIGNAL 5
void ChatClient::participantLeft(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 5, nullptr, _t1);
}

// SIGNAL 6
void ChatClient::errorOccurred(const QString & _t1, ChatClient::ErrorSession _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 6, nullptr, _t1, _t2);
}

// SIGNAL 8
void ChatClient::availableSessionsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 8, nullptr);
}

// SIGNAL 9
void ChatClient::pingMsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 9, nullptr);
}

// SIGNAL 10
void ChatClient::commandReceived(const QString & _t1, const QString & _t2, const QJsonObject & _t3)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 10, nullptr, _t1, _t2, _t3);
}

// SIGNAL 11
void ChatClient::sessionCreated(const QString & _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 11, nullptr, _t1, _t2);
}

// SIGNAL 12
void ChatClient::sessionCreatedBroadcast(const QString & _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 12, nullptr, _t1, _t2);
}

// SIGNAL 13
void ChatClient::sessionRenamed(const QString & _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 13, nullptr, _t1, _t2);
}

// SIGNAL 14
void ChatClient::hostChanged(const QString & _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 14, nullptr, _t1, _t2);
}

// SIGNAL 15
void ChatClient::kicked(const QString & _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 15, nullptr, _t1, _t2);
}

// SIGNAL 16
void ChatClient::participantKicked(const QString & _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 16, nullptr, _t1, _t2);
}

// SIGNAL 17
void ChatClient::sessionEnded(const QString & _t1, const QString & _t2)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 17, nullptr, _t1, _t2);
}

// SIGNAL 18
void ChatClient::leftSession(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 18, nullptr, _t1);
}

// SIGNAL 19
void ChatClient::serverReset(const QString & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 19, nullptr, _t1);
}
QT_WARNING_POP
