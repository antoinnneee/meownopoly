import QtQuick
import QtQuick3D

// CustomMaterial — composition par zone du Color ID Map. (N=20, MAX_TEX=8)
// Porté de kura_qt_viewer (armorpaint). Matériau PARTAGÉ : un seul exemplaire
// dans l'app, appliqué aux Model via KuraModel.overrideMaterials.
// Cf. doc/architecture/COLOR_ID_MAP_INTEGRATION_PLAN.md
CustomMaterial {
    id: mat

    property url baseColorSource
    property url colorIDSource

    // Source de la texture choisie par zone (les MAX_TEX=8 premières seulement).
    property url slot0PatternSource
    property url slot1PatternSource
    property url slot2PatternSource
    property url slot3PatternSource
    property url slot4PatternSource
    property url slot5PatternSource
    property url slot6PatternSource
    property url slot7PatternSource

    // === Teinte globale du "skin de base" ===
    property color baseTint: "white"
    property int   baseTintMode: 0
    property real  baseTintStrength: 0.0

    // === Couche teinte couleur, par zone ===
    property color tint0: "white"
    property color tint1: "white"
    property color tint2: "white"
    property color tint3: "white"
    property color tint4: "white"
    property color tint5: "white"
    property color tint6: "white"
    property color tint7: "white"
    property color tint8: "white"
    property color tint9: "white"
    property color tint10: "white"
    property color tint11: "white"
    property color tint12: "white"
    property color tint13: "white"
    property color tint14: "white"
    property color tint15: "white"
    property color tint16: "white"
    property color tint17: "white"
    property color tint18: "white"
    property color tint19: "white"

    property int tintMode0: 0
    property int tintMode1: 0
    property int tintMode2: 0
    property int tintMode3: 0
    property int tintMode4: 0
    property int tintMode5: 0
    property int tintMode6: 0
    property int tintMode7: 0
    property int tintMode8: 0
    property int tintMode9: 0
    property int tintMode10: 0
    property int tintMode11: 0
    property int tintMode12: 0
    property int tintMode13: 0
    property int tintMode14: 0
    property int tintMode15: 0
    property int tintMode16: 0
    property int tintMode17: 0
    property int tintMode18: 0
    property int tintMode19: 0

    property real tintStrength0: 0.0
    property real tintStrength1: 0.0
    property real tintStrength2: 0.0
    property real tintStrength3: 0.0
    property real tintStrength4: 0.0
    property real tintStrength5: 0.0
    property real tintStrength6: 0.0
    property real tintStrength7: 0.0
    property real tintStrength8: 0.0
    property real tintStrength9: 0.0
    property real tintStrength10: 0.0
    property real tintStrength11: 0.0
    property real tintStrength12: 0.0
    property real tintStrength13: 0.0
    property real tintStrength14: 0.0
    property real tintStrength15: 0.0
    property real tintStrength16: 0.0
    property real tintStrength17: 0.0
    property real tintStrength18: 0.0
    property real tintStrength19: 0.0

    // === Couche texture, par zone ===
    property real slot0TexOpacity: 1.0
    property real slot1TexOpacity: 1.0
    property real slot2TexOpacity: 1.0
    property real slot3TexOpacity: 1.0
    property real slot4TexOpacity: 1.0
    property real slot5TexOpacity: 1.0
    property real slot6TexOpacity: 1.0
    property real slot7TexOpacity: 1.0
    property real slot8TexOpacity: 1.0
    property real slot9TexOpacity: 1.0
    property real slot10TexOpacity: 1.0
    property real slot11TexOpacity: 1.0
    property real slot12TexOpacity: 1.0
    property real slot13TexOpacity: 1.0
    property real slot14TexOpacity: 1.0
    property real slot15TexOpacity: 1.0
    property real slot16TexOpacity: 1.0
    property real slot17TexOpacity: 1.0
    property real slot18TexOpacity: 1.0
    property real slot19TexOpacity: 1.0

    property color slot0TexTint: "white"
    property color slot1TexTint: "white"
    property color slot2TexTint: "white"
    property color slot3TexTint: "white"
    property color slot4TexTint: "white"
    property color slot5TexTint: "white"
    property color slot6TexTint: "white"
    property color slot7TexTint: "white"
    property color slot8TexTint: "white"
    property color slot9TexTint: "white"
    property color slot10TexTint: "white"
    property color slot11TexTint: "white"
    property color slot12TexTint: "white"
    property color slot13TexTint: "white"
    property color slot14TexTint: "white"
    property color slot15TexTint: "white"
    property color slot16TexTint: "white"
    property color slot17TexTint: "white"
    property color slot18TexTint: "white"
    property color slot19TexTint: "white"

    // Inversion de la texture : 0 = pattern, 1 = (1 - pattern).
    property int texInvert0: 0
    property int texInvert1: 0
    property int texInvert2: 0
    property int texInvert3: 0
    property int texInvert4: 0
    property int texInvert5: 0
    property int texInvert6: 0
    property int texInvert7: 0
    property int texInvert8: 0
    property int texInvert9: 0
    property int texInvert10: 0
    property int texInvert11: 0
    property int texInvert12: 0
    property int texInvert13: 0
    property int texInvert14: 0
    property int texInvert15: 0
    property int texInvert16: 0
    property int texInvert17: 0
    property int texInvert18: 0
    property int texInvert19: 0

    // Debug switch : 0 normal / 1 rouge / 2 UV / 3 base / 4 colormap / 5 match.
    property int debugMode: 0

    property TextureInput baseColorTex: TextureInput {
        enabled: true
        texture: Texture {
            source: mat.baseColorSource
            generateMipmaps: true
            minFilter: Texture.Linear
            magFilter: Texture.Linear
            mipFilter: Texture.Linear
        }
    }

    // Color ID map : linéaire + Nearest + pas de mipmaps + ClampToEdge (COLOR_ID_MAP.md §4).
    property TextureInput colorIDTex: TextureInput {
        enabled: true
        texture: Texture {
            source: mat.colorIDSource
            generateMipmaps: false
            minFilter: Texture.Nearest
            magFilter: Texture.Nearest
            mipFilter: Texture.None
            tilingModeHorizontal: Texture.ClampToEdge
            tilingModeVertical: Texture.ClampToEdge
        }
    }

    property TextureInput slot0Pattern: TextureInput {
        enabled: true
        texture: Texture { source: mat.slot0PatternSource; generateMipmaps: true; mipFilter: Texture.Linear }
    }
    property TextureInput slot1Pattern: TextureInput {
        enabled: true
        texture: Texture { source: mat.slot1PatternSource; generateMipmaps: true; mipFilter: Texture.Linear }
    }
    property TextureInput slot2Pattern: TextureInput {
        enabled: true
        texture: Texture { source: mat.slot2PatternSource; generateMipmaps: true; mipFilter: Texture.Linear }
    }
    property TextureInput slot3Pattern: TextureInput {
        enabled: true
        texture: Texture { source: mat.slot3PatternSource; generateMipmaps: true; mipFilter: Texture.Linear }
    }
    property TextureInput slot4Pattern: TextureInput {
        enabled: true
        texture: Texture { source: mat.slot4PatternSource; generateMipmaps: true; mipFilter: Texture.Linear }
    }
    property TextureInput slot5Pattern: TextureInput {
        enabled: true
        texture: Texture { source: mat.slot5PatternSource; generateMipmaps: true; mipFilter: Texture.Linear }
    }
    property TextureInput slot6Pattern: TextureInput {
        enabled: true
        texture: Texture { source: mat.slot6PatternSource; generateMipmaps: true; mipFilter: Texture.Linear }
    }
    property TextureInput slot7Pattern: TextureInput {
        enabled: true
        texture: Texture { source: mat.slot7PatternSource; generateMipmaps: true; mipFilter: Texture.Linear }
    }

    shadingMode: CustomMaterial.Shaded
    cullMode: Material.BackFaceCulling
    fragmentShader: Qt.resolvedUrl("shaders/tint.frag")
}
