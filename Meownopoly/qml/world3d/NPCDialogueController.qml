import QtQuick
import ItemSnapable

/*
 * NPCDialogueController — logique (non visuelle) des dialogues de PNJ.
 *
 * Copie du pattern ScreenEffectController : s'abonne aux signaux
 * entrée/sortie de zone du moteur physique (pattounxWorld.actorEnteredZone /
 * actorExitedZone), résout l'id de zone vers le PNJ lié (la zone de trigger
 * est le `next` du PNJ → on remonte par getPrevList), et pilote l'état du
 * dialogue : PNJ actif, index de ligne, pile pour zones chevauchantes (LIFO).
 *
 * Modes gérés :
 *  - Proximity : ouvert par actorEnteredZone, fermé par actorExitedZone
 *    (ou en fin de séquence).
 *  - Click : ouvert par openFor(npcTile), appelé par le badge 💬 de
 *    NPCDialogueOverlay.
 *  - Always : rendu directement par l'overlay (pancarte), pas d'état ici.
 *
 * Vue associée : NPCDialogueOverlay.qml (bulle + badges), enfant de workArea.
 */
Item {
    id: root
    // Non visuel.
    width: 0; height: 0
    visible: false

    // --- Entrées ---
    /// Façade physique (context property `pattounxWorld`).
    property var physicsWorld: null
    /// Liste des tuiles de l'éditeur (snapableTilesList) pour résoudre
    /// zoneId → tile de zone → PNJ lié.
    property var tilesList: []
    /// Si non vide, seules les entrées/sorties de cet acteur déclenchent le
    /// dialogue (le joueur local). Vide = tous les acteurs.
    property string onlyActorId: ""

    // --- Sorties ---
    /// Tile QML (SnapableNPC) du PNJ dont le dialogue est affiché. Null si aucun.
    property var activeNpcTile: null
    /// Index de la ligne courante dans la séquence.
    property int lineIndex: 0

    // Pile interne des zones actives porteuses d'un PNJ : [{ zoneId, npcTile }]
    property var _stack: []

    // ---------------------------------------------------------------------
    // Résolution zoneId → PNJ lié
    // ---------------------------------------------------------------------
    function _npcTileForZone(zoneId) {
        const list = root.tilesList
        if (!list) return null
        for (let i = 0; i < list.length; ++i) {
            const t = list[i]
            const sp = t ? t.snapableParameters : null
            if (!sp || !sp.uniqueId) continue
            if (sp.uniqueId.toString() !== zoneId) continue
            // Zone trouvée → remonter au PNJ source (PNJ --next--> zone).
            const prevs = sp.getPrevList()
            for (let j = 0; j < prevs.length; j++) {
                const cand = prevs[j]
                if (!cand || cand.tileType !== ItemSnapable.NPCTile) continue
                if (!cand.npcParameter || cand.npcParameter.lineCount() === 0) continue
                if (cand.npcParameter.triggerMode !== 0 /* Proximity */) continue
                // Résoudre la tile QML du PNJ.
                for (let k = 0; k < list.length; k++) {
                    if (list[k] && list[k].snapableParameters === cand)
                        return list[k]
                }
            }
            return null
        }
        return null
    }

    function _matchesActor(actorId) {
        return root.onlyActorId === "" || actorId === root.onlyActorId
    }

    function _recomputeActive() {
        // Le dialogue visible = dernière entrée de pile encore valide.
        for (let i = root._stack.length - 1; i >= 0; --i) {
            const t = root._stack[i].npcTile
            if (t && t.snapableParameters) { _setActive(t); return }
        }
        _setActive(null)
    }

    function _setActive(tile) {
        if (root.activeNpcTile === tile) return
        root.activeNpcTile = tile
        root.lineIndex = 0
    }

    function _onEntered(actorId, zoneId) {
        if (!_matchesActor(actorId)) return
        const npcTile = _npcTileForZone(zoneId)
        if (!npcTile) return
        // Copie pour déclencher le binding (mutation en place non observée).
        const next = root._stack.slice()
        next.push({ zoneId: zoneId, npcTile: npcTile })
        root._stack = next
        _recomputeActive()
    }

    function _onExited(actorId, zoneId) {
        if (!_matchesActor(actorId)) return
        const next = root._stack.slice()
        for (let i = next.length - 1; i >= 0; --i) {
            if (next[i].zoneId === zoneId) { next.splice(i, 1); break }
        }
        root._stack = next
        _recomputeActive()
    }

    // ---------------------------------------------------------------------
    // API mode Clic + avance de séquence
    // ---------------------------------------------------------------------
    /// Ouvre (ou ferme si déjà ouvert) le dialogue d'un PNJ au clic.
    function openFor(npcTile) {
        if (root.activeNpcTile === npcTile) { close(); return }
        root._stack = []   // le clic prend la main sur la proximité
        _setActive(npcTile)
    }

    /// Avance d'une ligne ; ferme en fin de séquence.
    function advance() {
        const t = root.activeNpcTile
        const npc = t && t.snapableParameters ? t.snapableParameters.npcParameter : null
        if (!npc) { close(); return }
        if (root.lineIndex + 1 < npc.lineCount())
            root.lineIndex = root.lineIndex + 1
        else
            close()
    }

    /// Ferme le dialogue courant (la pile de proximité est purgée : le
    /// joueur devra ressortir/rentrer dans la zone pour relancer).
    function close() {
        root._stack = []
        _setActive(null)
    }

    /// Réinitialise tout (ex: changement de carte, sortie de l'éditeur).
    function reset() { close() }

    // tilesList recréée / rechargée → les références de la pile peuvent être
    // mortes ; re-résoudre (même raison que onMapInfoChanged côté
    // ScreenEffectController).
    onTilesListChanged: _recomputeActive()

    Connections {
        target: root.physicsWorld
        ignoreUnknownSignals: true
        function onActorEnteredZone(actorId, zoneId) { root._onEntered(actorId, zoneId) }
        function onActorExitedZone(actorId, zoneId)  { root._onExited(actorId, zoneId) }
    }
}
