#include "appinfo.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>

#ifdef Q_OS_ANDROID
const QString appVersionName(APP_VERSION_NAME);
const QString appVersionCode(APP_VERSION_CODE);
#endif

AppInfo *AppInfo::m_pThis = nullptr;

AppInfo::AppInfo(QObject *parent)
    : QObject(parent)
{}

void AppInfo::registerQml()
{
    qmlRegisterSingletonType<AppInfo>("AppInfo", 1, 0, "AppInfo", &AppInfo::qmlInstance);
}

AppInfo *AppInfo::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new AppInfo;
    }
    return m_pThis;
}

QObject *AppInfo::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return AppInfo::instance();
}

QString AppInfo::name() const
{
    return m_name;
}

void AppInfo::setName(const QString &newName)
{
    if (m_name == newName)
        return;
    m_name = newName;
    emit nameChanged();
}

QString AppInfo::getVersionName()
{
#ifdef Q_OS_ANDROID
    return appVersionName;
#else
    return "NOTANDROID";
#endif
}

QString AppInfo::getVersionNumber()
{
#ifdef Q_OS_ANDROID
    return APP_VERSION_CODE;
#else
    return "NOTANDROID";
#endif
}
