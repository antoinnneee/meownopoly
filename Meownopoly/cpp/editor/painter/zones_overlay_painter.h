// Composant 2D unique pour dessiner toutes les zones d'exclusion d'une
// scène d'édition. Remplace les N `ZoneCanvasPainter` (1 par tile) qui
// devenaient ingérables au zoom extrême : leur backing texture suivait
// la taille de l'item (= bbox zone × gridSize) et explosait à mmSize=200+
// (centaines de MB par tile, freeze GPU >1 s par cran de zoom).
//
// Architecture identique au GridCanvasPainter :
//   - L'item couvre le VIEWPORT visible, pas la scène entière.
//   - Reçoit la liste des zones via `zones` (QVariantList) en coords grille.
//   - Pour chaque zone : compute bbox écran, viewport-cull, dessine
//     fill + stroke + hachures uniquement si visible.
//   - Le hit-testing/control-points/label restent dans
//     SnapableExclusionZone (gérés en QML).
//
// Compilé uniquement si MEOW_HAS_CANVAS_PAINTER est défini.

#pragma once

#ifdef MEOW_HAS_CANVAS_PAINTER

#include <QtCanvasPainter/QCanvasPainterItem>
#include <QColor>
#include <QVariantList>

class ZonesOverlayPainter : public QCanvasPainterItem
{
    Q_OBJECT
    // Liste de zones — chaque entrée est un QVariantMap :
    //   {
    //     posGridX: real, posGridY: real,    // origine en coords grille
    //     points  : [ {x: real, y: real}, ... ], // polygone grille-local
    //     color   : QColor,                  // teinte zone (fill 15%, hachures 60%)
    //     strokeColor: QColor,
    //     strokeWidth: real (défaut 2),
    //     hatchSpacing: real (défaut 12),
    //     opacity: real (défaut 1)
    //   }
    Q_PROPERTY(QVariantList zones READ zones WRITE setZones NOTIFY zonesChanged)
    Q_PROPERTY(qreal gridSize READ gridSize WRITE setGridSize NOTIFY gridSizeChanged)
    Q_PROPERTY(qreal viewportOffsetX READ viewportOffsetX WRITE setViewportOffsetX NOTIFY viewportOffsetXChanged)
    Q_PROPERTY(qreal viewportOffsetY READ viewportOffsetY WRITE setViewportOffsetY NOTIFY viewportOffsetYChanged)

public:
    explicit ZonesOverlayPainter(QQuickItem *parent = nullptr);
    ~ZonesOverlayPainter() override;

    QCanvasPainterItemRenderer *createItemRenderer() const override;

    QVariantList zones() const { return m_zones; }
    qreal gridSize() const { return m_gridSize; }
    qreal viewportOffsetX() const { return m_viewportOffsetX; }
    qreal viewportOffsetY() const { return m_viewportOffsetY; }

    void setZones(const QVariantList &v);
    void setGridSize(qreal v);
    void setViewportOffsetX(qreal v);
    void setViewportOffsetY(qreal v);

signals:
    void zonesChanged();
    void gridSizeChanged();
    void viewportOffsetXChanged();
    void viewportOffsetYChanged();

private:
    QVariantList m_zones;
    qreal m_gridSize = 1.0;
    qreal m_viewportOffsetX = 0.0;
    qreal m_viewportOffsetY = 0.0;
};

#endif // MEOW_HAS_CANVAS_PAINTER
