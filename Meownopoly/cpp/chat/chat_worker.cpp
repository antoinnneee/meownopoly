#include "chat_worker.h"
#include <QDebug>
#include <QThread>

ChatWorker::ChatWorker(QObject *parent)
    : QObject(parent)
    , m_webSocket(nullptr)
{
    qDebug() << "[ChatWorker] Created in thread:" << QThread::currentThread();
}

ChatWorker::~ChatWorker()
{
    if (m_webSocket) {
        if (m_webSocket->state() == QAbstractSocket::ConnectedState) {
            m_webSocket->close();
        }
        m_webSocket->deleteLater();
    }
    qDebug() << "[ChatWorker] Destroyed";
}

void ChatWorker::connectToServer(const QString &url)
{
    qDebug() << "[ChatWorker] connectToServer called in thread:" << QThread::currentThread();
    
    if (!m_webSocket) {
        m_webSocket = new QWebSocket();
        
        connect(m_webSocket, &QWebSocket::connected, this, &ChatWorker::onConnected);
        connect(m_webSocket, &QWebSocket::disconnected, this, &ChatWorker::onDisconnected);
        connect(m_webSocket, &QWebSocket::textMessageReceived, this, &ChatWorker::onTextMessageReceived);
        connect(m_webSocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
                this, &ChatWorker::onError);
    }
    
    if (m_webSocket->state() == QAbstractSocket::ConnectedState) {
        qDebug() << "[ChatWorker] Already connected, disconnecting first";
        m_webSocket->close();
    }
    
    qDebug() << "[ChatWorker] Connecting to:" << url;
    m_webSocket->open(QUrl(url));
}

void ChatWorker::sendTextMessage(const QString &message)
{
    if (!m_webSocket) {
        qWarning() << "[ChatWorker] Cannot send message: WebSocket not initialized";
        return;
    }
    
    if (m_webSocket->state() != QAbstractSocket::ConnectedState) {
        qWarning() << "[ChatWorker] Cannot send message: Not connected";
        return;
    }
    
    qDebug() << "[ChatWorker] Sending message in thread:" << QThread::currentThread();
    m_webSocket->sendTextMessage(message);
}

void ChatWorker::disconnectFromServer()
{
    qDebug() << "[ChatWorker] disconnectFromServer called";
    if (m_webSocket && m_webSocket->state() == QAbstractSocket::ConnectedState) {
        m_webSocket->close();
    }
}

void ChatWorker::onConnected()
{
    qDebug() << "[ChatWorker] Connected to server in thread:" << QThread::currentThread();
    emit connected();
}

void ChatWorker::onDisconnected()
{
    qDebug() << "[ChatWorker] Disconnected from server";
    emit disconnected();
}

void ChatWorker::onTextMessageReceived(const QString &message)
{
    qDebug() << "[ChatWorker] Message received in thread:" << QThread::currentThread();
    emit textMessageReceived(message);
}

void ChatWorker::onError(QAbstractSocket::SocketError error)
{
    QString errorString = m_webSocket ? m_webSocket->errorString() : "Unknown error";
    qWarning() << "[ChatWorker] WebSocket error:" << error << errorString;
    emit errorOccurred(errorString);
}

