#include "uistyle.h"

UiStyle::UiStyle() {}

void UiStyle::registerQml(){
    qmlRegisterType<UiStyle>("UiStyle", 1, 0, "UiStyle");
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
