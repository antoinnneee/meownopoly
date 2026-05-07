// Calcul pur (sans painter) des segments de hachures pour une zone
// d'exclusion polygonale. Découpé du renderer pour permettre :
//  - le précompute côté item (main thread, dans les setters)
//  - le précompute async (QThreadPool)
//  - les variantes intra-paint (QtConcurrent sur edges / hatches) testables
//
// QCanvasPainter n'étant pas thread-safe, on calcule UNIQUEMENT des données
// (QVector<float>) ici. Le draw effectif reste dans le renderer.

#pragma once

#ifdef MEOW_HAS_CANVAS_PAINTER

#include <QList>
#include <QPointF>
#include <QVector>

namespace zone_painter {

// Modes de parallélisation (sélectionné via env var MEOW_ZONE_PARALLEL_MODE,
// lu une seule fois au premier appel à `currentParallelMode()`). Le mode
// pilote la place où le scanline est fait (paint vs sync vs setter) ET la
// méthode (séquentiel vs QtConcurrent vs async).
enum class ParallelMode : quint8 {
    Baseline = 0,        // intra-paint, séquentiel (état actuel pré-essais)
    QtcHatches,          // intra-paint, QtConcurrent sur la boucle scanline
    QtcEdges,            // intra-paint, QtConcurrent sur le pré-calcul edges
    Precompute,          // calcul dans setters (main thread synchrone), cache
    PrecomputeAsync,     // calcul async via QThreadPool, cache + update() au ready
};

// Lit MEOW_ZONE_PARALLEL_MODE une fois (cas insensible) et cache la valeur.
// Valeurs reconnues : "baseline" (default), "qtc-hatches", "qtc-edges",
// "precompute", "precompute-async".
ParallelMode currentParallelMode();
const char *parallelModeName(ParallelMode m);

// Cœur du scanline. Pour les modes Baseline / QtcEdges / QtcHatches /
// Precompute*. Le format de sortie est un buffer plat de floats : 4 floats
// par segment (x0, y0, x1, y1).
//   - `pointsPx` : sommets du polygone en pixels locaux.
//   - `hatchSpacing` : pas perpendiculaire des hachures (en pixels logique
//     avant *sqrt(2) appliqué dans la fonction).
QVector<float> computeHatchSegments(const QList<QPointF> &pointsPx,
                                    qreal hatchSpacing);

// Variante : edges pré-calculées en parallèle via QtConcurrent. Utile pour
// stresser le coût de pré-calcul sur des polygones avec beaucoup de sommets.
QVector<float> computeHatchSegments_QtcEdges(const QList<QPointF> &pointsPx,
                                             qreal hatchSpacing);

// Variante : boucle scanline parallélisée via QtConcurrent. Chaque tâche
// traite un range de hachures. Le merge final concatène les sous-buffers.
QVector<float> computeHatchSegments_QtcHatches(const QList<QPointF> &pointsPx,
                                               qreal hatchSpacing);

} // namespace zone_painter

#endif // MEOW_HAS_CANVAS_PAINTER
