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


void UndoRedoManager::onUpdateListEdits(QJsonObject newEdit){
    m_listEdits.append(newEdit);
    m_currentEditIndex = m_currentEditIndex +1;
}

void UndoRedoManager::onAskEdit(EditAction editAction)
{
    switch (editAction) {
    case Preview:
        if (m_currentEditIndex > 0){
            m_currentEditIndex = m_currentEditIndex -1;
            emit returnEdit(m_listEdits.at(m_currentEditIndex));
        }
        break;
    case Next:
        if (m_currentEditIndex < m_listEdits.size() -1){
            m_currentEditIndex = m_currentEditIndex +1;
            emit returnEdit(m_listEdits.at(m_currentEditIndex));
        }
        break;
    default:
        break;
    }
}
