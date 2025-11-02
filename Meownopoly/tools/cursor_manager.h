#ifndef CURSOR_MANAGER_H
#define CURSOR_MANAGER_H

#include <QObject>
#include <QQmlEngine>
#include <QPoint>

class CursorManager : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static CursorManager *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

public slots:
    // Déplacer le curseur à une position spécifique (coordonnées globales)
    Q_INVOKABLE void setPos(int x, int y);
    // Déplacer le curseur à une position spécifique (avec QPoint)
    Q_INVOKABLE void setPosPoint(const QPoint &point);

signals:

private slots:

private:
    explicit CursorManager(QObject *parent = nullptr);
    static CursorManager *m_pThis;
};

#endif // CURSOR_MANAGER_H

