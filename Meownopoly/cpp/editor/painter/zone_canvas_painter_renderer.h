#pragma once

#ifdef MEOW_HAS_CANVAS_PAINTER

#include <QtCanvasPainter/QCanvasPainterItemRenderer>
#include <QColor>
#include <QList>
#include <QPointF>

class ZoneCanvasPainter;
class QCanvasPainter;

class ZoneCanvasPainterRenderer : public QCanvasPainterItemRenderer
{
public:
    ZoneCanvasPainterRenderer();

    void synchronize(QCanvasPainterItem *item) override;
    void paint(QCanvasPainter *painter) override;

private:
    // Construit le path du polygone dans `painter` (beginPath + moveTo +
    // lineTo + closePath). Réutilisé pour fill puis stroke.
    void buildPolygonPath(QCanvasPainter *painter) const;

    // Trace les hachures diagonales clippées au polygone. Comme
    // QCanvasPainter ne supporte pas clip(path) (seulement clip rect),
    // on calcule manuellement les segments visibles via intersections
    // ligne/arêtes.
    void drawHatches(QCanvasPainter *painter) const;

    QList<QPointF> m_points;
    QColor m_zoneColor;
    QColor m_strokeColor;
    qreal m_strokeWidth = 2.0;
    qreal m_hatchSpacing = 12.0;
};

#endif // MEOW_HAS_CANVAS_PAINTER
