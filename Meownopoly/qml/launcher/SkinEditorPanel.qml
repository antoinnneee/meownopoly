/*
 * SkinEditorPanel.qml — Créateur de skin "Color ID Map" (intégré au configurateur).
 *
 * Porté de kura_qt_viewer/Main.qml (panneau de droite), adapté au format
 * Meownopoly (helpers C++ LauncherManager au lieu du pont Catalog + XHR).
 *
 * Édite, pour un modèle (dossier `folderPath`) :
 *  - le skin courant (sous-dossier de skins/),
 *  - par zone : teinte (couleur + mode A/×/O + intensité), texture (biblio +
 *    opacité + teinte propre + invert), et le flag "équipe" (zone teintée par
 *    la couleur d'équipe au runtime),
 *  - les variantes (presets) du skin.
 *
 * Expose en lecture la config courante pour que le viewport (KuraModel) la
 * rende en live. Cf. doc/architecture/COLOR_ID_MAP_INTEGRATION_PLAN.md
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import LauncherManager 1.0
import theme
import ui_item

ColumnLayout {
    id: root
    spacing: Theme.spacingXL

    // --- Entrée ---
    property string folderPath: ""          // chemin clean du dossier modèle
    property url    baseColorUrl: ""         // base color (peau) — depuis le manifest

    // --- Sortie (lue par le viewport) ---
    readonly property string currentSkin: _currentSkin
    readonly property url skinUrl: (folderPath.length > 0 && _currentSkin.length > 0)
        ? ("file:///" + folderPath + "/skins/" + _currentSkin + "/") : ""
    readonly property url colorMapUrl: skinUrl.toString().length > 0
        ? (skinUrl + "colorMap.png") : ""
    property var  textureLib: []             // [{ name, file }]
    property int  slotCount: 1
    property var  config: ({})               // { baseTint, baseTintMode, baseTintStrength, slots:[…] }
    property var  teamZones: []              // indices des zones team:true
    property int  debugMode: 0

    readonly property int maxSlots: 20
    readonly property int maxTex: 8

    signal statusMessage(string msg)

    readonly property var tintModeSymbols: ["A", "×", "O"]
    readonly property var tintModeNames:   ["Aplat", "Multiply", "Overlay"]
    readonly property var slotPaletteHex: [
        "#F21818", "#18F2F2", "#85F218", "#8518F2", "#F2BC18", "#184FF2", "#18F24F", "#F218BC",
        "#F26A18", "#18A1F2", "#34F218", "#D718F2", "#D7F218", "#3418F2", "#18F2A1", "#F2186A",
        "#F24118", "#18C9F2", "#5CF218", "#AE18F2"
    ]

    // --- État interne ---
    property string _currentSkin: ""
    property var skins: []
    property var slotData: [ { name: "zone 0", team: false } ]
    property var _jsonTextures: null         // textures[] du skin.json (préservé à l'écriture)

    property color baseTint: "#ffffff"
    property int   baseTintMode: 0
    property real  baseTintStrength: 0.0

    property var tints:          Array(20).fill("#ffffff")
    property var tintModes:      Array(20).fill(0)
    property var tintStrengths:  Array(20).fill(0.0)
    property var texOpacities:   Array(20).fill(1.0)
    property var texTints:       Array(20).fill("#ffffff")
    property var textureInverts: Array(20).fill(false)
    property var texSelections:  Array(20).fill(0)   // index dans ["Aucune", ...lib]
    property var zoneTeam:       Array(20).fill(false)
    property var zoneNames:      Array(20).fill("")

    property var variantNames: []
    property var generalTextures: []         // bibliothèque partagée <AppData>/model_textures

    Component.onCompleted: refreshGeneralTextures()

    function _set(arrName, i, v) {
        const n = root[arrName].slice(); n[i] = v; root[arrName] = n; rebuildConfig()
    }
    function setTint(s, c)          { _set("tints", s, c.toString()) }
    function setTintMode(s, m)      { _set("tintModes", s, m) }
    function setTintStrength(s, v)  { _set("tintStrengths", s, v) }
    function setTexOpacity(s, v)    { _set("texOpacities", s, v) }
    function setTexTint(s, c)       { _set("texTints", s, c.toString()) }
    function setTextureInvert(s, on){ _set("textureInverts", s, on) }
    function setTexSelection(s, idx){ _set("texSelections", s, idx) }
    function setZoneTeam(s, on)     { _set("zoneTeam", s, on); _recomputeTeamZones() }
    function setZoneName(s, nm)     { _set("zoneNames", s, nm) }

    function _recomputeTeamZones() {
        let tz = []
        for (let i = 0; i < root.slotCount; i++) if (root.zoneTeam[i]) tz.push(i)
        root.teamZones = tz
    }

    // Reconstruit l'objet config (lu par le viewport).
    function rebuildConfig() {
        let slots = []
        for (let i = 0; i < root.maxSlots; i++) {
            const sel = root.texSelections[i] || 0
            const texName = (sel > 0 && root.textureLib[sel - 1]) ? root.textureLib[sel - 1].name : ""
            slots.push({
                tint: root.tints[i], tintMode: root.tintModes[i], tintStrength: root.tintStrengths[i],
                texture: texName, texOpacity: root.texOpacities[i], texTint: root.texTints[i],
                texInvert: root.textureInverts[i]
            })
        }
        root.config = {
            version: 2, skin: root._currentSkin,
            baseTint: root.baseTint.toString(), baseTintMode: root.baseTintMode,
            baseTintStrength: root.baseTintStrength, slots: slots
        }
    }

    function resetConfig() {
        root.baseTint = "#ffffff"; root.baseTintStrength = 0.0; root.baseTintMode = 0
        root.tints = Array(20).fill("#ffffff")
        root.tintModes = Array(20).fill(0)
        root.tintStrengths = Array(20).fill(0.0)
        root.texOpacities = Array(20).fill(1.0)
        root.texTints = Array(20).fill("#ffffff")
        root.textureInverts = Array(20).fill(false)
        root.texSelections = Array(20).fill(0)
        rebuildConfig()
    }

    // --- Skins ---
    function refreshSkins() {
        root.skins = (root.folderPath.length > 0) ? LauncherManager.listModelSkins(root.folderPath) : []
        if (root.skins.length > 0) loadSkin(root.skins[0])
        else { root._currentSkin = ""; root.slotCount = 1 }
    }

    function buildTextureLib(scanned, jsonTex) {
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

    // Re-scanne la bibliothèque de textures SANS wiper la config (contrairement à
    // loadSkin → resetConfig). Préserve les sélections de zones par nom car
    // l'ajout d'un fichier peut décaler les index (listSkinTextures trie par nom).
    function rescanTextureLib() {
        if (root._currentSkin.length === 0) return
        let selectedNames = []
        for (let i = 0; i < root.maxSlots; i++) {
            const sel = root.texSelections[i] || 0
            selectedNames.push((sel > 0 && root.textureLib[sel - 1]) ? root.textureLib[sel - 1].name : "")
        }
        const scanned = LauncherManager.listSkinTextures(root.folderPath, root._currentSkin)
        root.textureLib = buildTextureLib(scanned, root._jsonTextures)
        let sel = []
        for (let i = 0; i < root.maxSlots; i++) sel.push(texIndexByName(selectedNames[i]))
        root.texSelections = sel
        rebuildConfig()
    }

    // Importe une image (URL fichier) dans la bibliothèque du skin et l'assigne à
    // la zone donnée. Utilisé par le drag & drop sur une zone et par le bouton.
    function importTextureToZone(zoneIndex, fileUrl) {
        if (root._currentSkin.length === 0) { root.statusMessage("Aucun skin actif — crée-en un d'abord."); return }
        const before = LauncherManager.listSkinTextures(root.folderPath, root._currentSkin)
        if (!LauncherManager.importSkinTexture(root.folderPath, root._currentSkin, fileUrl.toString())) {
            root.statusMessage("Échec de l'import de la texture."); return
        }
        rescanTextureLib()
        // Repère le fichier nouvellement ajouté (diff avant/après), robuste à
        // l'encodage de l'URL et au tri ; fallback sur le basename si ré-import.
        const after = LauncherManager.listSkinTextures(root.folderPath, root._currentSkin)
        let newFile = ""
        for (let i = 0; i < after.length; i++) if (before.indexOf(after[i]) < 0) { newFile = after[i]; break }
        if (newFile.length === 0) newFile = decodeURIComponent(fileUrl.toString().split("/").pop())
        let idx = 0
        for (let k = 0; k < root.textureLib.length; k++)
            if (root.textureLib[k].file === newFile) { idx = k + 1; break }
        if (idx > 0) {
            root.setTexSelection(zoneIndex, idx)
            root.statusMessage("Texture « " + root.textureLib[idx - 1].name + " » assignée à la zone " + zoneIndex)
        } else {
            root.statusMessage("Texture importée (zone " + zoneIndex + ").")
        }
    }

    // --- Bibliothèque de textures générales (partagée entre modèles) ---
    function refreshGeneralTextures() {
        root.generalTextures = LauncherManager.listGeneralTextures()
    }
    function importIntoGeneral(fileUrl) {
        if (LauncherManager.importGeneralTexture(fileUrl.toString())) {
            refreshGeneralTextures()
            root.statusMessage("Texture ajoutée à la bibliothèque générale.")
        } else root.statusMessage("Échec de l'import dans la bibliothèque générale.")
    }
    function removeGeneralTexture(file) {
        if (LauncherManager.deleteGeneralTexture(file)) {
            refreshGeneralTextures()
            root.statusMessage("Texture retirée de la bibliothèque générale.")
        }
    }
    function copyGeneralToSkin(file) {
        if (root._currentSkin.length === 0) { root.statusMessage("Aucun skin actif — crée-en un d'abord."); return }
        if (LauncherManager.copyGeneralTextureToSkin(root.folderPath, root._currentSkin, file)) {
            rescanTextureLib()
            root.statusMessage("« " + file + " » copiée vers le modèle.")
        } else root.statusMessage("Échec de la copie vers le modèle.")
    }

    // --- Textures du modèle : suppression + nettoyage des non utilisées ---
    // Ensemble {file: true} des textures référencées : par la config courante ET
    // par TOUTES les variantes (sinon le nettoyage casserait une variante qui
    // référence une texture non assignée dans la config courante).
    function usedTextureFiles() {
        let used = {}
        // Index nom → fichier de la lib courante (les variantes stockent le nom).
        const libByName = {}
        for (let k = 0; k < root.textureLib.length; k++)
            libByName[root.textureLib[k].name] = root.textureLib[k].file
        // 1) config courante : sélections de zones.
        for (let i = 0; i < root.slotCount; i++) {
            const sel = root.texSelections[i] || 0
            if (sel > 0 && root.textureLib[sel - 1]) used[root.textureLib[sel - 1].file] = true
        }
        // 2) toutes les variantes (presets) sur disque. On itère root.variantNames
        //    (propriété trackée) pour que les bindings se rafraîchissent à l'ajout/
        //    suppression de variante.
        const variants = root.variantNames || []
        for (let v = 0; v < variants.length; v++) {
            const txt = LauncherManager.loadSkinVariant(root.folderPath, root._currentSkin, variants[v])
            if (!txt || !txt.length) continue
            let cfg
            try { cfg = JSON.parse(txt) } catch (e) { continue }
            const slots = (cfg && cfg.slots) ? cfg.slots : []
            for (let j = 0; j < slots.length; j++) {
                const nm = slots[j] ? slots[j].texture : ""
                if (nm && libByName[nm]) used[libByName[nm]] = true
            }
        }
        return used
    }
    function isTextureUsed(file) { return usedTextureFiles()[file] === true }
    function deleteModelTexture(file) {
        if (root._currentSkin.length === 0) return
        if (LauncherManager.deleteSkinTexture(root.folderPath, root._currentSkin, file)) {
            rescanTextureLib()   // les zones qui l'utilisaient repassent à "Aucune"
            root.statusMessage("Texture « " + file + " » supprimée du modèle.")
        }
    }
    function removeUnusedModelTextures() {
        if (root._currentSkin.length === 0) return
        const used = usedTextureFiles()
        const lib = root.textureLib.slice()
        let removed = 0
        for (let k = 0; k < lib.length; k++)
            if (!used[lib[k].file]
                && LauncherManager.deleteSkinTexture(root.folderPath, root._currentSkin, lib[k].file))
                removed++
        rescanTextureLib()
        root.statusMessage(removed + " texture(s) non utilisée(s) supprimée(s).")
    }

    function loadSkin(name) {
        if (!name || root.folderPath.length === 0) return
        root._currentSkin = name
        const scanned = LauncherManager.listSkinTextures(root.folderPath, name)
        let zones = {}, jsonTex = null
        const txt = LauncherManager.readSkinJson(root.folderPath, name)
        if (txt && txt.length) {
            try {
                const d = JSON.parse(txt)
                zones = d.zones || {}
                jsonTex = d.textures || null
            } catch (e) { root.statusMessage("skin.json illisible : " + e) }
        }
        root._jsonTextures = jsonTex
        root.textureLib = buildTextureLib(scanned, jsonTex)
        let count = 0
        while (count < root.maxSlots && zones[String(count)] !== undefined) count++
        count = Math.max(1, count)
        let sd = [], names = Array(20).fill(""), team = Array(20).fill(false)
        for (let i = 0; i < count; i++) {
            const z = zones[String(i)]
            const nm = (z && z.name) ? z.name : ("zone " + i)
            sd.push({ name: nm, team: !!(z && z.team) })
            names[i] = nm; team[i] = !!(z && z.team)
        }
        root.slotData = sd
        root.zoneNames = names
        root.zoneTeam = team
        root.slotCount = count
        resetConfig()
        _recomputeTeamZones()
        refreshVariants()
        root.statusMessage("Skin chargé : " + name + " — " + count + " zones, "
                           + root.textureLib.length + " textures")
    }

    // Re-détecte le nombre de zones depuis la colorMap du skin et l'applique
    // (utile si la colorMap a été (re)générée après création du skin).
    function redetectZones() {
        if (root._currentSkin.length === 0) return
        const cm = root.folderPath + "/skins/" + root._currentSkin + "/colorMap.png"
        const n = LauncherManager.detectColorMapZones(cm)
        if (n < 1) return
        let names = root.zoneNames.slice()
        for (let i = 0; i < n; i++) if (!names[i] || names[i].length === 0) names[i] = "zone " + i
        root.zoneNames = names
        root.slotCount = n
        rebuildConfig()
        _recomputeTeamZones()
        saveSkinJson()
        root.statusMessage(n + " zone(s) détectée(s) depuis la colorMap")
    }

    // Écrit skin.json (noms de zones + flags team + textures[] préservés).
    function saveSkinJson() {
        if (root._currentSkin.length === 0) return
        let zones = {}
        for (let i = 0; i < root.slotCount; i++) {
            let z = { name: root.zoneNames[i] || ("zone " + i) }
            if (root.zoneTeam[i]) z.team = true
            zones[String(i)] = z
        }
        let obj = { name: root._currentSkin, zones: zones }
        if (Array.isArray(root._jsonTextures)) obj.textures = root._jsonTextures
        LauncherManager.writeSkinJson(root.folderPath, root._currentSkin,
                                      JSON.stringify(obj, null, 2))
        root.statusMessage("skin.json enregistré pour " + root._currentSkin)
    }

    // --- Variantes ---
    function refreshVariants() {
        root.variantNames = (root._currentSkin.length > 0)
            ? LauncherManager.listSkinVariants(root.folderPath, root._currentSkin) : []
    }
    function texIndexByName(nm) {
        for (let k = 0; k < root.textureLib.length; k++)
            if (root.textureLib[k].name === nm) return k + 1
        return 0
    }
    function saveVariant(name) {
        if (!name || name.length === 0 || root._currentSkin.length === 0) return
        rebuildConfig()
        if (LauncherManager.saveSkinVariant(root.folderPath, root._currentSkin, name,
                                            JSON.stringify(root.config, null, 2))) {
            refreshVariants()
            root.statusMessage("Variante sauvée : " + name)
        }
    }
    function applyVariantConfig(cfg) {
        if (!cfg) return
        root.baseTint = cfg.baseTint || "#ffffff"
        root.baseTintMode = cfg.baseTintMode || 0
        root.baseTintStrength = (cfg.baseTintStrength !== undefined) ? cfg.baseTintStrength : 0.0
        let tints=[], modes=[], strs=[], opac=[], ttint=[], inv=[], sel=[]
        for (let i = 0; i < root.maxSlots; i++) {
            const s = (cfg.slots && cfg.slots[i]) ? cfg.slots[i] : null
            tints.push(s ? s.tint : "#ffffff")
            modes.push(s ? (s.tintMode || 0) : 0)
            strs.push(s ? (s.tintStrength || 0.0) : 0.0)
            opac.push(s ? ((s.texOpacity !== undefined) ? s.texOpacity : 1.0) : 1.0)
            ttint.push(s ? (s.texTint || "#ffffff") : "#ffffff")
            inv.push(s ? !!s.texInvert : false)
            sel.push(s ? texIndexByName(s.texture || "") : 0)
        }
        root.tints=tints; root.tintModes=modes; root.tintStrengths=strs
        root.texOpacities=opac; root.texTints=ttint; root.textureInverts=inv
        root.texSelections=sel
        rebuildConfig()
    }
    function loadVariant(name) {
        if (!name || root._currentSkin.length === 0) return
        const txt = LauncherManager.loadSkinVariant(root.folderPath, root._currentSkin, name)
        if (txt && txt.length) {
            try { applyVariantConfig(JSON.parse(txt)); root.statusMessage("Variante chargée : " + name) }
            catch (e) { root.statusMessage("Variante illisible : " + e) }
        }
    }
    function deleteVariant(name) {
        if (!name || root._currentSkin.length === 0) return
        LauncherManager.deleteSkinVariant(root.folderPath, root._currentSkin, name)
        refreshVariants()
    }

    onFolderPathChanged: refreshSkins()

    // ====================== UI ======================

    // --- Skin courant + création ---
    Label { text: "Skin"; color: Theme.textSoft; font.bold: true; font.pixelSize: Theme.fontSizeMedium }
    RowLayout {
        Layout.fillWidth: true; spacing: Theme.spacingS
        StyledComboBox {
            id: skinCombo
            Layout.fillWidth: true
            model: root.skins
            currentIndex: root.skins.indexOf(root._currentSkin)
            onActivated: root.loadSkin(currentText)
        }
        StyledButton {
            primary: true
            text: "＋ Skin"
            onClicked: newSkinDialog.open()
            ToolTip.text: "Créer un skin en important une color map"; ToolTip.visible: hovered; ToolTip.delay: 400
        }
    }
    Text {
        visible: root.skins.length === 0
        text: root.folderPath.length === 0 ? "Charge d'abord un modèle." : "Aucun skin — crée-en un (＋ Skin)."
        color: Theme.textHint; font.pixelSize: Theme.fontSizeSmall; Layout.fillWidth: true; wrapMode: Text.WordWrap
    }

    // --- Variantes ---
    Label { text: "Variantes"; color: Theme.textSoft; font.bold: true; font.pixelSize: Theme.fontSizeBody; visible: root._currentSkin.length > 0 }
    RowLayout {
        Layout.fillWidth: true; spacing: Theme.spacingS; visible: root._currentSkin.length > 0
        TextField {
            id: variantNameField
            Layout.fillWidth: true
            placeholderText: "nom de la variante…"
            color: Theme.textPrimary
            placeholderTextColor: Theme.textHint
            background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusXS }
            onAccepted: { root.saveVariant(text); text = "" }
        }
        StyledButton { primary: true; text: "Sauver"; onClicked: { root.saveVariant(variantNameField.text); variantNameField.text = "" } }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: Theme.spacingS; visible: root._currentSkin.length > 0
        StyledComboBox { id: variantCombo; Layout.fillWidth: true; model: root.variantNames }
        StyledButton { text: "Charger"; enabled: variantCombo.currentText.length > 0; onClicked: root.loadVariant(variantCombo.currentText) }
        StyledButton { danger: true; text: "Suppr"; enabled: variantCombo.currentText.length > 0; onClicked: root.deleteVariant(variantCombo.currentText) }
    }

    // --- Debug shader ---
    RowLayout {
        Layout.fillWidth: true; spacing: Theme.spacingS; visible: root._currentSkin.length > 0
        Label { text: "Debug"; color: Theme.textHint; font.pixelSize: Theme.fontSizeBody }
        Repeater {
            model: [ {l:"0",v:0}, {l:"base",v:3}, {l:"ID",v:4}, {l:"match",v:5} ]
            delegate: Button {
                id: dbgBtn
                required property var modelData
                text: modelData.l
                checkable: true; autoExclusive: true
                checked: root.debugMode === modelData.v
                onClicked: root.debugMode = modelData.v
                Layout.fillWidth: true
                implicitHeight: 28
                leftPadding: Theme.spacingL; rightPadding: Theme.spacingL
                background: Rectangle {
                    radius: Theme.radiusS
                    color: dbgBtn.checked ? Theme.accentAlt : (dbgBtn.hovered ? Theme.surfaceHover : Theme.surface)
                    border.color: dbgBtn.checked ? Theme.hover(Theme.accentAlt) : Theme.border
                    border.width: 1
                }
                contentItem: Text {
                    text: dbgBtn.text
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeBody
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; visible: root._currentSkin.length > 0 }

    // --- Couleur de peau (teinte globale) ---
    Label { text: "Couleur de peau"; color: Theme.textSoft; font.bold: true; font.pixelSize: Theme.fontSizeMedium; visible: root._currentSkin.length > 0 }
    RowLayout {
        Layout.fillWidth: true; spacing: Theme.spacingS; visible: root._currentSkin.length > 0
        Rectangle {
            width: 44; height: 24; radius: Theme.radiusXS; color: root.baseTint
            border.color: root.colorTarget === "base" ? Theme.accentAlt : Theme.borderLight
            border.width: root.colorTarget === "base" ? 2 : 1
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root._toggleColor("base") }
        }
        TintModeSelector {
            mode: root.baseTintMode
            onPicked: (m) => { root.baseTintMode = m; root.rebuildConfig() }
        }
        MeowSlider {
            Layout.fillWidth: true; from: 0.0; to: 1.0; value: root.baseTintStrength
            showValue: false
            onMoved: (v) => { root.baseTintStrength = v; root.rebuildConfig() }
        }
        Label { text: Number(root.baseTintStrength).toFixed(2); color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption; Layout.preferredWidth: 28 }
    }
    // Picker HSL inline de la couleur de peau (déplié au clic sur la pastille).
    Loader {
        Layout.fillWidth: true; Layout.leftMargin: Theme.spacingM
        active: root.colorTarget === "base"; visible: active
        sourceComponent: Component {
            InlineColorPicker {
                color: root.baseTint
                onColorPicked: (c) => { root.baseTint = c.toString(); root.rebuildConfig() }
            }
        }
    }

    // --- Zones ---
    RowLayout {
        Layout.fillWidth: true; visible: root._currentSkin.length > 0
        Label { text: "Zones — " + root.slotCount + "/" + root.maxSlots; color: Theme.textSoft; font.bold: true; font.pixelSize: Theme.fontSizeMedium; Layout.fillWidth: true }
        StyledButton { text: "Détecter zones"; font.pixelSize: Theme.fontSizeCaption; onClicked: root.redetectZones()
            ToolTip.text: "Re-détecter le nombre de zones depuis la colorMap"; ToolTip.visible: hovered; ToolTip.delay: 400 }
        StyledButton { text: "Enregistrer JSON"; font.pixelSize: Theme.fontSizeCaption; onClicked: root.saveSkinJson()
            ToolTip.text: "Enregistre noms de zones + flags équipe"; ToolTip.visible: hovered; ToolTip.delay: 400 }
    }

    Repeater {
        model: root._currentSkin.length > 0 ? root.slotCount : 0
        delegate: Item {
            id: zoneRoot
            Layout.fillWidth: true
            required property int index
            readonly property int zi: index
            implicitHeight: zoneCol.implicitHeight

            ColumnLayout {
                id: zoneCol
                anchors.left: parent.left; anchors.right: parent.right
                spacing: Theme.spacingXXS

                // En-tête : pastille + nom éditable + case équipe
                RowLayout {
                    Layout.fillWidth: true; spacing: Theme.spacingS
                    Rectangle { width: 14; height: 14; radius: 7
                        color: root.slotPaletteHex[zoneRoot.zi]; border.color: "#222"; border.width: 1 }
                    Label { text: zoneRoot.zi; color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption; Layout.preferredWidth: 12 }
                    TextField {
                        Layout.fillWidth: true
                        text: root.zoneNames[zoneRoot.zi]
                        placeholderText: "zone " + zoneRoot.zi
                        font.pixelSize: Theme.fontSizeSmall; color: Theme.textPrimary
                        placeholderTextColor: Theme.textHint
                        background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusXS }
                        onEditingFinished: root.setZoneName(zoneRoot.zi, text)
                    }
                    StyledCheckBox {
                        text: "équipe"; font.pixelSize: Theme.fontSizeCaption
                        checked: root.zoneTeam[zoneRoot.zi]
                        onToggled: root.setZoneTeam(zoneRoot.zi, checked)
                        ToolTip.text: "Teintée par la couleur d'équipe au runtime"; ToolTip.visible: hovered; ToolTip.delay: 400
                    }
                }

                // Teinte
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 20; spacing: Theme.spacingS
                    Label { text: "teinte"; color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption; Layout.preferredWidth: 42 }
                    Rectangle { width: 36; height: 22; radius: Theme.radiusXS
                        color: root.tints[zoneRoot.zi]
                        border.color: root.colorTarget === ("zone:" + zoneRoot.zi) ? Theme.accentAlt : Theme.borderLight
                        border.width: root.colorTarget === ("zone:" + zoneRoot.zi) ? 2 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root._toggleColor("zone:" + zoneRoot.zi) } }
                    TintModeSelector {
                        mode: root.tintModes[zoneRoot.zi]
                        onPicked: (m) => root.setTintMode(zoneRoot.zi, m)
                    }
                    MeowSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: root.tintStrengths[zoneRoot.zi]
                        showValue: false
                        onMoved: (v) => root.setTintStrength(zoneRoot.zi, v) }
                }
                // Picker HSL inline de la teinte de zone.
                Loader {
                    Layout.fillWidth: true; Layout.leftMargin: 20
                    active: root.colorTarget === ("zone:" + zoneRoot.zi); visible: active
                    sourceComponent: Component {
                        InlineColorPicker {
                            color: root.tints[zoneRoot.zi]
                            onColorPicked: (c) => root.setTint(zoneRoot.zi, c)
                        }
                    }
                }

                // Texture (≤ maxTex) — un libellé indique le drag & drop quand la lib est vide.
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 20; spacing: Theme.spacingS
                    visible: zoneRoot.zi < root.maxTex
                    Label { text: "texture"; color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption; Layout.preferredWidth: 42 }
                    StyledComboBox {
                        Layout.fillWidth: true; font.pixelSize: Theme.fontSizeSmall; implicitHeight: 26
                        visible: (root.textureLib || []).length > 0
                        model: ["Aucune"].concat((root.textureLib || []).map(function(t){ return t.name }))
                        currentIndex: root.texSelections[zoneRoot.zi] || 0
                        onActivated: root.setTexSelection(zoneRoot.zi, currentIndex)
                    }
                    Text {
                        Layout.fillWidth: true; visible: (root.textureLib || []).length === 0
                        text: "glisse une image ici…"; color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption; font.italic: true
                    }
                }
                // Opacité texture (si une texture choisie)
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 20; spacing: Theme.spacingS
                    visible: zoneRoot.zi < root.maxTex && (root.texSelections[zoneRoot.zi] || 0) > 0
                    Label { text: "opacité"; color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption; Layout.preferredWidth: 42 }
                    MeowSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: root.texOpacities[zoneRoot.zi]
                        showValue: false
                        onMoved: (v) => root.setTexOpacity(zoneRoot.zi, v) }
                    Rectangle { width: 26; height: 20; radius: Theme.radiusXS
                        color: root.texTints[zoneRoot.zi]
                        border.color: root.colorTarget === ("tex:" + zoneRoot.zi) ? Theme.accentAlt : Theme.borderLight
                        border.width: root.colorTarget === ("tex:" + zoneRoot.zi) ? 2 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root._toggleColor("tex:" + zoneRoot.zi) } }
                    StyledCheckBox { text: "inv"; font.pixelSize: Theme.fontSizeCaption; checked: root.textureInverts[zoneRoot.zi]
                        onToggled: root.setTextureInvert(zoneRoot.zi, checked) }
                }
                // Picker HSL inline de la teinte de texture.
                Loader {
                    Layout.fillWidth: true; Layout.leftMargin: 20
                    active: root.colorTarget === ("tex:" + zoneRoot.zi); visible: active
                    sourceComponent: Component {
                        InlineColorPicker {
                            color: root.texTints[zoneRoot.zi]
                            onColorPicked: (c) => root.setTexTint(zoneRoot.zi, c)
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }
            }

            // --- Drag & drop : déposer une image sur la zone → import + assignation ---
            DropArea {
                anchors.fill: parent
                enabled: zoneRoot.zi < root.maxTex
                keys: ["text/uri-list"]
                onEntered: (drag) => { dropHi.visible = drag.hasUrls }
                onExited: dropHi.visible = false
                onDropped: (drop) => {
                    dropHi.visible = false
                    if (drop.hasUrls && drop.urls.length > 0)
                        root.importTextureToZone(zoneRoot.zi, drop.urls[0])
                }
            }
            Rectangle {
                id: dropHi
                anchors.fill: parent
                visible: false
                color: Qt.alpha(Theme.accentAlt, 0.13)
                border.color: Theme.accentAlt; border.width: 2; radius: Theme.radiusS
                Text {
                    anchors.centerIn: parent
                    text: "Déposer l'image — zone " + zoneRoot.zi
                    color: "#d1fae5"; font.pixelSize: Theme.fontSizeBody; font.bold: true
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true; spacing: Theme.spacingS; visible: root._currentSkin.length > 0
        StyledButton { text: "Réinitialiser"; Layout.fillWidth: true; onClicked: root.resetConfig() }
        StyledButton { primary: true; text: "＋ Texture"; Layout.fillWidth: true; onClicked: textureDialog.open()
            ToolTip.text: "Importer une texture dans la bibliothèque du skin"; ToolTip.visible: hovered; ToolTip.delay: 400 }
    }

    // --- Textures du modèle (suppression + nettoyage) ---
    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; visible: root._currentSkin.length > 0 }
    RowLayout {
        Layout.fillWidth: true; visible: root._currentSkin.length > 0
        Label { text: "Textures du modèle (" + (root.textureLib || []).length + ")"
            color: Theme.textSoft; font.bold: true; font.pixelSize: Theme.fontSizeBody; Layout.fillWidth: true }
        StyledButton { text: "Nettoyer inutilisées"; font.pixelSize: Theme.fontSizeCaption
            enabled: (root.textureLib || []).length > 0
            onClicked: root.removeUnusedModelTextures()
            ToolTip.text: "Supprime du modèle les textures référencées par aucune zone ET aucune variante"; ToolTip.visible: hovered; ToolTip.delay: 400 }
    }
    Repeater {
        model: root._currentSkin.length > 0 ? (root.textureLib || []) : []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: Theme.spacingS
            Rectangle { width: 8; height: 8; radius: 4
                color: root.isTextureUsed(modelData.file) ? Theme.accentAlt : Theme.textHint }
            Label { text: modelData.name; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall
                Layout.fillWidth: true; elide: Text.ElideRight }
            Label { visible: !root.isTextureUsed(modelData.file); text: "inutilisée"
                color: Theme.textHint; font.pixelSize: Theme.fontSizeTiny }
            StyledButton { id: delModelBtn; danger: true
                leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                implicitWidth: 34; implicitHeight: 28
                contentItem: Item {
                    TrashIcon { anchors.centerIn: parent; width: 14; height: 16
                        color: delModelBtn.hovered ? Theme.dangerSoft : Theme.textSecondary }
                }
                onClicked: root.deleteModelTexture(modelData.file)
                ToolTip.text: "Supprimer du modèle"; ToolTip.visible: hovered; ToolTip.delay: 400 }
        }
    }

    // --- Bibliothèque générale (partagée) ---
    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface; visible: root._currentSkin.length > 0 }
    RowLayout {
        Layout.fillWidth: true; visible: root._currentSkin.length > 0
        Label { text: "Bibliothèque générale (" + (root.generalTextures || []).length + ")"
            color: Theme.textSoft; font.bold: true; font.pixelSize: Theme.fontSizeBody; Layout.fillWidth: true }
        StyledButton { primary: true; text: "＋ Importer"; font.pixelSize: Theme.fontSizeCaption; onClicked: generalTextureDialog.open()
            ToolTip.text: "Importer une image dans la bibliothèque partagée entre modèles"; ToolTip.visible: hovered; ToolTip.delay: 400 }
    }
    Text {
        visible: root._currentSkin.length > 0 && (root.generalTextures || []).length === 0
        text: "Bibliothèque vide — importe ici des textures réutilisables sur tous les modèles."
        color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption; Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
    Repeater {
        model: root._currentSkin.length > 0 ? (root.generalTextures || []) : []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: Theme.spacingS
            Rectangle { width: 8; height: 8; radius: 4; color: Theme.accent }
            Label { text: modelData; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSmall
                Layout.fillWidth: true; elide: Text.ElideRight }
            StyledButton { text: "→ modèle"; font.pixelSize: Theme.fontSizeCaption; implicitHeight: 24
                enabled: root._currentSkin.length > 0
                onClicked: root.copyGeneralToSkin(modelData)
                ToolTip.text: "Copier dans le skin du modèle courant"; ToolTip.visible: hovered; ToolTip.delay: 400 }
            StyledButton { id: delGenBtn; danger: true
                leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                implicitWidth: 34; implicitHeight: 28
                contentItem: Item {
                    TrashIcon { anchors.centerIn: parent; width: 14; height: 16
                        color: delGenBtn.hovered ? Theme.dangerSoft : Theme.textSecondary }
                }
                onClicked: root.removeGeneralTexture(modelData)
                ToolTip.text: "Supprimer de la bibliothèque générale"; ToolTip.visible: hovered; ToolTip.delay: 400 }
        }
    }

    // ====================== Sélecteur de couleur inline ======================
    // Pastille dont le picker HSL est déplié : "base" | "zone:<i>" | "tex:<i>" | "".
    property string colorTarget: ""
    function _toggleColor(id) { root.colorTarget = (root.colorTarget === id) ? "" : id }

    // ====================== Dialogues ======================

    Dialog {
        id: newSkinDialog
        title: "Nouveau skin"
        anchors.centerIn: Overlay.overlay
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        property url pickedColorMap: ""
        onAccepted: {
            const nm = newSkinName.text.trim()
            if (nm.length === 0) { root.statusMessage("Nom de skin vide."); return }
            let src = newSkinDialog.pickedColorMap.toString()
            if (LauncherManager.createModelSkin(root.folderPath, nm, src)) {
                root.refreshSkins(); root.loadSkin(nm)
                root.statusMessage("Skin créé : " + nm)
            } else root.statusMessage("Échec création du skin.")
            newSkinName.text = ""; newSkinDialog.pickedColorMap = ""
        }
        ColumnLayout {
            spacing: Theme.spacingM
            TextField { id: newSkinName; placeholderText: "nom du skin (ex: default)"; Layout.preferredWidth: 280 }
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.spacingS
                StyledButton { text: "Choisir colorMap…"; onClicked: colorMapDialog.open() }
                Text { Layout.fillWidth: true; elide: Text.ElideMiddle; color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption
                    text: newSkinDialog.pickedColorMap.toString().length > 0
                          ? newSkinDialog.pickedColorMap.toString() : "(optionnel)" }
            }
        }
    }
    FileDialog {
        id: colorMapDialog
        title: "Color map (color ID map)"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.tga *.bmp)", "Tous (*)"]
        onAccepted: newSkinDialog.pickedColorMap = selectedFile
    }
    FileDialog {
        id: textureDialog
        title: "Importer une texture dans le skin"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.tga *.bmp)", "Tous (*)"]
        onAccepted: {
            if (LauncherManager.importSkinTexture(root.folderPath, root._currentSkin, selectedFile.toString())) {
                root.rescanTextureLib()   // re-scan sans wiper la config des zones
                root.statusMessage("Texture importée.")
            }
        }
    }
    FileDialog {
        id: generalTextureDialog
        title: "Importer une texture dans la bibliothèque générale"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.tga *.bmp)", "Tous (*)"]
        onAccepted: root.importIntoGeneral(selectedFile)
    }
}
