#ifndef ITEMSNAPABLEFACTORY_H
#define ITEMSNAPABLEFACTORY_H

#include <QObject>
#include <QQmlEngine>
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
public slots:

signals:

private slots:

private:
    explicit ItemSnapableFactory(QObject *parent = nullptr);
    static ItemSnapableFactory *m_pThis;
};

#endif // ITEMSNAPABLEFACTORY_H
