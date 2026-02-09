#ifndef TEST_MANAGER_H
#define TEST_MANAGER_H

#include <QObject>
#include <QQmlEngine>
#include "server_manager.h"

class TestManager : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static TestManager *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE void testAction1();
    Q_INVOKABLE void testAction2();
    Q_INVOKABLE void testAction3();
    Q_INVOKABLE void testAction4();
    Q_INVOKABLE void testUdpServer();
    Q_INVOKABLE void testSendStun();

private:
    explicit TestManager(QObject *parent = nullptr);
    static TestManager *m_instance;
    ServerManager *m_serverManager;
};

#endif // TEST_MANAGER_H
