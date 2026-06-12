import QtQuick

/*
 * ScreenEffectController — logique (non visuelle) des effets visuels de zone.
 *
 * S'abonne aux signaux entrée/sortie de zone du moteur physique
 * (pattounxWorld.actorEnteredZone / actorExitedZone), résout l'id de zone vers
 * le ScreenEffect référencé par la zone (ZoneParameter.screenEffectId →
 * MapInfo.screenEffectById), et expose l'effet actif + un facteur de fondu
 * `amount` (0→1) animé.
 *
 * Plusieurs zones peuvent se chevaucher : on gère une pile, l'effet visible est
 * celui de la dernière zone entrée encore active (LIFO). `renderEffect` garde le
 * dernier effet non nul pendant le fondu de sortie pour ne pas couper net.
 *
 * Vue associée : ScreenEffectOverlay.qml (teinte + vignette) + un layer
 * MultiEffect sur la View3D pour le flou/désaturation (câblé côté Editor.qml).
 */
Item {
    id: root
    // Non visuel.
    width: 0; height: 0
    visible: false

    // --- Entrées ---
    /// Façade physique (context property `pattounxWorld`).
    property var physicsWorld: null
    /// Liste des tuiles de l'éditeur (snapableTilesList) pour résoudre zoneId→tile.
    property var tilesList: []
    /// MapInfo courant (bibliothèque d'effets).
    property var mapInfo: null
    /// Si non vide, seules les entrées/sorties de cet acteur déclenchent un effet
    /// (utile pour ne réagir qu'au joueur local). Vide = tous les acteurs.
    property string onlyActorId: ""

    // --- Sorties ---
    /// Effet ciblé actuellement (null si dans aucune zone à effet).
    property var activeEffect: null
    /// Dernier effet non nul — conservé pendant le fondu de sortie.
    property var renderEffect: null
    /// Facteur de fondu 0→1, animé selon fadeInMs/fadeOutMs de l'effet.
    property real amount: 0.0

    // Pile interne des zones actives porteuses d'un effet : [{ zoneId, effectId }]
    property var _stack: []

    // ---------------------------------------------------------------------
    // Résolution zoneId → effectId via la tuile de zone
    // ---------------------------------------------------------------------
    function _effectIdForZone(zoneId) {
        const list = root.tilesList
        if (!list) return ""
        // L'id de zone côté physique = ItemSnapable.uniqueId.toString() (cf.
        // EditorPhysicsBridge._idForTile). Les éléments de snapableTilesList sont
        // les SnapableElement QML : l'uuid et le ZoneParameter sont sous
        // `.snapableParameters`.
        for (let i = 0; i < list.length; ++i) {
            const t = list[i]
            const sp = t ? t.snapableParameters : null
            if (!sp || !sp.uniqueId) continue
            if (sp.uniqueId.toString() === zoneId) {
                const zp = sp.zoneParameter
                return (zp && zp.screenEffectId) ? zp.screenEffectId : ""
            }
        }
        return ""
    }

    function _resolveEffect(effectId) {
        if (!effectId || !root.mapInfo) return null
        return root.mapInfo.screenEffectById(effectId)
    }

    function _recomputeActive() {
        // L'effet visible = dernière entrée de pile dont l'effet existe encore.
        for (let i = root._stack.length - 1; i >= 0; --i) {
            const e = _resolveEffect(root._stack[i].effectId)
            if (e) { root.activeEffect = e; return }
        }
        root.activeEffect = null
    }

    function _matchesActor(actorId) {
        return root.onlyActorId === "" || actorId === root.onlyActorId
    }

    function _onEntered(actorId, zoneId) {
        if (!_matchesActor(actorId)) return
        const effectId = _effectIdForZone(zoneId)
        if (!effectId) return
        // Copie pour déclencher le binding (mutation en place non observée).
        const next = root._stack.slice()
        next.push({ zoneId: zoneId, effectId: effectId })
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

    /// Réinitialise tout (ex: changement de carte, sortie de l'éditeur).
    function reset() {
        root._stack = []
        root.activeEffect = null
    }

    // root.mapInfo est recréé à chaque commit de métadonnées (Game.updateMapMetadata)
    // → re-résoudre l'effet actif contre la nouvelle instance pour éviter une
    // référence morte / une édition live qui ne se reflète pas.
    onMapInfoChanged: _recomputeActive()

    // ---------------------------------------------------------------------
    // Fondu : pilote `amount` et garde `renderEffect` pendant la sortie
    // ---------------------------------------------------------------------
    onActiveEffectChanged: {
        if (activeEffect) {
            renderEffect = activeEffect
            _amountBehavior.duration = activeEffect.fadeInMs
            amount = 1.0
        } else {
            _amountBehavior.duration = renderEffect ? renderEffect.fadeOutMs : 300
            amount = 0.0
        }
    }

    Behavior on amount {
        id: _amountBehavior
        property int duration: 350
        NumberAnimation { duration: _amountBehavior.duration; easing.type: Easing.InOutQuad }
    }

    // Libère renderEffect une fois le fondu de sortie terminé (évite de garder
    // une réf morte ; purement défensif).
    onAmountChanged: {
        if (amount <= 0.001 && !activeEffect)
            renderEffect = null
    }

    Connections {
        target: root.physicsWorld
        ignoreUnknownSignals: true
        function onActorEnteredZone(actorId, zoneId) { root._onEntered(actorId, zoneId) }
        function onActorExitedZone(actorId, zoneId)  { root._onExited(actorId, zoneId) }
    }
}
