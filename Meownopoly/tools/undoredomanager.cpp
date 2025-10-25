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
    // Si on est en train de restaurer un etat, ignorer completement
    if (m_isRestoringState) {
        qDebug() << "[UNDO] Ignoring save during state restoration";
        return;
    }
    
    // Si on n'est pas à la fin, supprimer toutes les entrées futures
    if (m_currentEditIndex < m_listEdits.size() - 1) {
        int removed = m_listEdits.size() - m_currentEditIndex - 1;
        m_listEdits = m_listEdits.mid(0, m_currentEditIndex + 1);
        qDebug() << "[UNDO] Removed" << removed << "future states";
    }
    
    // Ajouter le nouvel etat
    m_listEdits.append(newEdit);
    m_currentEditIndex = m_listEdits.size() - 1;
    
    qDebug() << "[UNDO] State saved at index:" << m_currentEditIndex << "/ Total:" << m_listEdits.size();
}

void UndoRedoManager::onAskEdit(EditAction editAction)
{
    if (m_listEdits.isEmpty()) {
        qDebug() << "[UNDO] No states available";
        return;
    }
    
    switch (editAction) {
    case Preview:  // Undo
        if (m_currentEditIndex > 0) {
            m_currentEditIndex--;
            m_isRestoringState = true;  // Bloquer les sauvegardes
            qDebug() << "[UNDO] Restoring state:" << m_currentEditIndex << "/" << m_listEdits.size();
            emit returnEdit(m_listEdits.at(m_currentEditIndex));
            m_isRestoringState = false;  // Débloquer
        } else {
            qDebug() << "[UNDO] Already at oldest state";
        }
        break;
        
    case Next:  // Redo
        if (m_currentEditIndex < m_listEdits.size() - 1) {
            m_currentEditIndex++;
            m_isRestoringState = true;  // Bloquer les sauvegardes
            qDebug() << "[REDO] Restoring state:" << m_currentEditIndex << "/" << m_listEdits.size();
            emit returnEdit(m_listEdits.at(m_currentEditIndex));
            m_isRestoringState = false;  // Débloquer
        } else {
            qDebug() << "[REDO] Already at newest state";
        }
        break;
        
    default:
        break;
    }
}
