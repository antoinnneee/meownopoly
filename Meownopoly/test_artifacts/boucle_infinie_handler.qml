// Pathologique — boucle infinie DANS un handler d'événement.
//
// Attendu : `event_budget` (ou `bench_timeout`) en P4. Le chargement se passe
// bien ; c'est à la première stimulation (`boom`) que le handler ne rend pas la
// main → le watchdog de dispatch P4 tue le process (critère R1 n°1).
import QtQuick

Item {
    id: root

    Component.onCompleted: {
        GameApi.events.on("boom", function(evt) {
            // Ne rend jamais la main une fois l'événement reçu.
            while (true) {
                // busy-loop
            }
        });
    }
}
