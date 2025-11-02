#include "cursor_manager.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QCursor>
#include <QDebug>

CursorManager *CursorManager::m_pThis = nullptr;

CursorManager::CursorManager(QObject *parent)
    : QObject(parent)
{}

void CursorManager::registerQml()
{
    qmlRegisterSingletonType<CursorManager>("CursorManager", 1, 0, "CursorManager", &CursorManager::qmlInstance);
}

CursorManager *CursorManager::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new CursorManager;
    }
    return m_pThis;
}

QObject *CursorManager::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return CursorManager::instance();
}

void CursorManager::setPos(int x, int y)
{
    QCursor::setPos(x, y);
    qDebug() << "[CURSOR_MANAGER] Curseur déplacé à (" << x << ", " << y << ")";
}

void CursorManager::setPosPoint(const QPoint &point)
{
    QCursor::setPos(point);
    qDebug() << "[CURSOR_MANAGER] Curseur déplacé à" << point;
}

