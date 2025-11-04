
#include <QQmlEngine>
#include "undoredomanager.h"
#include "qjsonarray.h"

UndoRedoManager *UndoRedoManager::m_instance = nullptr;

UndoRedoManager::UndoRedoManager() {}

void UndoRedoManager::registerQml()
{
    UndoRedoManager::instance();
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
        qDebug() << "[UNDO][SAVE] BLOCKED - Save attempted during state restoration (flag is true)";
        return;
    }

    // compareJsonObject(newEdit);
    
    // Si on n'est pas à la fin, supprimer toutes les entrées futures
    if (m_currentEditIndex < m_listEdits.size() - 1) {
        int removed = m_listEdits.size() - m_currentEditIndex - 1;
        m_listEdits = m_listEdits.mid(0, m_currentEditIndex + 1);
        qDebug() << "[UNDO][SAVE] Cleared" << removed << "future states (redo history)";
    }
    
    // Ajouter le nouvel etat
    m_listEdits.append(newEdit);
    m_currentEditIndex = m_listEdits.size() - 1;
    
    qDebug() << "[UNDO][SAVE] State saved successfully at index:" << m_currentEditIndex << "/ Total states:" << m_listEdits.size();
}

void UndoRedoManager::onAskEdit(EditAction editAction)
{
    if (m_listEdits.isEmpty()) {
        qDebug() << "[UNDO][REQUEST] No states available - history is empty";
        return;
    }

    qDebug() << "[UNDO][REQUEST] Current index:" << m_currentEditIndex << "/ Total:" << m_listEdits.size();
    emit forceUnSelectAllElement();

    switch (editAction) {
    case Preview:  // Undo
        if (m_currentEditIndex > 0) {
            m_currentEditIndex--;
            // Set flag BEFORE emitting to prevent any saves during restoration
            m_isRestoringState = true;
            qDebug() << "[UNDO][RESTORE] Moving to index:" << m_currentEditIndex << "/" << m_listEdits.size() << "- Restoration flag SET";
            emit returnEdit(m_listEdits.at(m_currentEditIndex));
            // Flag will be cleared by QML after map loading completes
        } else {
            qDebug() << "[UNDO][RESTORE] Cannot undo - already at oldest state (index 0)";
        }
        break;
        
    case Next:  // Redo
        if (m_currentEditIndex < m_listEdits.size() - 1) {
            m_currentEditIndex++;
            // Set flag BEFORE emitting to prevent any saves during restoration
            m_isRestoringState = true;
            qDebug() << "[REDO][RESTORE] Moving to index:" << m_currentEditIndex << "/" << m_listEdits.size() << "- Restoration flag SET";
            emit returnEdit(m_listEdits.at(m_currentEditIndex));
            // Flag will be cleared by QML after map loading completes
        } else {
            qDebug() << "[REDO][RESTORE] Cannot redo - already at newest state (index" << m_currentEditIndex << ")";
        }
        break;
        
    default:
        break;
    }
}

bool UndoRedoManager::isRestoringState() const
{
    return m_isRestoringState;
}

void UndoRedoManager::setIsRestoringState(bool newIsRestoringState)
{
    if (m_isRestoringState == newIsRestoringState)
        return;
    m_isRestoringState = newIsRestoringState;
    emit isRestoringStateChanged();
}

void UndoRedoManager::clearRestorationFlag()
{
    if (m_isRestoringState) {
        qDebug() << "[UNDO][RESTORE] Restoration complete - Flag CLEARED, saves now allowed";
        m_isRestoringState = false;
        emit isRestoringStateChanged();
    } else {
        qDebug() << "[UNDO][RESTORE] Warning: clearRestorationFlag() called but flag was already false";
    }
}


// void UndoRedoManager::compareJsonObject(QJsonObject newEdit)
// {
//     QProcess diffProcess;

//     QTemporaryFile file;

//     QJsonDocument oldE = m_listEdits.isEmpty() ? QJsonDocument() : (QJsonDocument)m_listEdits.last();
//     QJsonDocument newE = QJsonDocument(newEdit);
//     QStringList arg;
//     arg << oldE.toJson(QJsonDocument::Indented) << newE.toJson(QJsonDocument::Indented);

//     // qDebug() << "Old E " << oldE;
//     // qDebug() << "New E " << newE;

//     diffProcess.start("fc.exe", arg);
//     // diffProcess.start("fc.exe", QStringList{"test", "test"});

//     qDebug() << "diffProcess.errorString() " << diffProcess.errorString();
//     qDebug() << " diffProcess.readAllStandardOutput " << diffProcess.readAllStandardOutput();
// }






// void UndoRedoManager::compareJsonObject(QJsonObject newEdit)
// {
//     if (m_listEdits.isEmpty()) {
//         qDebug() << "[UNDO] First state, nothing to compare";
//         return;
//     }

//     QJsonObject oldEdit = m_listEdits.last();

//     // Comparaison rapide : si identiques, pas besoin d'aller plus loin
//     if (oldEdit == newEdit) {
//         qDebug() << "[UNDO] No changes detected, skipping save";
//         // Vous pourriez m�me retourner ici pour ne PAS ajouter l'�tat dupliqu�
//         return;
//     }

//     // Comparaison d�taill�e pour le debug/logging
//     qDebug() << "[UNDO] Changes detected:";
//     compareJsonFields(oldEdit, newEdit, "");
// }

// void UndoRedoManager::compareJsonFields(const QJsonObject& oldObj, const QJsonObject& newObj, const QString& path)
// {
//     // R�cup�rer toutes les cl�s uniques
//     QSet<QString> allKeys;
//     for (const QString& key : oldObj.keys()) allKeys.insert(key);
//     for (const QString& key : newObj.keys()) allKeys.insert(key);

//     for (const QString& key : allKeys) {
//         QString currentPath = path.isEmpty() ? key : path + "." + key;

//         bool oldHasKey = oldObj.contains(key);
//         bool newHasKey = newObj.contains(key);

//         if (!oldHasKey && newHasKey) {
//             qDebug() << "  [+]" << currentPath << "=" << newObj[key];
//         }
//         else if (oldHasKey && !newHasKey) {
//             qDebug() << "  [-]" << currentPath;
//         }
//         else if (oldHasKey && newHasKey) {
//             QJsonValue oldVal = oldObj[key];
//             QJsonValue newVal = newObj[key];

//             if (oldVal != newVal) {
//                 if (oldVal.isObject() && newVal.isObject()) {
//                     // Comparaison r�cursive pour les objets imbriqu�s
//                     compareJsonFields(oldVal.toObject(), newVal.toObject(), currentPath);
//                 }
//                 else if (oldVal.isArray() && newVal.isArray()) {
//                     qDebug() << "  [~]" << currentPath << ": array changed (old size:"
//                              << oldVal.toArray().size() << ", new size:" << newVal.toArray().size() << ")";
//                 }
//                 else {
//                     qDebug() << "  [~]" << currentPath << ": " << oldVal << "->" << newVal;
//                 }
//             }
//         }
//     }
// }














