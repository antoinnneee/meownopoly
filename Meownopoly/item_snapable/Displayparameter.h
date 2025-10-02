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
#include <QColor>
#include <QFileInfo>

class DisplayParameter: public QObject {
    Q_OBJECT

public:
    // position and size
    Q_PROPERTY(int unitSizeWidth READ unitSizeWidth WRITE setUnitSizeWidth NOTIFY unitSizeWidthChanged)
    Q_PROPERTY(int unitSizeHeight READ unitSizeHeight WRITE setUnitSizeHeight NOTIFY unitSizeHeightChanged)
    Q_PROPERTY(int gridRelativePositionX READ gridRelativePositionX WRITE setGridRelativePositionX NOTIFY gridRelativePositionXChanged)
    Q_PROPERTY(int gridRelativePositionY READ gridRelativePositionY WRITE setGridRelativePositionY NOTIFY gridRelativePositionYChanged)
    Q_PROPERTY(int zLayer READ zLayer WRITE setZLayer NOTIFY zLayerChanged)
    Q_PROPERTY(float zOrder READ zOrder WRITE setZOrder NOTIFY zOrderChanged FINAL) // small addition to ZLayer

    // effects brightness, contrast, saturation, colorization
    Q_PROPERTY(double effectBrightness READ effectBrightness WRITE setEffectBrightness NOTIFY effectBrightnessChanged)
    Q_PROPERTY(double effectContrast READ effectContrast WRITE setEffectContrast NOTIFY effectContrastChanged)
    Q_PROPERTY(double effectSaturation READ effectSaturation WRITE setEffectSaturation NOTIFY effectSaturationChanged)
    Q_PROPERTY(double effectColorization READ effectColorization WRITE setEffectColorization NOTIFY effectColorizationChanged)
    Q_PROPERTY(QColor effectColorizationColor READ effectColorizationColor WRITE setEffectColorizationColor NOTIFY effectColorizationColorChanged)

    // effects blur
    Q_PROPERTY(bool effectBlurEnabled READ effectBlurEnabled WRITE setEffectBlurEnabled NOTIFY effectBlurEnabledChanged)
    Q_PROPERTY(double effectBlur READ effectBlur WRITE setEffectBlur NOTIFY effectBlurChanged)
    Q_PROPERTY(int effectBlurMax READ effectBlurMax WRITE setEffectBlurMax NOTIFY effectBlurMaxChanged)
    Q_PROPERTY(double effectBlurMultiplier READ effectBlurMultiplier WRITE setEffectBlurMultiplier NOTIFY effectBlurMultiplierChanged)
    
    // effects shadow
    Q_PROPERTY(bool effectShadowEnabled READ effectShadowEnabled WRITE setEffectShadowEnabled NOTIFY effectShadowEnabledChanged)
    Q_PROPERTY(double effectShadowBlur READ effectShadowBlur WRITE setEffectShadowBlur NOTIFY effectShadowBlurChanged)
    Q_PROPERTY(QColor effectShadowColor READ effectShadowColor WRITE setEffectShadowColor NOTIFY effectShadowColorChanged)
    Q_PROPERTY(double effectShadowHorizontalOffset READ effectShadowHorizontalOffset WRITE setEffectShadowHorizontalOffset NOTIFY effectShadowHorizontalOffsetChanged)
    Q_PROPERTY(double effectShadowVerticalOffset READ effectShadowVerticalOffset WRITE setEffectShadowVerticalOffset NOTIFY effectShadowVerticalOffsetChanged)
    Q_PROPERTY(double effectShadowOpacity READ effectShadowOpacity WRITE setEffectShadowOpacity NOTIFY effectShadowOpacityChanged)
    Q_PROPERTY(double effectShadowScale READ effectShadowScale WRITE setEffectShadowScale NOTIFY effectShadowScaleChanged)

    // rotation properties
    Q_PROPERTY(double rotationAngle READ rotationAngle WRITE setRotationAngle NOTIFY rotationAngleChanged)
    
    // mirror properties
    Q_PROPERTY(bool mirrorHorizontal READ mirrorHorizontal WRITE setMirrorHorizontal NOTIFY mirrorHorizontalChanged)
    Q_PROPERTY(bool mirrorVertical READ mirrorVertical WRITE setMirrorVertical NOTIFY mirrorVerticalChanged)


    Q_INVOKABLE QString getAnimePath(QString imagePath);

    DisplayParameter(int unitSizeWidth = 0, int unitSizeHeight = 0, int gridRelativePosition = 0, int gridRelativePositionY = 0, int zLayer = 5, float zOrder = 0, QObject *parent = nullptr);
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

    // effects brightness, contrast, saturation, colorization
    double effectBrightness() const;
    void setEffectBrightness(double effectBrightness);
    double effectContrast() const;
    void setEffectContrast(double effectContrast);
    double effectSaturation() const;
    void setEffectSaturation(double effectSaturation);
    double effectColorization() const;
    void setEffectColorization(double effectColorization);
    QColor effectColorizationColor() const;
    void setEffectColorizationColor(QColor effectColorizationColor);

    // effects blur
    bool effectBlurEnabled() const;
    void setEffectBlurEnabled(bool effectBlurEnabled);
    double effectBlur() const;
    void setEffectBlur(double effectBlur);
    int effectBlurMax() const;
    void setEffectBlurMax(int effectBlurMax);
    double effectBlurMultiplier() const;
    void setEffectBlurMultiplier(double effectBlurMultiplier);

    // effects shadow
    bool effectShadowEnabled() const;
    void setEffectShadowEnabled(bool effectShadowEnabled);
    double effectShadowBlur() const;
    void setEffectShadowBlur(double effectShadowBlur);
    QColor effectShadowColor() const;
    void setEffectShadowColor(QColor effectShadowColor);
    double effectShadowHorizontalOffset() const;
    void setEffectShadowHorizontalOffset(double effectShadowHorizontalOffset);
    double effectShadowVerticalOffset() const;
    void setEffectShadowVerticalOffset(double effectShadowVerticalOffset);
    double effectShadowOpacity() const;
    void setEffectShadowOpacity(double effectShadowOpacity);
    double effectShadowScale() const;
    void setEffectShadowScale(double effectShadowScale);

    // rotation methods
    double rotationAngle() const;
    void setRotationAngle(double rotationAngle);
    
    // mirror methods
    bool mirrorHorizontal() const;
    void setMirrorHorizontal(bool mirrorHorizontal);
    bool mirrorVertical() const;
    void setMirrorVertical(bool mirrorVertical);

    float zOrder() const;
    void setZOrder(float newZOrder);

signals:
    void unitSizeWidthChanged();
    void unitSizeHeightChanged();
    void gridRelativePositionXChanged();
    void gridRelativePositionYChanged();
    void zLayerChanged();

    void effectBrightnessChanged();
    void effectContrastChanged();
    void effectSaturationChanged();
    void effectColorizationChanged();
    void effectColorizationColorChanged();

    void effectBlurEnabledChanged();
    void effectBlurChanged();
    void effectBlurMaxChanged();
    void effectBlurMultiplierChanged();

    void effectShadowEnabledChanged();
    void effectShadowBlurChanged();
    void effectShadowColorChanged();
    void effectShadowHorizontalOffsetChanged();
    void effectShadowVerticalOffsetChanged();
    void effectShadowOpacityChanged();
    void effectShadowScaleChanged();

    void rotationAngleChanged();
    void mirrorHorizontalChanged();
    void mirrorVerticalChanged();

    void zOrderChanged();

private :
    int m_unitSizeWidth;
    int m_unitSizeHeight;
    int m_gridRelativePositionX;
    int m_gridRelativePositionY;
    int m_zLayer;

    double m_effectBrightness;
    double m_effectContrast;
    double m_effectSaturation;
    double m_effectColorization;
    QColor m_effectColorizationColor;

    bool m_effectBlurEnabled;
    double m_effectBlur;
    int m_effectBlurMax;
    double m_effectBlurMultiplier;

    bool m_effectShadowEnabled;
    double m_effectShadowBlur;
    QColor m_effectShadowColor;
    double m_effectShadowHorizontalOffset;
    double m_effectShadowVerticalOffset;
    double m_effectShadowOpacity;
    double m_effectShadowScale;

    // rotation members
    double m_rotationAngle;
    
    // mirror members
    bool m_mirrorHorizontal;
    bool m_mirrorVertical;

    float m_zOrder;
};

#endif // DISPLAYPARAMETER_H
