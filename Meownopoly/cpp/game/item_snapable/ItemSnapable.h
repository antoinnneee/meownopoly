#ifndef ITEMSNAPABLE_H
#define ITEMSNAPABLE_H

#include <QObject>
#include <QQmlEngine>
#include <QUrl>
#include "game/case/Case.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QJsonValueRef>

#include "Displayparameter.h"
#include "decorationparameter.h"
#include "ZoneParameter.h"

class ItemSnapable : public QObject
{
    Q_OBJECT

    
    Q_PROPERTY(Case* caseData READ caseData WRITE setCaseData NOTIFY caseDataChanged FINAL)
    Q_PROPERTY(DisplayParameter * displayParameter READ displayParameter WRITE setDisplayParameter NOTIFY displayParameterChanged FINAL)
    Q_PROPERTY(DecorationParameter * decorationParameter READ decorationParameter WRITE setDecorationParameter NOTIFY decorationParameterChanged FINAL)
    Q_PROPERTY(ZoneParameter * zoneParameter READ zoneParameter WRITE setZoneParameter NOTIFY zoneParameterChanged FINAL)
    Q_PROPERTY(QUuid uniqueId READ uniqueId WRITE setUniqueId NOTIFY uniqueIdChanged FINAL)
    Q_PROPERTY(TileType tileType READ tileType WRITE setTileType NOTIFY tileTypeChanged FINAL)


public:


    ItemSnapable();
    ItemSnapable(Case * caseData, DisplayParameter * displayParameter, QObject *parent = nullptr);
    ItemSnapable(DecorationParameter * decorationParameter, DisplayParameter * displayParameter, QObject *parent = nullptr);
    ItemSnapable(const QJsonObject &json, QObject *parent = nullptr);
    ItemSnapable(Case::CaseType caseType, QObject *parent = nullptr);
    enum TileType {
        CaseTile,
        DecorationTile,
        PhysicZoneTile,
    };
    Q_ENUM(TileType)

    Case * caseData() const;
    void setCaseData(Case * caseData);
    DisplayParameter * displayParameter() const;
    void setDisplayParameter(DisplayParameter * displayParameter);
    DecorationParameter * decorationParameter() const;
    void setDecorationParameter(DecorationParameter * decorationParameter);
    ZoneParameter * zoneParameter() const;
    void setZoneParameter(ZoneParameter * zoneParameter);
    static void registerQml();
    Q_INVOKABLE virtual QString toJSON();

    Q_INVOKABLE void print();

    QJsonObject getOriginalJson() const { return m_json; }

    QUuid uniqueId() const;
    void setUniqueId(const QUuid &newUniqueId);

    Q_INVOKABLE void changeCaseDataType(Case::CaseType caseType);

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
    ItemSnapable::TileType tileType() const;
    void setTileType(const ItemSnapable::TileType &newTileType);

    // Copie les données d'un autre ItemSnapable
    Q_INVOKABLE void copyFrom(ItemSnapable* source);

    bool operator==(const ItemSnapable &other) const {
        if (m_tileType != other.m_tileType)
            return false;
        if (m_displayParameter && other.m_displayParameter) {
            if (!(*m_displayParameter == *other.m_displayParameter))
                return false;
        }
        switch (m_tileType) {
        case DecorationTile:
            if (m_decorationParameter && other.m_decorationParameter)
                if (!(*m_decorationParameter == *other.m_decorationParameter))
                    return false;
            break;
        case PhysicZoneTile:
            if (m_zoneParameter && other.m_zoneParameter)
                if (!(*m_zoneParameter == *other.m_zoneParameter))
                    return false;
            break;
        case CaseTile:
            if (m_caseData && other.m_caseData)
                if (m_caseData->toJSON() != other.m_caseData->toJSON())
                    return false;
            break;
        }
        if (next.size() != other.next.size() || prev.size() != other.prev.size())
            return false;
        for (int i = 0; i < next.size(); i++)
            if (next[i]->uniqueId() != other.next[i]->uniqueId())
                return false;
        for (int i = 0; i < prev.size(); i++)
            if (prev[i]->uniqueId() != other.prev[i]->uniqueId())
                return false;
        return true;
    }

signals:
    void caseDataChanged();
    void displayParameterChanged();
    void decorationParameterChanged();
    void zoneParameterChanged();

    void uniqueIdChanged();

    void tileTypeChanged();

private :
    Case * m_caseData = nullptr;
    DisplayParameter * m_displayParameter = new DisplayParameter;
    DecorationParameter * m_decorationParameter = new DecorationParameter;
    ZoneParameter * m_zoneParameter = new ZoneParameter;
    QJsonObject m_json;
    QUuid m_uniqueId;
    TileType m_tileType;
};

#endif // ITEMSNAPABLE_H
