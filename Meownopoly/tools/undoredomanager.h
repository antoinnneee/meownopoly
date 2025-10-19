#ifndef UNDOREDOMANAGER_H
#define UNDOREDOMANAGER_H

#include <QObject>
#include "qqmlengine.h"
#include "qtmetamacros.h"
#include <QJsonObject>

class UndoRedoManager : public QObject
{
    Q_OBJECT
public:

    enum EditAction{
        CtrlZ,
        CtrlY
    };

    Q_ENUM(EditAction)

    UndoRedoManager();

    // explicit UndoRedoManager(QObject *parent = nullptr);

    static UndoRedoManager* instance();
    static QObject* qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static void registerQml();

signals:

    void returnEdit(QJsonObject editAction);

public slots:

    void onUpdateListEdits(QJsonObject newEdit);
    void onAskEdit(EditAction editAction);

private :
    static UndoRedoManager *m_instance;

    inline static int m_currentEditIndex = 0;
    QList <QJsonObject> listEdits;
};

#endif // UNDOREDOMANAGER_H
