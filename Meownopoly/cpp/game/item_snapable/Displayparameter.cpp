#include "Displayparameter.h"
#include "tools/logger.h"




DisplayParameter::DisplayParameter(int unitSizeWidth, int unitSizeHeight, int gridRelativePositionX, int gridRelativePositionY, int zLayer, float zOrder, QObject *parent)
    : QObject(parent)
{
    m_unitSizeWidth = unitSizeWidth;
    m_unitSizeHeight = unitSizeHeight;
    m_gridRelativePositionX = gridRelativePositionX;
    m_gridRelativePositionY = gridRelativePositionY;
    m_zLayer = zLayer;
    m_zOrder = zOrder;
    m_effectBrightness = 0.0;
    m_effectContrast = 0.0;
    m_effectSaturation = 0.0;
    m_effectColorization = 0.0;
    m_effectColorizationColor = QColor(255, 255, 255);
    m_effectBlurEnabled = false;
    m_effectBlur = 0.0;
    m_effectBlurMax = 32;
    m_effectBlurMultiplier = 1.0;
    m_effectShadowEnabled = false;
    m_effectShadowBlur = 1.0;
    m_effectShadowColor = QColor(0, 0, 0, 1.0);
    m_effectShadowHorizontalOffset = 0.0;
    m_effectShadowVerticalOffset = 0.0;
    m_effectShadowOpacity = 1.0;
    m_effectShadowScale = 1.0;
    
    // Initialize rotation properties
    m_rotationAngle = 0.0;

    // Initialize mirror properties
    m_mirrorHorizontal = false;
    m_mirrorVertical = false;
}

DisplayParameter::DisplayParameter(const QJsonObject &json, QObject *parent): QObject(parent)
{
    m_unitSizeWidth = json["unitSizeWidth"].toInt();
    m_unitSizeHeight = json["unitSizeHeight"].toInt();
    m_gridRelativePositionX = json["gridRelativePositionX"].toInt();
    m_gridRelativePositionY = json["gridRelativePositionY"].toInt();
    m_zLayer = json["zLayer"].toInt();
    m_zOrder = json["zOrder"].toDouble();
    m_effectBrightness = json["effectBrightness"].toDouble();
    m_effectContrast = json["effectContrast"].toDouble();
    m_effectSaturation = json["effectSaturation"].toDouble();
    m_effectColorization = json["effectColorization"].toDouble();
    m_effectColorizationColor = QColor(json["effectColorizationColor"].toString());
    m_effectBlurEnabled = json["effectBlurEnabled"].toInt();
    m_effectBlur = json["effectBlur"].toDouble();
    m_effectBlurMax = json["effectBlurMax"].toInt();
    m_effectBlurMultiplier = json["effectBlurMultiplier"].toDouble();
    m_effectShadowEnabled = json["effectShadowEnabled"].toInt();
    m_effectShadowBlur = json["effectShadowBlur"].toDouble();
    m_effectShadowColor = QColor(json["effectShadowColor"].toString());
    m_effectShadowHorizontalOffset = json["effectShadowHorizontalOffset"].toDouble();
    m_effectShadowVerticalOffset = json["effectShadowVerticalOffset"].toDouble();
    m_effectShadowOpacity = json["effectShadowOpacity"].toDouble();
    m_effectShadowScale = json["effectShadowScale"].toDouble();
    
    // Load rotation properties
    m_rotationAngle = json["rotationAngle"].toDouble();
    
    // Load mirror properties
    m_mirrorHorizontal = json["mirrorHorizontal"].toInt();
    m_mirrorVertical = json["mirrorVertical"].toInt();
}

void DisplayParameter::applyJson(const QJsonObject &json)
{
    setUnitSizeWidth(json["unitSizeWidth"].toInt());
    setUnitSizeHeight(json["unitSizeHeight"].toInt());
    setGridRelativePositionX(json["gridRelativePositionX"].toInt());
    setGridRelativePositionY(json["gridRelativePositionY"].toInt());
    setZLayer(json["zLayer"].toInt());
    setZOrder(json["zOrder"].toDouble());
    setEffectBrightness(json["effectBrightness"].toDouble());
    setEffectContrast(json["effectContrast"].toDouble());
    setEffectSaturation(json["effectSaturation"].toDouble());
    setEffectColorization(json["effectColorization"].toDouble());
    setEffectColorizationColor(QColor(json["effectColorizationColor"].toString()));
    setEffectBlurEnabled(json["effectBlurEnabled"].toInt());
    setEffectBlur(json["effectBlur"].toDouble());
    setEffectBlurMax(json["effectBlurMax"].toInt());
    setEffectBlurMultiplier(json["effectBlurMultiplier"].toDouble());
    setEffectShadowEnabled(json["effectShadowEnabled"].toInt());
    setEffectShadowBlur(json["effectShadowBlur"].toDouble());
    setEffectShadowColor(QColor(json["effectShadowColor"].toString()));
    setEffectShadowHorizontalOffset(json["effectShadowHorizontalOffset"].toDouble());
    setEffectShadowVerticalOffset(json["effectShadowVerticalOffset"].toDouble());
    setEffectShadowOpacity(json["effectShadowOpacity"].toDouble());
    setEffectShadowScale(json["effectShadowScale"].toDouble());
    setRotationAngle(json["rotationAngle"].toDouble());
    setMirrorHorizontal(json["mirrorHorizontal"].toInt());
    setMirrorVertical(json["mirrorVertical"].toInt());
}

QJsonObject DisplayParameter::toJsonObject() const
{
    // NB : effectBlurEnabled / effectShadowEnabled / mirror* sont écrits en
    // ENTIER (0/1) — les lecteurs (ctor JSON + applyJson) les relisent via
    // QJsonValue::toInt(), qui renvoie 0 sur un booléen JSON. Écrire un bool
    // ici casserait le round-trip.
    return QJsonObject{
        { "unitSizeWidth",                m_unitSizeWidth },
        { "unitSizeHeight",               m_unitSizeHeight },
        { "gridRelativePositionX",        m_gridRelativePositionX },
        { "gridRelativePositionY",        m_gridRelativePositionY },
        { "zLayer",                       m_zLayer },
        { "zOrder",                       m_zOrder },
        { "effectBrightness",             m_effectBrightness },
        { "effectContrast",               m_effectContrast },
        { "effectSaturation",             m_effectSaturation },
        { "effectColorization",           m_effectColorization },
        { "effectColorizationColor",      m_effectColorizationColor.name() },
        { "effectBlurEnabled",            m_effectBlurEnabled ? 1 : 0 },
        { "effectBlur",                   m_effectBlur },
        { "effectBlurMax",                m_effectBlurMax },
        { "effectBlurMultiplier",         m_effectBlurMultiplier },
        { "effectShadowEnabled",          m_effectShadowEnabled ? 1 : 0 },
        { "effectShadowBlur",             m_effectShadowBlur },
        { "effectShadowColor",            m_effectShadowColor.name() },
        { "effectShadowHorizontalOffset", m_effectShadowHorizontalOffset },
        { "effectShadowVerticalOffset",   m_effectShadowVerticalOffset },
        { "effectShadowOpacity",          m_effectShadowOpacity },
        { "effectShadowScale",            m_effectShadowScale },
        { "rotationAngle",                m_rotationAngle },
        { "mirrorHorizontal",             m_mirrorHorizontal ? 1 : 0 },
        { "mirrorVertical",               m_mirrorVertical ? 1 : 0 },
    };
}

QString DisplayParameter::toJSON()
{
    return QString::fromUtf8(
        QJsonDocument(toJsonObject()).toJson(QJsonDocument::Compact));
}
int DisplayParameter::unitSizeWidth() const
{
    return m_unitSizeWidth;
}

void DisplayParameter::setUnitSizeWidth(int unitSizeWidth)
{
    m_unitSizeWidth = unitSizeWidth;
    emit unitSizeWidthChanged();
}

int DisplayParameter::unitSizeHeight() const
{
    return m_unitSizeHeight;
}

void DisplayParameter::setUnitSizeHeight(int unitSizeHeight)
{
    m_unitSizeHeight = unitSizeHeight;
    emit unitSizeHeightChanged();
}

int DisplayParameter::gridRelativePositionX() const
{
    return m_gridRelativePositionX;
}

void DisplayParameter::setGridRelativePositionX(int gridRelativePositionX)
{
    if (m_gridRelativePositionX != gridRelativePositionX)
        qDebug() << "[DP] setGridRelativePositionX" << m_gridRelativePositionX << "->" << gridRelativePositionX;
    m_gridRelativePositionX = gridRelativePositionX;
    emit gridRelativePositionXChanged();
}

int DisplayParameter::gridRelativePositionY() const
{
    return m_gridRelativePositionY;
}

void DisplayParameter::setGridRelativePositionY(int gridRelativePositionY)
{
    m_gridRelativePositionY = gridRelativePositionY;
    emit gridRelativePositionYChanged();
}

int DisplayParameter::zLayer() const
{
    return m_zLayer;
}

void DisplayParameter::setZLayer(int zLayer)
{
    m_zLayer = zLayer;
    emit zLayerChanged();
}

double DisplayParameter::effectBrightness() const
{
    return m_effectBrightness;
}

void DisplayParameter::setEffectBrightness(double effectBrightness)
{
    m_effectBrightness = effectBrightness;
    emit effectBrightnessChanged();
}

double DisplayParameter::effectContrast() const
{
    return m_effectContrast;
}

void DisplayParameter::setEffectContrast(double effectContrast)
{
    m_effectContrast = effectContrast;
    emit effectContrastChanged();
}

double DisplayParameter::effectSaturation() const
{
    return m_effectSaturation;
}

void DisplayParameter::setEffectSaturation(double effectSaturation)
{
    m_effectSaturation = effectSaturation;
    emit effectSaturationChanged();
}

double DisplayParameter::effectColorization() const
{
    return m_effectColorization;
}

void DisplayParameter::setEffectColorization(double effectColorization)
{
    m_effectColorization = effectColorization;
    emit effectColorizationChanged();
}

QColor DisplayParameter::effectColorizationColor() const
{
    return m_effectColorizationColor;
}

void DisplayParameter::setEffectColorizationColor(QColor effectColorizationColor)
{
    m_effectColorizationColor = effectColorizationColor;
    emit effectColorizationColorChanged();
}

bool DisplayParameter::effectBlurEnabled() const
{
    return m_effectBlurEnabled;
}

void DisplayParameter::setEffectBlurEnabled(bool effectBlurEnabled)
{
    m_effectBlurEnabled = effectBlurEnabled;
    emit effectBlurEnabledChanged();
}

double DisplayParameter::effectBlur() const
{
    return m_effectBlur;    
}

void DisplayParameter::setEffectBlur(double effectBlur)
{
    m_effectBlur = effectBlur;
    emit effectBlurChanged();
}

int DisplayParameter::effectBlurMax() const
{
    return m_effectBlurMax;
}

void DisplayParameter::setEffectBlurMax(int effectBlurMax)
{
    m_effectBlurMax = effectBlurMax;
    emit effectBlurMaxChanged();
}

double DisplayParameter::effectBlurMultiplier() const
{
    return m_effectBlurMultiplier;
}

void DisplayParameter::setEffectBlurMultiplier(double effectBlurMultiplier)
{
    m_effectBlurMultiplier = effectBlurMultiplier;
    emit effectBlurMultiplierChanged();
}

bool DisplayParameter::effectShadowEnabled() const
{
    return m_effectShadowEnabled;
}

void DisplayParameter::setEffectShadowEnabled(bool effectShadowEnabled)
{
    m_effectShadowEnabled = effectShadowEnabled;
    emit effectShadowEnabledChanged();
}

double DisplayParameter::effectShadowBlur() const
{
    return m_effectShadowBlur;
}

void DisplayParameter::setEffectShadowBlur(double effectShadowBlur)
{
    m_effectShadowBlur = effectShadowBlur;
    emit effectShadowBlurChanged();
}

QColor DisplayParameter::effectShadowColor() const
{
    return m_effectShadowColor;
}

void DisplayParameter::setEffectShadowColor(QColor effectShadowColor)
{
    m_effectShadowColor = effectShadowColor;
    emit effectShadowColorChanged();
}

double DisplayParameter::effectShadowHorizontalOffset() const
{
    return m_effectShadowHorizontalOffset;
}

void DisplayParameter::setEffectShadowHorizontalOffset(double effectShadowHorizontalOffset)
{
    m_effectShadowHorizontalOffset = effectShadowHorizontalOffset;
    emit effectShadowHorizontalOffsetChanged();
}

double DisplayParameter::effectShadowVerticalOffset() const
{
    return m_effectShadowVerticalOffset;
}

void DisplayParameter::setEffectShadowVerticalOffset(double effectShadowVerticalOffset)
{
    m_effectShadowVerticalOffset = effectShadowVerticalOffset;
    emit effectShadowVerticalOffsetChanged();
}

double DisplayParameter::effectShadowOpacity() const
{
    return m_effectShadowOpacity;
}

void DisplayParameter::setEffectShadowOpacity(double effectShadowOpacity)
{
    m_effectShadowOpacity = effectShadowOpacity;
    emit effectShadowOpacityChanged();
}

double DisplayParameter::effectShadowScale() const
{
    return m_effectShadowScale;
}

void DisplayParameter::setEffectShadowScale(double effectShadowScale)
{
    m_effectShadowScale = effectShadowScale;
    emit effectShadowScaleChanged();
}

// Rotation methods
double DisplayParameter::rotationAngle() const
{
    return m_rotationAngle;
}

void DisplayParameter::setRotationAngle(double rotationAngle)
{
    m_rotationAngle = rotationAngle;
    emit rotationAngleChanged();
}



// Mirror methods
bool DisplayParameter::mirrorHorizontal() const
{
    return m_mirrorHorizontal;
}

void DisplayParameter::setMirrorHorizontal(bool mirrorHorizontal)
{
    m_mirrorHorizontal = mirrorHorizontal;
    emit mirrorHorizontalChanged();
}

bool DisplayParameter::mirrorVertical() const
{
    return m_mirrorVertical;
}

void DisplayParameter::setMirrorVertical(bool mirrorVertical)
{
    m_mirrorVertical = mirrorVertical;
    emit mirrorVerticalChanged();
}

float DisplayParameter::zOrder() const
{
    return m_zOrder;

}

void DisplayParameter::setZOrder(float newZOrder)
{
    if (qFuzzyCompare(m_zOrder, newZOrder))
        return;
    m_zOrder = newZOrder;
    emit zOrderChanged();
}
