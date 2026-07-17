// Pathologique — tentative d'accès à un singleton du jeu masqué.
//
// Attendu : `load_failed` en P2 (erreur de référence). C'est la PREUVE du
// masquage (critère R1 n°4, première brique mesurée de l'étage 2 / D13) : dans
// le contexte restreint, `Game`, `Catway`, etc. sont ré-exposés en `undefined`
// → `Game.currentMap` lève un TypeError capté par le canal warnings du banc.
import QtQuick

Item {
    id: root

    Component.onCompleted: {
        // Chacun de ces accès doit produire un TypeError (objet = undefined).
        const m = Game.currentMap;              // singleton de jeu masqué
        const p = Catway.lastLocalPort();       // réseau masqué
        GameApi.memory.set("volé", String(m) + String(p));
    }
}
