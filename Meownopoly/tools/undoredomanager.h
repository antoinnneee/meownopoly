#ifndef UNDOREDOMANAGER_H
#define UNDOREDOMANAGER_H

#include <QObject>
#include "qqmlengine.h"
#include <qqml.h>

class UndoRedoManager : public QObject
{
    Q_OBJECT
public:

    UndoRedoManager();

    // explicit UndoRedoManager(QObject *parent = nullptr);

    static UndoRedoManager* instance();
    static QObject* qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static void registerQml();

private :
    static UndoRedoManager *m_instance;

    // QList <QJsonDocument> listEdits;
};

#endif // UNDOREDOMANAGER_H
