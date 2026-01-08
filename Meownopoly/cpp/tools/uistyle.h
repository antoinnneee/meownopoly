#ifndef UISTYLE_H
#define UISTYLE_H

#include <QObject>
#include <qqml.h>

class UiStyle : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int z_CONFIG_PANEL READ z_CONFIG_PANEL CONSTANT FINAL)
    Q_PROPERTY(int z_HUD READ z_HUD CONSTANT FINAL)
    Q_PROPERTY(int z_SELECTION_RECT READ z_SELECTION_RECT CONSTANT FINAL)
    Q_PROPERTY(int z_CURSOR_TRACKER READ z_CURSOR_TRACKER CONSTANT FINAL)
    Q_PROPERTY(int z_LINK_TRACKER READ z_LINK_TRACKER CONSTANT FINAL)
    Q_PROPERTY(int z_WORKAREA READ z_WORKAREA CONSTANT FINAL)

    Q_PROPERTY(int z_BACKGROUND READ z_BACKGROUND CONSTANT FINAL)
    Q_PROPERTY(int z_GRID READ z_GRID CONSTANT FINAL)
    Q_PROPERTY(int z_GLOBAL_MA READ z_GLOBAL_MA CONSTANT FINAL)

public:

    UiStyle();

    static void registerQml();

    int z_CONFIG_PANEL() const;

    int z_HUD() const;

    int z_SELECTION_RECT() const;

    int z_CURSOR_TRACKER() const;

    int z_LINK_TRACKER() const;

    int z_WORKAREA() const;

    int z_BACKGROUND() const;

    int z_GRID() const;

    int z_GLOBAL_MA() const;

private:
    int m_z_CONFIG_PANEL = 10000;
    int m_z_HUD = 9000;
    int m_z_SELECTION_RECT = 8000;
    int m_z_CURSOR_TRACKER = 7000;
    int m_z_LINK_TRACKER = 6000;
    int m_z_WORKAREA = 5000;

    int m_z_BACKGROUND = 4000;
    int m_z_GRID = 3000;
    int m_z_GLOBAL_MA = 2000;

};

#endif // UISTYLE_H
