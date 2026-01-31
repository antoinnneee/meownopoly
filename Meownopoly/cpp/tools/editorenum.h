#ifndef EDITORENUM_H
#define EDITORENUM_H

#include <QObject>
#include <QQmlEngine>

class EditorEnum : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static EditorEnum *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);


    enum EditorMouseMode {
        EM_NORMAL,
        EM_POSE,
        EM_SELECTION_LINK,
        EM_TEMPLATE,
        EM_GAME,
        EM_DRAW_POLYGON,
    };
    Q_ENUM(EditorMouseMode)

public slots:

signals:

private slots:

private:
    explicit EditorEnum(QObject *parent = nullptr);
    static EditorEnum *m_pThis;
};

#endif // EDITORENUM_H
