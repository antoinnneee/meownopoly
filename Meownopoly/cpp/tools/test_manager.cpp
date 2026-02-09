#include "test_manager.h"
#include "logger.h"
#include <QDebug>

TestManager *TestManager::m_instance = nullptr;

TestManager::TestManager(QObject *parent) : QObject(parent)
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
