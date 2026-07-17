// Corpus banc d'essai (doc 12 §8) — tentative d'accès aux singletons du jeu.
// Attendu : PASSE P0 (une référence non résolue n'est pas décidable
// statiquement sans la liste des symboles du contexte), puis `load_failed`
// (ReferenceError) en P2 au banc — c'est la PREUVE du masquage de contexte
// (critère R1 n°4, doc 12 §8).
import QtQuick

Item {
    Component.onCompleted: {
        // Ces symboles existent dans le jeu mais ne doivent pas exister dans
        // le contexte restreint de l'artefact.
        Game.updateMap()
        Catway.broadcastRaw("EC:pwned;0;0")
        MapFileManager.saveMap()
    }
}
