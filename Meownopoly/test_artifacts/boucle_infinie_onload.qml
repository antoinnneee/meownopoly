// Pathologique — boucle infinie au chargement (`Component.onCompleted`).
//
// Attendu : `load_timeout` (P2). Le watchdog du banc tue le process au-delà de
// MEOW_BENCH_LOAD_TIMEOUT_MS ; le GUI du jeu superviseur n'est JAMAIS gelé
// (critère R1 n°1 : fiabilité du kill).
import QtQuick

Item {
    id: root

    Component.onCompleted: {
        // Aucune sortie : le chargement ne rend jamais la main.
        while (true) {
            // busy-loop
        }
    }
}
