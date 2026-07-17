// Corpus banc d'essai (doc 12 §8) — allocation massive en boucle.
// Attendu : PASSE P0 (statiquement licite), puis `runaway_alloc` (watchdog
// RSS 512 Mo) ou `object_quota` (> 200 objets D34) au banc.
import QtQuick

Item {
    id: root
    property var hoard: []

    Component.onCompleted: {
        for (let i = 0; i < 100000000; ++i) {
            root.hoard.push(new Array(4096).fill(i))
        }
    }
}
