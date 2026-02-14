#include "test_manager.h"
#include "logger.h"
#include <QDebug>

TestManager *TestManager::m_instance = nullptr;

TestManager::TestManager(QObject *parent) : QObject(parent), m_stunManager(nullptr)
{
}

void TestManager::registerQml()
{
    qmlRegisterSingletonType<TestManager>("utils", 1, 0, "TestManager", TestManager::qmlInstance);
}

TestManager *TestManager::instance()
{
    if (!m_instance) {
        m_instance = new TestManager();
    }
    return m_instance;
}

QObject *TestManager::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    return instance();
}

void TestManager::testAction1()
{
    Logger::instance()->info("Test Action 1 executed from C++", "TestManager");
    qDebug() << "Test Action 1 executed";
}

void TestManager::testAction2()
{
    Logger::instance()->success("Test Action 2 executed from C++", "TestManager");
    qDebug() << "Test Action 2 executed";
}

void TestManager::testAction3()
{
    Logger::instance()->warn("Test Action 3 executed from C++", "TestManager");
    qDebug() << "Test Action 3 executed";
}

void TestManager::testAction4()
{
    Logger::instance()->error("Test Action 4 executed from C++", "TestManager");
    qDebug() << "Test Action 4 executed";
}

void TestManager::testUdpServer()
{
    if (!m_stunManager) {
        m_stunManager = new StunManager(this);
        connect(m_stunManager, &StunManager::log, [](QString msg){
            Logger::instance()->info(msg, "StunManager");
            // qDebug() << "[StunManager]" << msg;
        });
    }
    m_stunManager->startServer();
}

void TestManager::testSendStun()
{
    if (m_stunManager) {
        m_stunManager->sendStunRequest();
    } else {
        Logger::instance()->warn("Server not started. Start UDP Server first.", "TestManager");
    }
}

void TestManager::testSetStunServer(QString ip, int port)
{
    if (m_stunManager) {
        m_stunManager->setStunServer(ip, (quint16)port);
    } else {
        // Need to create it if not exists, though usually startServer is called first. 
        // But for config it makes sense to create it.
        m_stunManager = new StunManager(this);
        connect(m_stunManager, &StunManager::log, [](QString msg){
             Logger::instance()->info(msg, "StunManager");
             // qDebug() << "[StunManager]" << msg;
        });
        m_stunManager->setStunServer(ip, (quint16)port);
    }
}

void TestManager::testSetPeer(QString ip, int port)
{
    if (m_stunManager) {
        m_stunManager->setPeer(ip, (quint16)port);
    }
}

void TestManager::testSendMessage(QString message)
{
    if (m_stunManager) {
        m_stunManager->sendMessageToPeer(message);
    }
}
