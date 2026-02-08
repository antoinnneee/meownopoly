#include "uistyle.h"


UiStyle *UiStyle::m_pThis = nullptr;

UiStyle::UiStyle() {}

void UiStyle::registerQml() {
    qmlRegisterSingletonType<UiStyle>("UiStyle", 1, 0, "UiStyle", &UiStyle::qmlInstance);
}

UiStyle *UiStyle::instance() {
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new UiStyle;
    }
    return m_pThis;
}

QObject *UiStyle::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine) {
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return UiStyle::instance();
}

int UiStyle::z_CONFIG_PANEL() const
{
    return m_z_CONFIG_PANEL;
}

int UiStyle::z_HUD() const
{
    return m_z_HUD;
}

int UiStyle::z_SELECTION_RECT() const
{
    return m_z_SELECTION_RECT;
}

int UiStyle::z_TEMPLATE_PREVIEW() const
{
    return m_z_TEMPLATE_PREVIEW;
}

int UiStyle::z_CURSOR_TRACKER() const
{
    return m_z_CURSOR_TRACKER;
}

int UiStyle::z_LINK_TRACKER() const
{
    return m_z_LINK_TRACKER;
}

int UiStyle::z_WORKAREA() const
{
    return m_z_WORKAREA;
}

int UiStyle::z_BACKGROUND() const
{
    return m_z_BACKGROUND;
}

int UiStyle::z_GRID() const
{
    return m_z_GRID;
}

int UiStyle::z_GLOBAL_MA () const
{
    return m_z_GLOBAL_MA;
}

int UiStyle::z_CHAT_DRAWER() const
{
    return m_z_CHAT_DRAWER;
}

