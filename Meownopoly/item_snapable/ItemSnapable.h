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
#include <QJsonValueRef>

class DisplayParameter: public QObject {
    Q_OBJECT

    public:
        Q_PROPERTY(int unitSizeWidth READ unitSizeWidth WRITE setUnitSizeWidth NOTIFY unitSizeWidthChanged)
        Q_PROPERTY(int unitSizeHeight READ unitSizeHeight WRITE setUnitSizeHeight NOTIFY unitSizeHeightChanged)
        Q_PROPERTY(int gridRelativePositionX READ gridRelativePositionX WRITE setGridRelativePositionX NOTIFY gridRelativePositionXChanged)
        Q_PROPERTY(int gridRelativePositionY READ gridRelativePositionY WRITE setGridRelativePositionY NOTIFY gridRelativePositionYChanged)
        Q_PROPERTY(int zLayer READ zLayer WRITE setZLayer NOTIFY zLayerChanged)

        DisplayParameter(int unitSizeWidth = 0, int unitSizeHeight = 0, int gridRelativePosition = 0, int gridRelativePositionY = 0, int zLayer = 5, QObject *parent = nullptr);
        DisplayParameter(const QJsonObject &json, QObject *parent = nullptr);
        QString toJSON();

        int unitSizeWidth() const {return m_unitSizeWidth;}
        void setUnitSizeWidth(int unitSizeWidth) {m_unitSizeWidth = unitSizeWidth; emit unitSizeWidthChanged();}
        int unitSizeHeight() const {return m_unitSizeHeight;}
        void setUnitSizeHeight(int unitSizeHeight) {m_unitSizeHeight = unitSizeHeight; emit unitSizeHeightChanged();}
        int gridRelativePositionX() const {return m_gridRelativePositionX;}
        void setGridRelativePositionX(int gridRelativePositionX) {m_gridRelativePositionX = gridRelativePositionX; emit gridRelativePositionXChanged();}
        int gridRelativePositionY() const {return m_gridRelativePositionY;}
        void setGridRelativePositionY(int gridRelativePositionY) {m_gridRelativePositionY = gridRelativePositionY; emit gridRelativePositionYChanged();}
        int zLayer() const {return m_zLayer;}
        void setZLayer(int zLayer) {m_zLayer = zLayer; emit zLayerChanged();}


        signals:
            void unitSizeWidthChanged();
            void unitSizeHeightChanged();
            void gridRelativePositionXChanged();
            void gridRelativePositionYChanged();
            void zLayerChanged();

        private :
            int m_unitSizeWidth;
            int m_unitSizeHeight;
            int m_gridRelativePositionX;
            int m_gridRelativePositionY;
            int m_zLayer;
    

};

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

    Q_INVOKABLE QString toJSON();

signals:
        void caseDataChanged();
        void displayParameterChanged();


private :
        Case * m_caseData;
        DisplayParameter * m_displayParameter;
        QJsonObject m_json;
};

#endif // ITEMSNAPABLE_H
