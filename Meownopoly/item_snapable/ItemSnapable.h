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

#include "displayparameter.h"

class ItemSnapable : public QObject
{
    Q_OBJECT

    Q_PROPERTY(Case * caseData READ caseData WRITE setCaseData NOTIFY caseDataChanged FINAL)
    Q_PROPERTY(DisplayParameter * displayParameter READ displayParameter WRITE setDisplayParameter NOTIFY displayParameterChanged FINAL)
    

public:
    ItemSnapable();
    ItemSnapable(Case * caseData, DisplayParameter * displayParameter, QObject *parent = nullptr);
    ItemSnapable(const QJsonDocument &json, QObject *parent = nullptr);

    Case * caseData() const {return m_caseData;}
    void setCaseData(Case * caseData) {m_caseData = caseData; emit caseDataChanged();}
    DisplayParameter * displayParameter() const {return m_displayParameter;}
    void setDisplayParameter(DisplayParameter * displayParameter) {m_displayParameter = displayParameter; emit displayParameterChanged();}

    static void registerQml();
    Q_INVOKABLE virtual QString toJSON();

signals:
        void caseDataChanged();
        void displayParameterChanged();


private :
        Case * m_caseData;
        DisplayParameter * m_displayParameter;
        QJsonObject m_json;
};

#endif // ITEMSNAPABLE_H
