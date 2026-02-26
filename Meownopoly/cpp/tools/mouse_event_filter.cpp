#include "mouse_event_filter.h"

#include <QEvent>
#include <QMouseEvent>
#include <QSettings>
#include <QCursor>
#include <QGuiApplication>

MouseEventFilter* MouseEventFilter::m_pThis = nullptr;

MouseEventFilter::MouseEventFilter(QObject *parent)
    : QObject(parent)
    , m_isFirstMove(true)
    , m_isInternalPosChange(false)
{
}

MouseEventFilter* MouseEventFilter::instance()
{
    if (!m_pThis) {
        m_pThis = new MouseEventFilter(qApp);
    }
    return m_pThis;
}

bool MouseEventFilter::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::MouseMove) {
        // Avoid infinite loop during internal setPos
        if (m_isInternalPosChange) {
            m_isInternalPosChange = false;
            return false;
        }

        QMouseEvent *mouseEvent = static_cast<QMouseEvent*>(event);
        QPoint globalPos = QCursor::pos();

        if (m_isFirstMove) {
            m_lastPos = globalPos;
            m_isFirstMove = false;
            return false;
        }

        // Only scale if we moved from last known position
        if (globalPos != m_lastPos) {
            QSettings settings;
            settings.beginGroup("Controls");
            double sensitivity = settings.value("mouseSensitivity", 1.0).toDouble();
            bool invertY = settings.value("invertMouseY", false).toBool();
            settings.endGroup();

            // We calculate the delta from the real OS movement
            QPoint delta = globalPos - m_lastPos;
            
            // If settings are default, just update lastPos and continue
            if (sensitivity == 1.0 && !invertY) {
                m_lastPos = globalPos;
                return false;
            }

            // Calculate new position
            int dx = static_cast<int>(delta.x() * sensitivity);
            int dy = static_cast<int>(delta.y() * sensitivity);
            
            if (invertY) {
                dy = -dy;
            }

            QPoint newGlobalPos = m_lastPos + QPoint(dx, dy);

            // Update state before moving to prevent loop
            m_lastPos = newGlobalPos;
            m_isInternalPosChange = true;
            
            QCursor::setPos(newGlobalPos);
            
            // Consume the original event to prevent "doubling" or erratic jumps
            return true;
        }
    } else if (event->type() == QEvent::Enter || event->type() == QEvent::WindowActivate) {
        // Reset tracking when entering window or activating to prevent huge deltas
        m_isFirstMove = true;
    }

    return QObject::eventFilter(obj, event);
}
