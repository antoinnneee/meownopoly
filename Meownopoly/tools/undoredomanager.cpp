#include "undoredomanager.h"

UndoRedoManager *UndoRedoManager::m_instance = nullptr;

UndoRedoManager::UndoRedoManager() {}

void UndoRedoManager::registerQml()
{
    qmlRegisterSingletonType<UndoRedoManager>("UndoRedoManager", 1, 0, "UndoRedoManager", &UndoRedoManager::qmlInstance);
}

UndoRedoManager* UndoRedoManager::instance()
{
    if (m_instance == nullptr) {
        m_instance = new UndoRedoManager;
    }
    return m_instance;
}

QObject *UndoRedoManager::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    return UndoRedoManager::instance();
}


void UndoRedoManager::onUpdateListEdits(QJsonObject newEdit)
{
}

void UndoRedoManager::onAskEdit(EditAction editAction)
{

}
