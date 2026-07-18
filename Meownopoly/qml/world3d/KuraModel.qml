import QtQuick
import QtQuick3D
import QtQuick3D.AssetUtils

/*
 * KuraModel — présentateur 3D d'un modèle "Color ID Map".
 *
 * Charge un .glb via RuntimeLoader (format kuraViewer, sans balsam) et applique
 * un KuraMaterial partagé à tous les Model de l'arbre chargé (overrideMaterials).
 * La config de skin/variante (+ teinte d'équipe) est distribuée sur le matériau.
 *
 * Utilisé par World3D, Model3DPreview et PCP_Profile3DPreview → un seul endroit
 * à maintenir. Cf. doc/architecture/COLOR_ID_MAP_INTEGRATION_PLAN.md §6.
 */
Node {
    id: root

    // --- Sources ---
    property url glbUrl                          // base/<Model>.glb
    property url baseColorUrl                    // base/skin_base.png (la "peau")
    property url colorMapUrl                     // skins/<skin>/colorMap.png
    property url skinUrl                         // .../skins/<skin>/  (pour résoudre textures/)

    // --- Référence bibliothèque officielle V3 (M11, D18) ---
    // Métadonnées de traçabilité : version semver + hash de contenu du package
    // dont provient ce modèle. Informatif (diagnostic/outillage) — la résolution
    // effective est faite en amont (SkinnedModel.resolveModelReference).
    property string packageVersion: ""
    property string contentHash: ""

    // Bibliothèque de textures du skin courant : [{ name, file }]
    property var textureLib: []

    // Nombre de zones du skin (skin.json). Sert au clamp.
    property int slotCount: 1

    readonly property int maxSlots: 20
    readonly property int maxTex: 8

    // Un skin n'est appliqué que si on a une colorMap ET une base color.
    // Sinon (ex: modèle .glb sans colorMap, comme Princess pour l'instant),
    // on laisse les matériaux natifs du .glb intacts (rendu d'origine).
    readonly property bool skinActive: String(colorMapUrl).length > 0
                                       && String(baseColorUrl).length > 0

    // --- Config (variante) ---
    // { baseTint, baseTintMode, baseTintStrength,
    //   slots: [ { tint, tintMode, tintStrength, texture(=nom), texOpacity, texTint, texInvert } ] }
    property var config: ({})

    // --- Teinte d'équipe (override des zones team:true du skin.json) ---
    property color teamColor: "transparent"     // alpha 0 = pas d'équipe
    property var   teamZones: []                 // index de zones marquées team

    // --- Transform du modèle (depuis model_manifest.json) ---
    property vector3d modelScale:    Qt.vector3d(1, 1, 1)
    property vector3d modelEuler:    Qt.vector3d(0, 0, 0)
    property vector3d modelPosition: Qt.vector3d(0, 0, 0)

    // Debug shader (0 normal .. 5 slot match).
    property alias debugMode: mat.debugMode

    // Exposé pour brancher des effets externes éventuels.
    property alias material: mat

    onConfigChanged:    Qt.callLater(root.applyConfig)
    onTeamColorChanged: Qt.callLater(root.applyConfig)
    onTeamZonesChanged: Qt.callLater(root.applyConfig)
    onTextureLibChanged: Qt.callLater(root.applyConfig)

    // Résout l'URL de la texture choisie pour une zone. Si aucune texture
    // (ou introuvable), on renvoie la BASE COLOR : la couche texture devient
    // alors neutre (mix(base, base, opacity) == base), comme dans kura.
    function textureUrlFor(slot) {
        const slots = (root.config && root.config.slots) ? root.config.slots : []
        const s = slots[slot]
        if (s && s.texture) {
            const lib = root.textureLib || []
            for (let k = 0; k < lib.length; k++)
                if (lib[k].name === s.texture)
                    return root.skinUrl + "textures/" + lib[k].file
        }
        return root.baseColorUrl
    }

    // Distribue la config sur le matériau (imperatif, via accès par nom).
    function applyConfig() {
        const cfg = root.config || {}
        mat.baseTint         = cfg.baseTint         !== undefined ? cfg.baseTint         : "#ffffff"
        mat.baseTintMode     = cfg.baseTintMode     !== undefined ? cfg.baseTintMode     : 0
        mat.baseTintStrength = cfg.baseTintStrength !== undefined ? cfg.baseTintStrength : 0.0

        const slots = cfg.slots || []
        const hasTeam = root.teamColor.a > 0.0
        const teamSet = {}
        const tz = root.teamZones || []
        for (let t = 0; t < tz.length; t++) teamSet[tz[t]] = true

        for (let i = 0; i < root.maxSlots; i++) {
            const s = slots[i] || null
            mat["tint" + i]          = s ? (s.tint || "#ffffff") : "#ffffff"
            mat["tintMode" + i]      = s ? (s.tintMode || 0) : 0
            mat["tintStrength" + i]  = s ? (s.tintStrength || 0.0) : 0.0
            mat["slot" + i + "TexOpacity"] = s ? ((s.texOpacity !== undefined) ? s.texOpacity : 1.0) : 1.0
            mat["slot" + i + "TexTint"]    = s ? (s.texTint || "#ffffff") : "#ffffff"
            mat["texInvert" + i]     = s ? (s.texInvert ? 1 : 0) : 0

            // Override équipe : la couleur d'équipe écrase la teinte des zones team.
            if (hasTeam && teamSet[i]) {
                mat["tint" + i]         = root.teamColor
                mat["tintMode" + i]     = 0       // Aplat
                mat["tintStrength" + i] = 1.0
            }

            // Sources de texture (seules les maxTex premières ont un sampler).
            if (i < root.maxTex)
                mat["slot" + i + "PatternSource"] = root.textureUrlFor(i)
        }
    }

    KuraMaterial {
        id: mat
        baseColorSource: root.baseColorUrl
        colorIDSource:   root.colorMapUrl
    }

    RuntimeLoader {
        id: loader
        source: root.glbUrl
        scale: root.modelScale
        eulerRotation: root.modelEuler
        position: root.modelPosition

        // Réassigne le matériau custom à chaque Model de l'arbre chargé
        // (sinon les matières du glb l'emportent).
        function overrideMaterials(node) {
            let n = 0
            for (let i = 0; i < node.children.length; ++i) {
                const c = node.children[i]
                if (c.materials !== undefined) { c.materials = [mat]; n++ }
                n += overrideMaterials(c)
            }
            return n
        }
    }

    // Enum Status instable selon les versions Qt (6.11 ≠ Ready) → on poll.
    // Ne tourne que si un skin est actif (sinon on garde les matières du .glb).
    Timer {
        id: patchTimer
        interval: 100
        repeat: true
        running: root.skinActive
        property int attempts: 0
        onTriggered: {
            attempts++
            const n = loader.overrideMaterials(loader)
            if (n > 0) {
                root.applyConfig()
                stop()
            } else if (attempts >= 50) {
                console.warn("[KuraModel] aucun Model trouvé après 5s pour", root.glbUrl)
                stop()
            }
        }
    }

    // Re-patch si la source OU l'activation du skin change (nouveau modèle / skin assigné).
    function _restartPatch() {
        if (!root.skinActive) return
        patchTimer.attempts = 0
        patchTimer.restart()
    }
    onSkinActiveChanged: _restartPatch()
    Connections {
        target: loader
        function onSourceChanged() { root._restartPatch() }
    }
}
