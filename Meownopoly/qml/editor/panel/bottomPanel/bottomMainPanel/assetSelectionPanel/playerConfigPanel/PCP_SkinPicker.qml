import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AssetManager
import theme

/*
 * PCP_SkinPicker — choix du skin + de la variante (preset Color ID Map) du
 * modèle d'un PlayerProfile. Lit les skins/variantes installés dans
 * <AppData>/models/<modelName>/ et émet un colorVariant JSON
 * { "skin": "...", "variant": "..." } ("" si rien à choisir).
 *
 * Masqué pour les primitives (Cube/Sphere) ou si le modèle n'a pas de skin.
 * Cf. doc/architecture/COLOR_ID_MAP_INTEGRATION_PLAN.md (Phase C).
 */
ColumnLayout {
    id: root

    property string modelName: ""
    property string colorVariant: ""            // JSON courant (in)
    signal colorVariantPicked(string json)      // (out)

    spacing: Math.round(Screen.pixelDensity * 1)

    property var    _skins: []
    property var    _variants: []
    property string _skin: ""
    property string _variant: ""

    function _isPrimitive() { return root.modelName === "Cube" || root.modelName === "Sphere" }

    function refresh() {
        if (root.modelName.length === 0 || _isPrimitive()) {
            root._skins = []; root._variants = []; root._skin = ""; root._variant = ""
            return
        }
        root._skins = AssetManager.listModelSkins(root.modelName)
        let cv = {}
        if (root.colorVariant && root.colorVariant.length) {
            try { cv = JSON.parse(root.colorVariant) } catch (e) {}
        }
        let sk = cv.skin || (root._skins.length > 0 ? root._skins[0] : "")
        if (sk.length > 0 && root._skins.indexOf(sk) < 0 && root._skins.length > 0) sk = root._skins[0]
        root._skin = sk
        root._variants = sk.length > 0 ? AssetManager.listSkinVariants(root.modelName, sk) : []
        root._variant = cv.variant || ""
        _syncCombos()
    }

    function _syncCombos() {
        const si = skinCombo.find(root._skin)
        skinCombo.currentIndex = si >= 0 ? si : 0
        const vi = root._variant.length > 0 ? variantCombo.find(root._variant) : 0
        variantCombo.currentIndex = vi >= 0 ? vi : 0
    }

    function _emit() {
        const json = (root._skin.length > 0 || root._variant.length > 0)
                     ? JSON.stringify({ skin: root._skin, variant: root._variant }) : ""
        root.colorVariantPicked(json)
    }

    onModelNameChanged:    refresh()
    onColorVariantChanged: refresh()
    Component.onCompleted:  refresh()

    visible: !_isPrimitive() && root._skins.length > 0

    Label {
        text: "Skin"
        color: Theme.textSecondary
        font.pixelSize: Math.round(Screen.pixelDensity * 3)
        font.bold: true
    }
    PCP_StyledComboBox {
        id: skinCombo
        Layout.fillWidth: true
        model: root._skins
        onActivated: {
            root._skin = currentText
            root._variants = AssetManager.listSkinVariants(root.modelName, root._skin)
            root._variant = ""
            variantCombo.currentIndex = 0
            root._emit()
        }
    }

    Label {
        text: "Variante"
        visible: root._variants.length > 0
        color: Theme.textSecondary
        font.pixelSize: Math.round(Screen.pixelDensity * 3)
        font.bold: true
    }
    PCP_StyledComboBox {
        id: variantCombo
        visible: root._variants.length > 0
        Layout.fillWidth: true
        model: ["(défaut)"].concat(root._variants)
        onActivated: {
            root._variant = currentIndex <= 0 ? "" : currentText
            root._emit()
        }
    }
}
