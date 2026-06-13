/*
 * SkinnedModel — présentateur runtime d'un modèle joueur re-skinné.
 *
 * Résout `modelName` + `colorVariant` (JSON du PlayerProfile) en :
 *   - le .glb + la base color (depuis model_manifest.json),
 *   - le skin choisi (colorVariant.skin || manifest.colorId.defaultSkin || 1er),
 *   - la variante choisie (colorVariant.variant || defaultVariant),
 *   - les zones d'équipe (skin.json zones team:true),
 * puis alimente un KuraModel. Gère aussi les primitives Cube/Sphere.
 *
 * Les modèles vivent dans <AppData>/models/<modelName>/ (format kura).
 * Lecture des fichiers via LauncherManager (helpers déjà présents) — à
 * terme à déplacer dans AssetManager (Phase E). teamColorOverride permet à
 * la partie d'imposer une couleur d'équipe par-dessus la variante.
 * Cf. doc/architecture/COLOR_ID_MAP_INTEGRATION_PLAN.md
 */
import QtQuick
import QtQuick3D
import AssetManager

Node {
    id: root

    property string modelName: ""
    property string colorVariant: ""             // JSON sérialisé du PlayerProfile
    property color  teamColorOverride: "transparent"  // imposé par la partie (équipes)

    readonly property bool isPrimitive: modelName === "Cube" || modelName === "Sphere"

    // --- Résolu ---
    property url   _glbUrl: ""
    property url   _baseColorUrl: ""
    property url   _skinUrl: ""
    property var   _textureLib: []
    property var   _config: ({})
    property var   _teamZones: []
    property int   _slotCount: 1
    property color _teamColor: "transparent"
    property vector3d _modelScale: Qt.vector3d(1, 1, 1)
    property vector3d _modelEuler: Qt.vector3d(0, 0, 0)
    property vector3d _modelPosition: Qt.vector3d(0, 0, 0)

    function _buildTextureLib(scanned, jsonTex) {
        let lib = [], used = {}
        if (Array.isArray(jsonTex)) {
            for (let k = 0; k < jsonTex.length; k++) {
                const t = jsonTex[k]
                if (t && t.file && scanned.indexOf(t.file) >= 0) {
                    lib.push({ name: t.name || t.file, file: t.file }); used[t.file] = true
                }
            }
        }
        for (let j = 0; j < scanned.length; j++) {
            const f = scanned[j]
            if (!used[f]) lib.push({ name: f.replace(/\.[^.]+$/, ''), file: f })
        }
        return lib
    }

    // Préfixe d'URL : QRC (:/…) → qrc:/… ; sinon chemin disque → file:///…
    function _urlBase(dir) { return dir.charAt(0) === ":" ? ("qrc" + dir) : ("file:///" + dir) }

    function resolve() {
        if (modelName.length === 0 || isPrimitive) return

        const dir = AssetManager.modelDir(modelName)
        const ub = _urlBase(dir)
        const manifest = AssetManager.readModelManifest(modelName) || {}

        const glbRel      = manifest.glb      ? manifest.glb      : ("base/" + modelName + ".glb")
        const skinBaseRel = manifest.skinBase ? manifest.skinBase : "base/skin_base.png"
        root._glbUrl       = ub + "/" + glbRel
        root._baseColorUrl = ub + "/" + skinBaseRel

        const t = manifest.transform
        root._modelScale    = (t && t.scale)         ? Qt.vector3d(t.scale[0], t.scale[1], t.scale[2]) : Qt.vector3d(1, 1, 1)
        root._modelEuler    = (t && t.eulerRotation) ? Qt.vector3d(t.eulerRotation[0], t.eulerRotation[1], t.eulerRotation[2]) : Qt.vector3d(0, 0, 0)
        root._modelPosition = (t && t.position)      ? Qt.vector3d(t.position[0], t.position[1], t.position[2]) : Qt.vector3d(0, 0, 0)

        let cv = {}
        if (colorVariant && colorVariant.length) { try { cv = JSON.parse(colorVariant) } catch (e) {} }
        const colorId = manifest.colorId || {}

        const skins = AssetManager.listModelSkins(modelName)
        let skin = cv.skin || colorId.defaultSkin || (skins.length > 0 ? skins[0] : "")
        if (skin.length > 0 && skins.indexOf(skin) < 0 && skins.length > 0) skin = skins[0]
        root._skinUrl = skin.length > 0 ? (ub + "/skins/" + skin + "/") : ""

        let zones = {}, jsonTex = null
        if (skin.length > 0) {
            const txt = AssetManager.readSkinJson(modelName, skin)
            if (txt && txt.length) {
                try { const d = JSON.parse(txt); zones = d.zones || {}; jsonTex = d.textures || null } catch (e) {}
            }
        }
        const scanned = skin.length > 0 ? AssetManager.listSkinTextures(modelName, skin) : []
        root._textureLib = _buildTextureLib(scanned, jsonTex)

        let count = 0
        while (count < 20 && zones[String(count)] !== undefined) count++
        root._slotCount = Math.max(1, count)
        let tz = []
        for (let i = 0; i < root._slotCount; i++) { const z = zones[String(i)]; if (z && z.team) tz.push(i) }
        root._teamZones = tz

        let cfg = {}
        const variantName = cv.variant || colorId.defaultVariant || ""
        if (variantName.length > 0 && skin.length > 0) {
            const vt = AssetManager.loadSkinVariant(modelName, skin, variantName)
            if (vt && vt.length) { try { cfg = JSON.parse(vt) } catch (e) {} }
        }
        root._config = cfg

        if (root.teamColorOverride.a > 0.0) root._teamColor = root.teamColorOverride
        else if (cv.teamColor)              root._teamColor = cv.teamColor
        else                                root._teamColor = "transparent"
    }

    onModelNameChanged:         Qt.callLater(root.resolve)
    onColorVariantChanged:      Qt.callLater(root.resolve)
    onTeamColorOverrideChanged: Qt.callLater(root.resolve)
    Component.onCompleted:      root.resolve()

    // Primitives Cube/Sphere (pas de re-skin).
    Model {
        visible: root.isPrimitive
        source: root.modelName === "Cube" ? "#Cube" : "#Sphere"
        materials: PrincipledMaterial { baseColor: "white" }
    }

    // Modèle skinné (.glb + Color ID Map).
    KuraModel {
        visible: !root.isPrimitive
        glbUrl:       root._glbUrl
        baseColorUrl: root._baseColorUrl
        colorMapUrl:  root._skinUrl.toString().length > 0 ? (root._skinUrl + "colorMap.png") : ""
        skinUrl:      root._skinUrl
        textureLib:   root._textureLib
        config:       root._config
        teamColor:    root._teamColor
        teamZones:    root._teamZones
        slotCount:    root._slotCount
        modelScale:    root._modelScale
        modelEuler:    root._modelEuler
        modelPosition: root._modelPosition
    }
}
