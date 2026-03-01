#ifndef ITEMSNAPABLEFACTORY_H
#define ITEMSNAPABLEFACTORY_H

#include <QObject>
#include <QQmlEngine>
#include <QJsonObject>
#include <QJsonArray>
#include "game/case/Case.h"
#include "ItemSnapable.h"

class ItemSnapableFactory : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static ItemSnapableFactory *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE ItemSnapable *createItemSnapable();
    Q_INVOKABLE ItemSnapable *createItemSnapable(Case::CaseType caseType);
    Q_INVOKABLE ItemSnapable *createItemSnapableFromJson(const QJsonObject &json);
    Q_INVOKABLE ItemSnapable *createPhysicZone();

    /// Demande la création d'un item depuis C++ ou QML.
    /// Émet createItemRequested(jsonData) que l'éditeur QML intercepte.
    Q_INVOKABLE void requestCreateItem(const QJsonObject &jsonData);
    /// Demande la création de plusieurs items depuis un tableau JSON.
    /// Émet createItemsRequested(jsonArray) que l'éditeur QML intercepte.
    Q_INVOKABLE void requestCreateItems(const QJsonArray &jsonArray);
    /// Variante prenant une chaîne JSON — détecte automatiquement objet ou tableau.
    void requestCreateItemFromString(const QString &jsonString);

public slots:

signals:
    /// Émis pour demander à l'éditeur QML de créer et placer un ItemSnapable.
    void createItemRequested(const QJsonObject &jsonData);
    /// Émis pour demander à l'éditeur QML de créer et placer plusieurs ItemSnapable.
    void createItemsRequested(const QJsonArray &jsonArray);

private slots:

private:
    explicit ItemSnapableFactory(QObject *parent = nullptr);
    static ItemSnapableFactory *m_pThis;
};

#endif // ITEMSNAPABLEFACTORY_H
