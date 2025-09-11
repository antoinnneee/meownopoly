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
    enum TileType {
        CaseTile,
        DecorationTile,
    };

    Q_ENUM(TileType)

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

signals:
    void caseDataChanged();
    void displayParameterChanged();
    void decorationParameterChanged();

private :
    Case * m_caseData = nullptr;
    DisplayParameter * m_displayParameter = nullptr;
    DecorationParameter * m_decorationParameter = nullptr;
    QJsonObject m_json;
};

#endif // ITEMSNAPABLE_H
