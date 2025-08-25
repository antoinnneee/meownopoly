#ifndef DISPLAYPARAMETER_H
#define DISPLAYPARAMETER_H


#include <QObject>
#include <QQmlEngine>
#include <QUrl>
#include "case/Case.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
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

    int unitSizeWidth() const;
    void setUnitSizeWidth(int unitSizeWidth);
    int unitSizeHeight() const;
    void setUnitSizeHeight(int unitSizeHeight);
    int gridRelativePositionX() const;
    void setGridRelativePositionX(int gridRelativePositionX);
    int gridRelativePositionY() const;
    void setGridRelativePositionY(int gridRelativePositionY);
    int zLayer() const;
    void setZLayer(int zLayer);

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

#endif // DISPLAYPARAMETER_H
