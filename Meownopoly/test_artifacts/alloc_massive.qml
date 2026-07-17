// Pathologique — allocation massive retenue en mémoire.
//
// Attendu : `runaway_alloc` (ou `object_quota`). L'artefact retient un gros
// ballast en mémoire, faisant exploser la RSS attribuable bien au-delà du
// budget D34 (8 Mo de delta depuis la baseline P1). Le watchdog du banc
// échantillonne le pic RSS ; le dépassement est verdicté en P4.
//
// Pas de `Qt.createQmlObject` (interdit P0) : une allocation JS retenue suffit.
import QtQuick

Item {
    id: root

    // Retenu pour la durée de vie de l'artefact → compte dans le pic mémoire.
    property var ballast: []

    Component.onCompleted: {
        // ~8 M entrées : dizaines de Mo, largement au-dessus des 8 Mo permis.
        for (let i = 0; i < 8000000; ++i)
            root.ballast.push(i * 3.14159);
    }
}
