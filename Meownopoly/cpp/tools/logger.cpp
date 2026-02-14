#include "logger.h"
#include "debug_info.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QDebug>

Logger *Logger::m_pThis = nullptr;

Logger::Logger(QObject *parent)
    : QObject(parent)
{}

void Logger::registerQml()
{
    qmlRegisterSingletonType<Logger>("Logger", 1, 0, "Logger", &Logger::qmlInstance);
}

Logger *Logger::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new Logger;
    }
    return m_pThis;
}

QObject *Logger::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return Logger::instance();
}

void Logger::log(const QString &message)
{
    logMessage("INFO", message, QString("LOG"), "");
}

void Logger::info(const QString &message, const QString &category)
{
#if LOG_LEVEL_INFO
    logMessage("INFO", message, category, DBG_CLR_BLUE);
#endif
}

void Logger::debug(const QString &message, const QString &category)
{
#if LOG_LEVEL_DEBUG
    logMessage("DEBUG", message, category, "");
#endif
}

void Logger::warn(const QString &message, const QString &category)
{
#if LOG_LEVEL_WARN
    logMessage("WARN", message, category, DBG_CLR_YELLOW);
#endif
}

void Logger::error(const QString &message, const QString &category)
{
#if LOG_LEVEL_ERROR
    logMessage("ERROR", message, category, DBG_CLR_RED);
#endif
}

void Logger::success(const QString &message, const QString &category)
{
#if LOG_LEVEL_SUCCESS
    logMessage("SUCCESS", message, category, DBG_CLR_GREEN);
#endif
}

void Logger::logMessage(const QString &level, const QString &message, const QString &category, const QString &color)
{
    Q_UNUSED(level)
    QString formattedMessage;
    if (!category.isEmpty()) {
        formattedMessage = QString("[%1] %2").arg(category, message);
    } else {
        formattedMessage = message;
    }
    
    qDebug().noquote() << color << formattedMessage << DBG_CLR_RESET;
}
