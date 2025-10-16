#ifndef ITEMSNAPABLE_H
#define ITEMSNAPABLE_H

#include <QObject>
#include <QQmlEngine>
#include <QUrl>
#include "case/Case.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QJsonValueRef>

#include "Displayparameter.h"
#include "Decorationparameter.h"

class ItemSnapable : public QObject
{
    Q_OBJECT

    
    Q_PROPERTY(Case* caseData READ caseData WRITE setCaseData NOTIFY caseDataChanged FINAL)
    Q_PROPERTY(DisplayParameter * displayParameter READ displayParameter WRITE setDisplayParameter NOTIFY displayParameterChanged FINAL)
    Q_PROPERTY(DecorationParameter * decorationParameter READ decorationParameter WRITE setDecorationParameter NOTIFY decorationParameterChanged FINAL)
    Q_PROPERTY(QUuid uniqueId READ uniqueId WRITE setUniqueId NOTIFY uniqueIdChanged FINAL)

    enum TileType {
        CaseTile,
        DecorationTile,
    };


public:
    ItemSnapable();
    ItemSnapable(Case * caseData, DisplayParameter * displayParameter, QObject *parent = nullptr);
    ItemSnapable(DecorationParameter * decorationParameter, DisplayParameter * displayParameter, QObject *parent = nullptr);
    ItemSnapable(const QJsonObject &json, QObject *parent = nullptr);
    

    Case * caseData() const;
    void setCaseData(Case * caseData);
    DisplayParameter * displayParameter() const;
    void setDisplayParameter(DisplayParameter * displayParameter);
    DecorationParameter * decorationParameter() const;
    void setDecorationParameter(DecorationParameter * decorationParameter);
    static void registerQml();
    Q_INVOKABLE virtual QString toJSON();
    
    // Helper function to create the correct Case type from JSON
    static Case* getNewCaseFromJSON(const QJsonObject &caseJson, QObject *parent = nullptr);

    void print();

    QJsonObject getOriginalJson() const { return m_json; }

    QUuid uniqueId() const;
    void setUniqueId(const QUuid &newUniqueId);



    Q_INVOKABLE void addNext(ItemSnapable *newNext);
    Q_INVOKABLE bool removeNext(ItemSnapable *caseToRemove); // Nouvelle fonction
    Q_INVOKABLE  bool removeNextAt(int index); // Nouvelle fonction

    Q_INVOKABLE void addPrev(ItemSnapable *newPrev);
    Q_INVOKABLE bool removePrev(ItemSnapable *caseToRemove); // Nouvelle fonction
    Q_INVOKABLE bool removePrevAt(int index); // Nouvelle fonction


    Q_INVOKABLE QList<ItemSnapable*> getNextList() {return next;}
    Q_INVOKABLE QList<ItemSnapable*> getPrevList() {return prev;}
    QList<ItemSnapable*> next = QList<ItemSnapable*>();
    QList<ItemSnapable*> prev = QList<ItemSnapable*>();
    TileType tileType() const;
    void setTileType(const TileType &newTileType);

signals:
    void caseDataChanged();
    void displayParameterChanged();
    void decorationParameterChanged();

    void uniqueIdChanged();

    void tileTypeChanged();

private :
    Case * m_caseData = nullptr;
    DisplayParameter * m_displayParameter = new DisplayParameter;
    DecorationParameter * m_decorationParameter = new DecorationParameter;
    QJsonObject m_json;
    QUuid m_uniqueId;
    TileType m_tileType;
};

#endif // ITEMSNAPABLE_H
