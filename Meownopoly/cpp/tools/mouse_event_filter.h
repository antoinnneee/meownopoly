#ifndef __MOUSE_EVENT_FILTER_H
#define __MOUSE_EVENT_FILTER_H

#include <QObject>
#include <QPoint>

/**
 * @brief Global event filter to handle mouse sensitivity and inversion.
 * Intercepts mouse move events at the application level to scale movement.
 */
class MouseEventFilter : public QObject
{
    Q_OBJECT

public:
    explicit MouseEventFilter(QObject *parent = nullptr);
    static MouseEventFilter* instance();

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;

private:
    static MouseEventFilter* m_pThis;
    QPoint m_lastPos;
    bool m_isFirstMove;
    bool m_isInternalPosChange;
};

#endif // __MOUSE_EVENT_FILTER_H
