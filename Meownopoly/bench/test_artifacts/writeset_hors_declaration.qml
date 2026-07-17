// Corpus banc d'essai (doc 12 §8) — écriture mémoire hors write-set déclaré.
// Attendu : PASSE P0 (l'écriture est syntaxiquement licite ; le write-set
// déclaré n'est comparable qu'à l'exécution), puis `writeset_violation` en P4
// au banc (write-set observé ≠ déclaré, D11). Write-set déclaré supposé :
// ["state/compteur"] — "state/clef_pirate" n'y figure pas.
import QtQuick
import Meow.GameApi

Item {
    Component.onCompleted: {
        events.on("zoneEntered", function (ev) {
            memory.set("state/compteur", (memory.get("state/compteur") || 0) + 1)
            // Écriture NON déclarée dans le write-set de la proposition :
            memory.set("state/clef_pirate", ev.playerId)
        })
    }
}
