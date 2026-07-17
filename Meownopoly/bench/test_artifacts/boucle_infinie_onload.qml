// Corpus banc d'essai (doc 12 §8) — boucle infinie au chargement.
// Attendu : PASSE P0 (statiquement licite), puis `load_timeout` en P2 au
// banc (> MEOW_BENCH_LOAD_TIMEOUT_MS), le jeu superviseur ne gèle jamais.
import QtQuick

Item {
    Component.onCompleted: {
        let x = 0
        while (true) {
            x = x + 1
        }
    }
}
