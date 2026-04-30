// Composant 2D rapide pour dessiner les zones d'exclusion polygonales.
// Utilise la nouvelle API QtCanvasPainter (Tech Preview Qt 6.11) qui rend
// nativement sur GPU via QRhi — bcp plus rapide que `Canvas` QML (QPainter
// CPU) avec 100+ instances.
//
// Compilé uniquement si MEOW_HAS_CANVAS_PAINTER est défini (CanvasPainter
// disponible). Sinon, tomber sur le Canvas QML existant.

#pragma once

#ifdef MEOW_HAS_CANVAS_PAINTER

#include <QtCanvasPainter/QCanvasPainterItem>
#include <QColor>
#include <QPointF>
#include <QVariantList>

class ZoneCanvasPainter : public QCanvasPainterItem
{
    Q_OBJECT
    Q_PROPERTY(QVariantList polygonPoints READ polygonPoints WRITE setPolygonPoints NOTIFY polygonPointsChanged)
    Q_PROPERTY(qreal gridSize READ gridSize WRITE setGridSize NOTIFY gridSizeChanged)
    Q_PROPERTY(QColor zoneColor READ zoneColor WRITE setZoneColor NOTIFY zoneColorChanged)
    Q_PROPERTY(QColor strokeColor READ strokeColor WRITE setStrokeColor NOTIFY strokeColorChanged)
    Q_PROPERTY(qreal strokeWidth READ strokeWidth WRITE setStrokeWidth NOTIFY strokeWidthChanged)
    Q_PROPERTY(qreal hatchSpacing READ hatchSpacing WRITE setHatchSpacing NOTIFY hatchSpacingChanged)

public:
    explicit ZoneCanvasPainter(QQuickItem *parent = nullptr);

    QCanvasPainterItemRenderer *createItemRenderer() const override;

    QVariantList polygonPoints() const { return m_polygonPoints; }
    qreal gridSize() const { return m_gridSize; }
    QColor zoneColor() const { return m_zoneColor; }
    QColor strokeColor() const { return m_strokeColor; }
    qreal strokeWidth() const { return m_strokeWidth; }
    qreal hatchSpacing() const { return m_hatchSpacing; }

    // Conversion accessible au renderer (synchronize) : passe par
    // QVariantList pour rester compatible JSON/QML, le renderer convertit
    // en QList<QPointF> pixel pour le draw.
    QList<QPointF> polygonPointsPx() const;

    void setPolygonPoints(const QVariantList &v);
    void setGridSize(qreal v);
    void setZoneColor(const QColor &v);
    void setStrokeColor(const QColor &v);
    void setStrokeWidth(qreal v);
    void setHatchSpacing(qreal v);

signals:
    void polygonPointsChanged();
    void gridSizeChanged();
    void zoneColorChanged();
    void strokeColorChanged();
    void strokeWidthChanged();
    void hatchSpacingChanged();

private:
    QVariantList m_polygonPoints;
    qreal m_gridSize = 1.0;
    QColor m_zoneColor = QColor("#FF5722");
    QColor m_strokeColor = QColor("#B23F1A");
    qreal m_strokeWidth = 2.0;
    qreal m_hatchSpacing = 12.0;
};

#endif // MEOW_HAS_CANVAS_PAINTER
