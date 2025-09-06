#include "editorenum.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>

EditorEnum *EditorEnum::m_pThis = nullptr;

EditorEnum::EditorEnum(QObject *parent)
    : QObject(parent)
{}

void EditorEnum::registerQml()
{
    qmlRegisterSingletonType<EditorEnum>("EditorEnum", 1, 0, "EditorEnum", &EditorEnum::qmlInstance);
    qmlRegisterType<EditorMouseMode>("EditorEnum", 1, 0, "EditorMouseMode");

}

EditorEnum *EditorEnum::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new EditorEnum;
    }
    return m_pThis;
}

QObject *EditorEnum::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return EditorEnum::instance();
}
