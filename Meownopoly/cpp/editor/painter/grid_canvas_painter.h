// Composant 2D rapide pour dessiner la grille de l'éditeur.
// Remplace le Repeater historique (1202 Rectangle pour 600 croisillons) par
// un seul item GPU avec viewport culling — on ne trace que les lignes
// effectivement visibles à l'écran.
//
// L'item est positionné dans le QML pour COUVRIR le viewport visible (i.e.
// la zone visible du Base_Board parent du GridManager), pas la grille
// entière. La grille peut s'étendre sur 7200×7200 px — instancier un canvas
// de cette taille saturerait la VRAM (200+ Mo). En se limitant au viewport
// (~1280×720), le backing store reste raisonnable et le culling devient
// "gratuit" : ce qui est hors viewport n'est jamais rasterisé.
//
// Inputs côté QML :
//   - paramètres grille  : croisillons, gridSize, gridColor, gridOpacity,
//                          lineWidth, resizeMode, showGrid
//   - position du GridManager dans son parent : viewportOffsetX/Y
//     (= gridManager.x/y, lus côté QML et passés ici)
//
// Compilé uniquement si MEOW_HAS_CANVAS_PAINTER est défini.

#pragma once

#ifdef MEOW_HAS_CANVAS_PAINTER

#include <QtCanvasPainter/QCanvasPainterItem>
#include <QColor>

class GridCanvasPainter : public QCanvasPainterItem
{
    Q_OBJECT
    Q_PROPERTY(int croisillons READ croisillons WRITE setCroisillons NOTIFY croisillonsChanged)
    Q_PROPERTY(qreal gridSize READ gridSize WRITE setGridSize NOTIFY gridSizeChanged)
    Q_PROPERTY(QColor gridColor READ gridColor WRITE setGridColor NOTIFY gridColorChanged)
    Q_PROPERTY(qreal gridOpacity READ gridOpacity WRITE setGridOpacity NOTIFY gridOpacityChanged)
    Q_PROPERTY(qreal lineWidth READ lineWidth WRITE setLineWidth NOTIFY lineWidthChanged)
    Q_PROPERTY(bool resizeMode READ resizeMode WRITE setResizeMode NOTIFY resizeModeChanged)
    Q_PROPERTY(bool showGrid READ showGrid WRITE setShowGrid NOTIFY showGridChanged)
    Q_PROPERTY(qreal viewportOffsetX READ viewportOffsetX WRITE setViewportOffsetX NOTIFY viewportOffsetXChanged)
    Q_PROPERTY(qreal viewportOffsetY READ viewportOffsetY WRITE setViewportOffsetY NOTIFY viewportOffsetYChanged)

public:
    explicit GridCanvasPainter(QQuickItem *parent = nullptr);
    ~GridCanvasPainter() override;

    QCanvasPainterItemRenderer *createItemRenderer() const override;

    int croisillons() const { return m_croisillons; }
    qreal gridSize() const { return m_gridSize; }
    QColor gridColor() const { return m_gridColor; }
    qreal gridOpacity() const { return m_gridOpacity; }
    qreal lineWidth() const { return m_lineWidth; }
    bool resizeMode() const { return m_resizeMode; }
    bool showGrid() const { return m_showGrid; }
    qreal viewportOffsetX() const { return m_viewportOffsetX; }
    qreal viewportOffsetY() const { return m_viewportOffsetY; }

    void setCroisillons(int v);
    void setGridSize(qreal v);
    void setGridColor(const QColor &v);
    void setGridOpacity(qreal v);
    void setLineWidth(qreal v);
    void setResizeMode(bool v);
    void setShowGrid(bool v);
    void setViewportOffsetX(qreal v);
    void setViewportOffsetY(qreal v);

signals:
    void croisillonsChanged();
    void gridSizeChanged();
    void gridColorChanged();
    void gridOpacityChanged();
    void lineWidthChanged();
    void resizeModeChanged();
    void showGridChanged();
    void viewportOffsetXChanged();
    void viewportOffsetYChanged();

private:
    int m_croisillons = 600;
    qreal m_gridSize = 1.0;
    QColor m_gridColor = QColor("#80808080");
    qreal m_gridOpacity = 0.5;
    qreal m_lineWidth = 1.0;
    bool m_resizeMode = false;
    bool m_showGrid = true;
    qreal m_viewportOffsetX = 0.0;
    qreal m_viewportOffsetY = 0.0;
};

#endif // MEOW_HAS_CANVAS_PAINTER
