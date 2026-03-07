#ifndef UNDOREDOMANAGER_H
#define UNDOREDOMANAGER_H

#include <QObject>
#include <QQmlEngine>
#include <QJsonObject>
#include <QProcess>


class UndoRedoManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isRestoringState READ isRestoringState WRITE setIsRestoringState NOTIFY isRestoringStateChanged FINAL)
public:


    enum EditAction{
        Preview,
        Next
    };

    Q_ENUM(EditAction)

    UndoRedoManager();

    // explicit UndoRedoManager(QObject *parent = nullptr);

    static UndoRedoManager* instance();
    static QObject* qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static void registerQml();
    
    // Nouvelle methode pour vérifier si on peut sauvegarder
    Q_INVOKABLE bool canSave() const { return !m_isRestoringState; }
    
    // Method to clear restoration flag from QML after map loading completes
    Q_INVOKABLE void clearRestorationFlag();

    bool isRestoringState() const;
    void setIsRestoringState(bool newIsRestoringState);

    QJsonObject getLastEdit() const {
        if (m_currentEditIndex >= 0 && m_currentEditIndex < m_listEdits.size()) {
            return m_listEdits.at(m_currentEditIndex);
        }
        return QJsonObject(); // Return empty object if index is out of bounds
    }

public slots:

    void onUpdateListEdits(QJsonObject newEdit);
    void onAskEdit(EditAction editAction);

signals:

    void returnEdit(QJsonObject editAction);
    void forceUnSelectAllElement();
    void isRestoringStateChanged();

private :
    static UndoRedoManager *m_instance;

    int m_currentEditIndex = 0;  // Commence à 0
    QList <QJsonObject> m_listEdits;
    QJsonObject m_edit;
    bool m_isRestoringState = false;  // Flag pour bloquer les sauvegardes pendant restauration
};

#endif // UNDOREDOMANAGER_H
