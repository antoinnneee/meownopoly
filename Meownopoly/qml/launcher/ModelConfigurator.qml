/*
 * ModelConfigurator.qml — Configurateur de modèle 3D plein écran.
 *
 * Workflow :
 *  1. L'utilisateur sélectionne un dossier source (ex: dossier Princess
 *     contenant Princess.qml + meshes/ + maps/ + model_manifest.json).
 *  2. On extrait nom + version du manifest, et on lit l'éventuel bloc
 *     // __MODEL_TRANSFORM_BEGIN__/END__ déjà présent dans le .qml.
 *  3. On neutralise ce bloc (writeModelTransform identité) pour que le
 *     wrapper du viewport applique seul le transform — pas de double.
 *  4. Sliders scale + eulerRotation : preview live via le wrapper.
 *  5. Comparaison : ComboBox avec les modèles installés
 *     (AssetManager.availablePlayerModels + Cube/Sphere).
 *  6. Caméra : toggle Game (ortho 55°) / Face (turntable).
 *  7. Sauvegarder & Uploader : injecte le marker dans le .qml,
 *     créé le .meow et l'upload.
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import AssetManager
import LauncherManager 1.0
import theme
import ui_item

Rectangle {
    id: root
    color: Theme.background

    signal closeRequested()


    // URL du serveur de ressources, à passer depuis le Launcher (logic.serverUrl).
    property string serverUrl: ""

    // --- État interne ---
    property string folderPath: ""           // chemin clean (sans file:///)
    property string modelName: ""            // ex "Princess"
    property string modelVersion: "1.0.0"
    property string comparisonName: ""
    property string cameraMode: "game"

    // Dossier (clean) à charger d'emblée à l'ouverture (bouton « Éditer » du
    // launcher). Vide = ouverture sans modèle.
    property string initialFolderPath: ""
    // Onglet du panneau de contrôles : "3d" (transform) | "tex" (skin/textures).
    property string controlTab: "3d"

    Component.onCompleted: {
        if (root.initialFolderPath && root.initialFolderPath.length > 0)
            root.loadFromFolder(root.initialFolderPath)
    }

    // --- Format kura (.glb + skins) ---
    property url    glbUrl: ""               // file:///<folder>/base/<glb>
    property url    baseColorUrl: ""         // file:///<folder>/<skinBase>
    property string glbRel: ""               // chemin relatif du .glb (manifest)
    property string skinBaseRel: ""          // chemin relatif de la peau (manifest)

    // Transform live (édité par les sliders) — échelle par défaut 100.
    property real scaleX: 100
    property real scaleY: 100
    property real scaleZ: 100
    property bool scaleLocked: true
    property real eulerX: 0
    property real eulerY: 0
    property real eulerZ: 0
    property real posX: 0
    property real posY: 0
    property real posZ: 0

    // Computed
    readonly property bool hasFolder: folderPath.length > 0 && modelName.length > 0
    readonly property url  modelSourceUrl: hasFolder
        ? ("file:///" + folderPath + "/" + modelName + ".qml")
        : ""
    readonly property var  installedModels: AssetManager.availablePlayerModels()

    // Charge un modèle au format kura : <folder>/base/<glb> + skins/ +
    // model_manifest.json (name, version, glb, skinBase, transform, colorId).
    function loadFromFolder(rawPath) {
        let cleaned = rawPath
        if (cleaned.startsWith("file:///")) cleaned = cleaned.substring(8)
        else if (cleaned.startsWith("file://")) cleaned = cleaned.substring(7)

        const manifest = LauncherManager.readModelManifest(cleaned) || {}
        const folderName = cleaned.substring(cleaned.lastIndexOf("/") + 1)
        const name    = manifest.name    ? manifest.name    : folderName
        const version = manifest.version ? manifest.version : "1.0.0"
        const glbRel      = manifest.glb      ? manifest.glb      : ("base/" + name + ".glb")
        const skinBaseRel = manifest.skinBase ? manifest.skinBase : "base/skin_base.png"

        root.modelName    = name
        root.modelVersion = version
        root.folderPath   = cleaned
        root.glbRel       = glbRel
        root.skinBaseRel  = skinBaseRel
        root.glbUrl       = "file:///" + cleaned + "/" + glbRel
        root.baseColorUrl = "file:///" + cleaned + "/" + skinBaseRel

        // Transform depuis le manifest (plus de marker .qml).
        const t = manifest.transform
        if (t && t.scale && t.eulerRotation) {
            root.scaleX = t.scale[0]; root.scaleY = t.scale[1]; root.scaleZ = t.scale[2]
            root.eulerX = t.eulerRotation[0]; root.eulerY = t.eulerRotation[1]; root.eulerZ = t.eulerRotation[2]
            if (t.position) { root.posX = t.position[0]; root.posY = t.position[1]; root.posZ = t.position[2] }
            else { root.posX = 0; root.posY = 0; root.posZ = 0 }
        } else {
            resetTransform()
        }
        // skinEditor.folderPath est bindé sur root.folderPath → refreshSkins auto.

        statusBar.message = "Modèle chargé : " + root.modelName + " v" + root.modelVersion
    }

    function resetTransform() {
        scaleX = 100; scaleY = 100; scaleZ = 100
        eulerX = 0; eulerY = 0; eulerZ = 0
        posX = 0; posY = 0; posZ = 0
    }

    // Normalise un nom de modèle : trim + première lettre en majuscule.
    // Le nom de modèle doit toujours commencer par une majuscule.
    function _capitalizeName(name) {
        const t = (name || "").trim()
        if (t.length === 0) return t
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    function applyTransformAndSave(uploadAfter) {
        if (!hasFolder) return
        // Garantit la majuscule initiale même si modelName a été défini ailleurs.
        root.modelName = root._capitalizeName(root.modelName)
        if (!modelName || modelName.length === 0) {
            statusBar.message = "Nom de modèle manquant."
            return
        }
        if (!modelVersion || modelVersion.length === 0) {
            statusBar.message = "Version manquante."
            return
        }
        if (uploadAfter && (!root.serverUrl || root.serverUrl.length === 0)) {
            statusBar.message = "URL serveur vide — configurez-la dans le launcher avant d'uploader."
            return
        }

        // Persiste le skin courant (noms de zones + flags équipe).
        skinEditor.saveSkinJson()

        // Manifest (transform + colorId migrent ici, plus de marker .qml).
        const manifest = {
            name: root.modelName, version: root.modelVersion, type: "model",
            glb: root.glbRel.length > 0 ? root.glbRel : ("base/" + root.modelName + ".glb"),
            skinBase: root.skinBaseRel.length > 0 ? root.skinBaseRel : "base/skin_base.png",
            transform: {
                scale: [root.scaleX, root.scaleY, root.scaleZ],
                eulerRotation: [root.eulerX, root.eulerY, root.eulerZ],
                position: [root.posX, root.posY, root.posZ]
            },
            colorId: { version: 1, defaultSkin: skinEditor.currentSkin, defaultVariant: "" }
        }
        if (!LauncherManager.writeModelManifest(folderPath, JSON.stringify(manifest, null, 2))) {
            statusBar.message = "Échec de l'écriture du manifest."
            return
        }
        LauncherManager.createModelPackage(folderPath, modelName, modelVersion)
        statusBar.message = uploadAfter
            ? "Manifest + paquet créés, upload en cours..."
            : "Manifest + paquet créés."
        if (uploadAfter) {
            LauncherManager.uploadModelPackage(root.serverUrl, modelName, modelVersion)
        }
    }

    function reloadCurrentFolder() {
        if (!folderPath) return
        loadFromFolder(folderPath)
    }

    FolderDialog {
        id: folderDialog
        title: "Sélectionner le dossier du modèle 3D"
        onAccepted: root.loadFromFolder(selectedFolder.toString())
    }

    // --- Nouveau modèle depuis un .glb (remplace l'import balsam) ---
    Dialog {
        id: newModelDialog
        title: "Nouveau modèle (.glb)"
        anchors.centerIn: Overlay.overlay
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        property url glb: ""
        property url skinBase: ""
        onAccepted: {
            const nm = newModelName.text.trim()
            if (nm.length === 0) { statusBar.message = "Nom du modèle vide."; return }
            if (newModelDialog.glb.toString().length === 0) { statusBar.message = "Choisis un fichier .glb."; return }
            const folder = LauncherManager.createModelFromGlb("", nm,
                              newModelDialog.glb.toString(), newModelDialog.skinBase.toString())
            if (folder && folder.length > 0) root.loadFromFolder(folder)
            else statusBar.message = "Échec de la création du modèle."
        }
        ColumnLayout {
            spacing: Theme.spacingM
            TextField {
                id: newModelName
                placeholderText: "nom du modèle (ex: Kura)"
                Layout.preferredWidth: 320
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.spacingS
                MeowButton { text: "Choisir .glb…"; variant: "secondary"; fontSize: Theme.fontSizeBody; hoverZoom: false; onClicked: glbDialog.open() }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideMiddle
                    color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption
                    text: newModelDialog.glb.toString().length > 0 ? newModelDialog.glb.toString() : "(requis)"
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.spacingS
                MeowButton { text: "Base color (peau)…"; variant: "secondary"; fontSize: Theme.fontSizeBody; hoverZoom: false; onClicked: skinBaseDialog.open() }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideMiddle
                    color: Theme.textHint; font.pixelSize: Theme.fontSizeCaption
                    text: newModelDialog.skinBase.toString().length > 0 ? newModelDialog.skinBase.toString() : "(optionnel)"
                }
            }
        }
    }
    FileDialog {
        id: glbDialog
        title: "Modèle .glb"
        nameFilters: ["Modèles 3D (*.glb *.gltf)", "Tous les fichiers (*)"]
        onAccepted: newModelDialog.glb = selectedFile
    }
    FileDialog {
        id: skinBaseDialog
        title: "Base color (peau)"
        nameFilters: ["Images (*.png *.jpg *.jpeg)", "Tous les fichiers (*)"]
        onAccepted: newModelDialog.skinBase = selectedFile
    }

    // (balsam retiré — import remplacé par « Nouveau modèle (.glb) »)

    // ============================================================
    // Composants réutilisables
    // ============================================================
    component AxisSlider: RowLayout {
        id: axisRow
        property string axisLabel: "X"
        property real minValue: 0
        property real maxValue: 100
        property real stepValue: 0.01
        property real boundValue: 0
        property real defaultValue: 0
        property int decimals: 2
        signal valueEdited(real v)
        spacing: Theme.spacingS
        Text {
            text: axisRow.axisLabel
            color: Theme.textHint
            Layout.preferredWidth: 18
            verticalAlignment: Text.AlignVCenter
        }
        MeowSlider {
            id: slider
            Layout.fillWidth: true
            from: axisRow.minValue
            to:   axisRow.maxValue
            stepSize: axisRow.stepValue
            value: axisRow.boundValue
            showValue: false
            onMoved: (v) => axisRow.valueEdited(v)
        }
        TextField {
            id: tf
            Layout.preferredWidth: 70
            text: axisRow.boundValue.toFixed(axisRow.decimals)
            color: Theme.textPrimary
            background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusXS }
            validator: DoubleValidator { bottom: axisRow.minValue; top: axisRow.maxValue }
            onEditingFinished: {
                const v = parseFloat(text.replace(",", "."))
                if (!isNaN(v)) axisRow.valueEdited(v)
            }
        }
        Button {
            id: btnResetAxis
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            text: "↺"
            ToolTip.visible: hovered
            ToolTip.delay: 400
            ToolTip.text: "Réinitialiser à " + axisRow.defaultValue.toFixed(axisRow.decimals)
            onClicked: axisRow.valueEdited(axisRow.defaultValue)
            background: Rectangle {
                color: btnResetAxis.pressed ? Theme.pressed(Theme.borderLight) : (btnResetAxis.hovered ? Theme.surfaceHover : "transparent")
                border.color: Theme.border
                radius: Theme.radiusXS
            }
            contentItem: Text {
                text: btnResetAxis.text
                color: Theme.textHint
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }

    // ============================================================
    // Layout
    // ============================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingL

        // ---- Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXL

            MeowButton {
                text: "Retour"
                iconText: "←"
                variant: "secondary"
                baseColor: Theme.borderLight
                fontSize: Theme.fontSizeBody
                hoverZoom: false
                onClicked: root.closeRequested()
            }

            Text {
                text: "Configurateur de modèle 3D"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
            }

            // Identité du modèle (déplacée du panneau vers la top bar).
            Text { text: "Nom"; color: Theme.textHint; font.pixelSize: Theme.fontSizeBody; Layout.leftMargin: Theme.spacingM }
            TextField {
                id: nameField
                Layout.preferredWidth: 150
                text: root.modelName
                placeholderText: "Princess"
                // Majuscule forcée sur le premier caractère du nom de modèle.
                onEditingFinished: {
                    const norm = root._capitalizeName(text)
                    root.modelName = norm
                    if (text !== norm)
                        text = norm
                }
                color: Theme.textPrimary
                placeholderTextColor: Theme.textHint
                background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusXS }
            }
            Text { text: "Version"; color: Theme.textHint; font.pixelSize: Theme.fontSizeBody }
            TextField {
                Layout.preferredWidth: 80
                text: root.modelVersion
                placeholderText: "1.0.0"
                onEditingFinished: root.modelVersion = text
                color: Theme.textPrimary
                placeholderTextColor: Theme.textHint
                background: Rectangle { color: Theme.background; border.color: Theme.border; radius: Theme.radiusXS }
            }

            Item { Layout.fillWidth: true }   // spacer

            // Toggle caméra
            Row {
                spacing: Theme.spacingS
                MeowButton {
                    id: btnGame
                    text: "Vue jeu"
                    // Pas de `checkable` : le binding `checked` pilote seul l'état
                    // visuel (sinon le click toggle casse le binding → deselect trompeur).
                    checked: root.cameraMode === "game"
                    baseColor: btnGame.checked ? Theme.accent : Theme.borderLight
                    fontSize: Theme.fontSizeBody
                    hoverZoom: false
                    glossy: false
                    onClicked: root.cameraMode = "game"
                }
                MeowButton {
                    id: btnFace
                    text: "Face"
                    checked: root.cameraMode === "face"
                    baseColor: btnFace.checked ? Theme.accent : Theme.borderLight
                    fontSize: Theme.fontSizeBody
                    hoverZoom: false
                    glossy: false
                    onClicked: root.cameraMode = "face"
                }
            }

            MeowButton {
                text: "Reset vue"
                baseColor: Theme.borderLight
                fontSize: Theme.fontSizeBody
                hoverZoom: false
                onClicked: viewport.resetView()
            }

        }

        // ---- Body : viewport + panneau droit
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingL

            // Viewport
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#0f0f12"
                radius: Theme.radiusM
                border.color: Theme.border
                clip: true

                Model3DPreview {
                    id: viewport
                    anchors.fill: parent
                    modelName: root.modelName
                    subjectScale: Qt.vector3d(root.scaleX, root.scaleY, root.scaleZ)
                    subjectEuler: Qt.vector3d(root.eulerX, root.eulerY, root.eulerZ)
                    subjectPosition: Qt.vector3d(root.posX, root.posY, root.posZ)
                    comparisonName: root.comparisonName
                    cameraMode: root.cameraMode

                    // Sujet Color ID Map (.glb + skin live depuis skinEditor)
                    subjectGlbUrl: root.glbUrl
                    subjectBaseColorUrl: root.baseColorUrl
                    subjectColorMapUrl: skinEditor.colorMapUrl
                    subjectSkinUrl: skinEditor.skinUrl
                    subjectTextureLib: skinEditor.textureLib
                    subjectConfig: skinEditor.config
                    subjectTeamZones: skinEditor.teamZones
                    subjectSlotCount: skinEditor.slotCount
                    subjectDebugMode: skinEditor.debugMode
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !root.hasFolder
                    color: Theme.surface
                    radius: Theme.radiusM
                    border.color: Theme.border
                    width: 380; height: 80
                    Text {
                        anchors.centerIn: parent
                        text: "Sélectionnez un dossier, ou déposez un .glb pour créer un modèle"
                        color: Theme.textHint
                    }
                }

                // Drag & drop d'un .glb sur le viewport → ouvre « Nouveau modèle ».
                DropArea {
                    id: objDropArea
                    anchors.fill: parent
                    onEntered: (drag) => {
                        if (drag.hasUrls && drag.urls.length > 0) {
                            const u = drag.urls[0].toString().toLowerCase()
                            if (u.endsWith(".glb") || u.endsWith(".gltf")) drag.accept()
                        }
                    }
                    onDropped: (drop) => {
                        if (drop.hasUrls && drop.urls.length > 0) {
                            const u = drop.urls[0].toString()
                            const ul = u.toLowerCase()
                            if (ul.endsWith(".glb") || ul.endsWith(".gltf")) {
                                const slash = Math.max(u.lastIndexOf("/"), u.lastIndexOf("\\"))
                                let base = slash >= 0 ? u.substring(slash + 1) : u
                                const dot = base.lastIndexOf(".")
                                if (dot > 0) base = base.substring(0, dot)
                                newModelDialog.glb = u
                                newModelDialog.skinBase = ""
                                newModelName.text = base
                                newModelDialog.open()
                                drop.accept()
                            }
                        }
                    }
                }

                // Overlay visuel pendant un drag valide
                Rectangle {
                    anchors.fill: parent
                    visible: objDropArea.containsDrag
                    color: Qt.alpha(Theme.success, 0.2)
                    border.color: Theme.success
                    border.width: 3
                    radius: Theme.radiusM
                    z: 50
                    Text {
                        anchors.centerIn: parent
                        text: "Déposer un .glb pour créer un modèle"
                        color: Theme.success
                        font.pixelSize: Theme.fontSizeDisplay
                        font.bold: true
                    }
                }
            }

            // Panneau de contrôles (2 onglets : 3D / Textures) pour raccourcir le scroll
            ColumnLayout {
                // Un ColumnLayout imbriqué dans un RowLayout a fillWidth=true par
                // défaut → il écraserait le viewport 3D. On force une largeur fixe.
                Layout.fillWidth: false
                Layout.preferredWidth: 380
                Layout.maximumWidth: 380
                Layout.fillHeight: true
                spacing: Theme.spacingM

                // Onglets
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS
                    Repeater {
                        model: [ { k: "3d", t: "3D" }, { k: "tex", t: "Textures" } ]
                        delegate: Button {
                            id: tabBtn
                            required property var modelData
                            text: modelData.t
                            Layout.fillWidth: true
                            implicitHeight: 32
                            checkable: true
                            autoExclusive: true
                            checked: root.controlTab === modelData.k
                            onClicked: root.controlTab = modelData.k
                            background: Rectangle {
                                radius: Theme.radiusS
                                color: tabBtn.checked ? Theme.accent : (tabBtn.hovered ? Theme.surfaceHover : Theme.surface)
                                border.color: tabBtn.checked ? Theme.accent : Theme.border
                                border.width: 1
                            }
                            contentItem: Text {
                                text: tabBtn.text; color: Theme.textPrimary; font.bold: tabBtn.checked
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // --- Onglet 3D : source, transform, comparaison, actions
                ScrollView {
                    id: tab3dScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: root.controlTab === "3d"

                    ColumnLayout {
                        width: tab3dScroll.availableWidth
                        spacing: Theme.spacingXL

                        // --- Source
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Source"
                        background: Rectangle { color: Theme.surface; radius: Theme.radiusM; border.color: Theme.border }
                        label: Text { text: parent.title; color: Theme.textSoft; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingS

                            Text {
                                text: root.folderPath || "Aucun dossier sélectionné"
                                color: root.folderPath ? Theme.textSecondary : Theme.textHint
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                wrapMode: Text.NoWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingS

                                MeowButton {
                                    id: btnPickFolder
                                    text: "Sélectionner dossier..."
                                    Layout.fillWidth: true
                                    baseColor: "#795548"
                                    fontSize: Theme.fontSizeBody
                                    hoverZoom: false
                                    onClicked: folderDialog.open()
                                }
                                Button {
                                    id: btnReload
                                    text: "↻"
                                    enabled: root.hasFolder
                                    Layout.preferredWidth: 36
                                    onClicked: root.reloadCurrentFolder()
                                    ToolTip.visible: hovered
                                    ToolTip.delay: 400
                                    ToolTip.text: "Recharger le dossier (re-scan manifest + transform)"
                                    background: Rectangle { color: btnReload.enabled ? (btnReload.pressed ? Theme.pressed(Theme.borderLight) : Theme.borderLight) : Theme.surfaceHover; radius: Theme.radiusS }
                                    contentItem: Text { text: btnReload.text; color: Theme.textPrimary; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: Theme.spacingS }
                                }
                            }

                            MeowButton {
                                id: btnNewModel
                                text: "Nouveau modèle (.glb)"
                                iconText: "＋"
                                Layout.fillWidth: true
                                variant: "primary"
                                fontSize: Theme.fontSizeBody
                                hoverZoom: false
                                onClicked: {
                                    newModelDialog.glb = ""
                                    newModelDialog.skinBase = ""
                                    newModelName.text = ""
                                    newModelDialog.open()
                                }
                            }
                        }
                    }

                    // --- Comparaison
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Comparaison"
                        background: Rectangle { color: Theme.surface; radius: Theme.radiusM; border.color: Theme.border }
                        label: Text { text: parent.title; color: Theme.textSoft; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingS

                            StyledComboBox {
                                id: compCombo
                                Layout.fillWidth: true
                                model: ["<Aucun>"].concat(root.installedModels)
                                onActivated: {
                                    root.comparisonName = (currentIndex <= 0) ? "" : currentText
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Décalage X"; color: Theme.textSecondary }
                                MeowSlider {
                                    Layout.fillWidth: true
                                    from: 0; to: 1000
                                    value: viewport.comparisonOffsetX
                                    showValue: false
                                    onMoved: (v) => viewport.comparisonOffsetX = v
                                }
                                Text { text: viewport.comparisonOffsetX.toFixed(0); color: Theme.textHint; Layout.preferredWidth: 36 }
                            }
                        }
                    }


                    // --- Échelle
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Échelle"
                        background: Rectangle { color: Theme.surface; radius: Theme.radiusM; border.color: Theme.border }
                        label: Text { text: parent.title; color: Theme.textSoft; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingS

                            StyledCheckBox {
                                text: "Verrouillage uniforme (XYZ)"
                                checked: root.scaleLocked
                                onCheckedChanged: root.scaleLocked = checked
                            }

                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "X"
                                minValue: 0.05; maxValue: 500; stepValue: 0.05; decimals: 2
                                defaultValue: 100
                                boundValue: root.scaleX
                                onValueEdited: (v) => {
                                    root.scaleX = v
                                    if (root.scaleLocked) { root.scaleY = v; root.scaleZ = v }
                                }
                            }
                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "Y"
                                minValue: 0.05; maxValue: 500; stepValue: 0.05; decimals: 2
                                defaultValue: 100
                                boundValue: root.scaleY
                                onValueEdited: (v) => {
                                    root.scaleY = v
                                    if (root.scaleLocked) { root.scaleX = v; root.scaleZ = v }
                                }
                            }
                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "Z"
                                minValue: 0.05; maxValue: 500; stepValue: 0.05; decimals: 2
                                defaultValue: 100
                                boundValue: root.scaleZ
                                onValueEdited: (v) => {
                                    root.scaleZ = v
                                    if (root.scaleLocked) { root.scaleX = v; root.scaleY = v }
                                }
                            }
                        }
                    }

                    // --- Rotation
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Rotation (degrés)"
                        background: Rectangle { color: Theme.surface; radius: Theme.radiusM; border.color: Theme.border }
                        label: Text { text: parent.title; color: Theme.textSoft; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingS

                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "X"
                                minValue: -180; maxValue: 180; stepValue: 1; decimals: 1
                                defaultValue: 0
                                boundValue: root.eulerX
                                onValueEdited: (v) => root.eulerX = v
                            }
                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "Y"
                                minValue: -180; maxValue: 180; stepValue: 1; decimals: 1
                                defaultValue: 0
                                boundValue: root.eulerY
                                onValueEdited: (v) => root.eulerY = v
                            }
                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "Z"
                                minValue: -180; maxValue: 180; stepValue: 1; decimals: 1
                                defaultValue: 0
                                boundValue: root.eulerZ
                                onValueEdited: (v) => root.eulerZ = v
                            }
                        }
                    }

                    // --- Position
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Position (unités monde)"
                        background: Rectangle { color: Theme.surface; radius: Theme.radiusM; border.color: Theme.border }
                        label: Text { text: parent.title; color: Theme.textSoft; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingS

                            Text {
                                text: "Y > 0 = monter (utile pour faire toucher les pieds au sol)"
                                color: Theme.textHint
                                font.pixelSize: Theme.fontSizeCaption
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "X"
                                minValue: -500; maxValue: 500; stepValue: 0.5; decimals: 2
                                defaultValue: 0
                                boundValue: root.posX
                                onValueEdited: (v) => root.posX = v
                            }
                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "Y"
                                minValue: -500; maxValue: 500; stepValue: 0.5; decimals: 2
                                defaultValue: 0
                                boundValue: root.posY
                                onValueEdited: (v) => root.posY = v
                            }
                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "Z"
                                minValue: -500; maxValue: 500; stepValue: 0.5; decimals: 2
                                defaultValue: 0
                                boundValue: root.posZ
                                onValueEdited: (v) => root.posZ = v
                            }

                            MeowButton {
                                text: "Reset transform global"
                                Layout.fillWidth: true
                                baseColor: Theme.borderLight
                                fontSize: Theme.fontSizeBody
                                hoverZoom: false
                                onClicked: root.resetTransform()
                            }
                        }
                    }

                    // --- Actions
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Actions"
                        background: Rectangle { color: Theme.surface; radius: Theme.radiusM; border.color: Theme.border }
                        label: Text { text: parent.title; color: Theme.textSoft; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingS

                            MeowButton {
                                text: "Sauvegarder dans le .qml + créer .meow"
                                Layout.fillWidth: true
                                enabled: root.hasFolder
                                variant: "success"
                                fontSize: Theme.fontSizeBody
                                hoverZoom: false
                                onClicked: root.applyTransformAndSave(false)
                            }
                            MeowButton {
                                text: "Sauvegarder & Uploader"
                                Layout.fillWidth: true
                                enabled: root.hasFolder && !LauncherManager.isDownloading
                                variant: "primary"
                                fontSize: Theme.fontSizeBody
                                hoverZoom: false
                                onClicked: root.applyTransformAndSave(true)
                            }
                        }
                    }
                }
            }

                // --- Onglet Textures : créateur de skin (Color ID Map)
                ScrollView {
                    id: tabTexScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: root.controlTab === "tex"

                    ColumnLayout {
                        width: tabTexScroll.availableWidth
                        spacing: Theme.spacingXL

                        GroupBox {
                            Layout.fillWidth: true
                            title: "Skin (Color ID Map)"
                            background: Rectangle { color: Theme.surface; radius: Theme.radiusM; border.color: Theme.border }
                            label: Text { text: parent.title; color: Theme.textSoft; font.bold: true }

                            SkinEditorPanel {
                                id: skinEditor
                                anchors.fill: parent
                                folderPath: root.folderPath
                                baseColorUrl: root.baseColorUrl
                                onStatusMessage: (msg) => statusBar.message = msg
                            }
                        }
                    }
                }
            }
        }

        // ---- Status bar
        Rectangle {
            id: statusBar
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            color: Theme.surface
            radius: Theme.radiusS
            border.color: Theme.border
            property string message: "Prêt."

            Text {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingL
                verticalAlignment: Text.AlignVCenter
                text: statusBar.message
                      + (LauncherManager.downloadStatus
                         ? "  [" + LauncherManager.downloadStatus + "]"
                         : "")
                color: Theme.textSecondary
                elide: Text.ElideRight
            }
        }
    }
}
