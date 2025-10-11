#ifndef MEOWSTYLE_H
#define MEOWSTYLE_H

#include <QObject>
#include <QQmlEngine>
#include <QStringList>
#include <QMap>

class MeowStyle : public QObject
{
    Q_OBJECT
    
    // Propriétés pour les couleurs des familles
    Q_PROPERTY(QStringList familyColors READ familyColors CONSTANT)
    // Propriétés pour les noms des types de cases
    Q_PROPERTY(QMap<int, QString> caseTypeNames READ caseTypeNames CONSTANT)
    
public:
    static void registerQml();
    static MeowStyle *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    // Getter pour les couleurs des familles
    QStringList familyColors() const;
    // Getter pour les noms des types de cases
    QMap<int, QString> caseTypeNames() const;
    // Méthode helper pour récupérer un nom de type de case depuis QML
    Q_INVOKABLE QString getCaseTypeName(int caseType) const;

public slots:

signals:

private slots:

private:
    explicit MeowStyle(QObject *parent = nullptr);
    static MeowStyle *m_pThis;
    
    // Couleurs des familles basées sur CaseRestArea.h et CaseTile.qml
    QStringList m_familyColors;
    // Noms des types de cases basés sur Case.h
    QMap<int, QString> m_caseTypeNames;
};

#endif // MEOWSTYLE_H
