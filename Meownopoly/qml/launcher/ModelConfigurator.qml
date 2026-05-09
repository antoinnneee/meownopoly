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

Rectangle {
    id: root
    color: "#1e1e1e"

    signal closeRequested()

    // Path balsam.exe persistant : binding bidirectionnel via signal
    // (le parent persiste dans QSettings via LauncherLogic).
    property string balsamPath: LauncherManager.balsamPath
    signal balsamPathRequested(string newPath)

    // Options balsam : map clé→bool/real injectée par le parent et
    // remontée via signal balsamOptionRequested(key, value).
    property var balsamOptions: ({})
    signal balsamOptionRequested(string key, var value)
    signal balsamOptionsResetRequested()
    function getBalsamOpt(key, def) {
        return (balsamOptions !== undefined && balsamOptions[key] !== undefined)
               ? balsamOptions[key] : def
    }

    // URL du serveur de ressources, à passer depuis le Launcher (logic.serverUrl).
    property string serverUrl: ""

    // --- État interne ---
    property string folderPath: ""           // chemin clean (sans file:///)
    property string modelName: ""            // ex "Princess"
    property string modelVersion: "1.0.0"
    property string comparisonName: ""
    property string cameraMode: "game"

    // Aperçu .obj externe (drop&drag ou bouton)
    property url auxObjUrl: ""

    // Transform live (édité par les sliders)
    property real scaleX: 1
    property real scaleY: 1
    property real scaleZ: 1
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

    function loadFromFolder(rawPath) {
        let cleaned = rawPath
        if (cleaned.startsWith("file:///")) cleaned = cleaned.substring(8)
        else if (cleaned.startsWith("file://")) cleaned = cleaned.substring(7)

        const detected = LauncherManager.findModelQml(cleaned)
        if (!detected) {
            statusBar.message = "Aucun .qml trouvé dans ce dossier."
            return
        }

        const manifest = LauncherManager.readModelManifest(cleaned)
        const name    = (manifest && manifest.name)    ? manifest.name    : detected
        const version = (manifest && manifest.version) ? manifest.version : "1.0.0"

        // Lire transform existant AVANT d'écrire identité.
        const t = LauncherManager.readModelTransform(cleaned, name)

        // Neutralise le marker AVANT de bind l'URL au Loader3D — sinon le
        // Loader peut parser le fichier avec l'ancien transform et le
        // wrapper du viewport l'appliquerait en double.
        LauncherManager.writeModelTransform(cleaned, name, 1, 1, 1, 0, 0, 0, 0, 0, 0)

        // Mise à jour atomique de l'état (déclenche le bind de modelSourceUrl)
        if (t && t.scale && t.eulerRotation) {
            root.scaleX = t.scale[0]
            root.scaleY = t.scale[1]
            root.scaleZ = t.scale[2]
            root.eulerX = t.eulerRotation[0]
            root.eulerY = t.eulerRotation[1]
            root.eulerZ = t.eulerRotation[2]
            if (t.position) {
                root.posX = t.position[0]
                root.posY = t.position[1]
                root.posZ = t.position[2]
            } else {
                root.posX = 0; root.posY = 0; root.posZ = 0
            }
        } else {
            resetTransform()
        }
        root.modelVersion = version
        root.modelName = name
        root.folderPath = cleaned

        statusBar.message = "Modèle chargé : " + root.modelName + " v" + root.modelVersion
    }

    function resetTransform() {
        scaleX = 1; scaleY = 1; scaleZ = 1
        eulerX = 0; eulerY = 0; eulerZ = 0
        posX = 0; posY = 0; posZ = 0
    }

    function applyTransformAndSave(uploadAfter) {
        if (!hasFolder) return
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
        const ok = LauncherManager.writeModelTransform(
            folderPath, modelName,
            scaleX, scaleY, scaleZ,
            eulerX, eulerY, eulerZ,
            posX, posY, posZ
        )
        if (!ok) {
            statusBar.message = "Échec de l'écriture du transform."
            return
        }
        LauncherManager.createModelPackage(folderPath, modelName, modelVersion)
        statusBar.message = uploadAfter
            ? "Transform écrit, paquet créé, upload en cours..."
            : "Transform écrit, paquet créé."
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

    FileDialog {
        id: objDialog
        title: "Sélectionner un fichier .obj à prévisualiser"
        nameFilters: ["Modèles 3D (*.obj *.gltf *.glb *.fbx)", "Fichiers OBJ (*.obj)", "Tous les fichiers (*)"]
        onAccepted: root.auxObjUrl = selectedFile.toString()
    }

    FileDialog {
        id: balsamPathDialog
        title: "Sélectionner balsam.exe"
        nameFilters: ["Exécutables (*.exe)", "Tous les fichiers (*)"]
        onAccepted: {
            let p = selectedFile.toString()
            if (p.startsWith("file:///")) p = p.substring(8)
            else if (p.startsWith("file://")) p = p.substring(7)
            root.balsamPathRequested(p)
        }
    }

    // Connexion au signal C++ : quand balsam termine, on charge le .qml
    // résultat dans le configurateur (= il devient le nouveau sujet).
    Connections {
        target: LauncherManager
        function onBalsamFinished(success, qmlPath, errorMessage) {
            if (success) {
                statusBar.message = "balsam OK : " + qmlPath
                // qmlPath = .../<dossier>/<Name>.qml → on charge le dossier
                let folder = qmlPath
                const lastSlash = Math.max(folder.lastIndexOf("/"), folder.lastIndexOf("\\"))
                if (lastSlash > 0) folder = folder.substring(0, lastSlash)
                root.loadFromFolder(folder)
            } else {
                statusBar.message = "balsam : ERREUR — " + errorMessage
            }
        }
    }

    function runBalsamOnAuxObj() {
        if (!root.auxObjUrl || root.auxObjUrl.toString().length === 0) return
        let src = root.auxObjUrl.toString()
        if (src.startsWith("file:///")) src = src.substring(8)
        else if (src.startsWith("file://")) src = src.substring(7)

        // Output : <dossier du .obj>/<basename>_qml/
        const lastSlash = Math.max(src.lastIndexOf("/"), src.lastIndexOf("\\"))
        const dir = lastSlash > 0 ? src.substring(0, lastSlash) : "."
        let basename = lastSlash > 0 ? src.substring(lastSlash + 1) : src
        const dot = basename.lastIndexOf(".")
        if (dot > 0) basename = basename.substring(0, dot)
        const outDir = dir + "/" + basename + "_qml"

        statusBar.message = "balsam : conversion en cours vers " + outDir + "..."
        LauncherManager.runBalsamImport(src, outDir, root.balsamOptions)
    }

    // Définitions des options balsam, fournies par le C++ (clé/flag/
    // label/type/default/group/dependsOn). Cf. balsamOptionDefinitions().
    readonly property var _balsamDefs: LauncherManager.balsamOptionDefinitions()
    readonly property var _balsamGroups: {
        // Groupement des défs par "group" (Géométrie / Échelle / etc.)
        const out = {}
        const order = []
        for (let i = 0; i < _balsamDefs.length; ++i) {
            const d = _balsamDefs[i]
            const g = d.group || "Autre"
            if (!out[g]) { out[g] = []; order.push(g) }
            out[g].push(d)
        }
        return { groups: out, order: order }
    }

    // Popup de configuration balsam (path + options de conversion)
    Popup {
        id: balsamConfigPopup
        anchors.centerIn: Overlay.overlay
        modal: true
        focus: true
        width: Math.min(720, root.width - 80)
        height: Math.min(620, root.height - 80)
        padding: 0
        background: Rectangle { color: "#27272a"; border.color: "#3f3f46"; radius: 8 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: "Configuration balsam"
                color: "#e5e7eb"
                font.pixelSize: 16
                font.bold: true
            }
            Text {
                text: "balsam est l'outil Qt Quick3D qui convertit .obj/.glb/.gltf/.fbx en .qml + .mesh + textures. Habituellement situé dans <Qt>/<version>/<compiler>/bin/balsam.exe."
                color: "#9ca3af"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.pixelSize: 11
            }

            // --- Path
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                TextField {
                    Layout.fillWidth: true
                    text: root.balsamPath
                    placeholderText: "C:/Qt/6.11.0/mingw_64/bin/balsam.exe"
                    color: "white"
                    background: Rectangle { color: "#1f1f23"; border.color: "#3a3a3a"; radius: 3 }
                    onEditingFinished: if (text !== root.balsamPath) root.balsamPathRequested(text)
                }
                Button {
                    id: btnBrowseBalsam
                    text: "Parcourir..."
                    onClicked: balsamPathDialog.open()
                    background: Rectangle { color: btnBrowseBalsam.pressed ? "#5d4037" : "#795548"; radius: 4 }
                    contentItem: Text { text: btnBrowseBalsam.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                }
            }
            Text {
                text: root.balsamPath.length > 0
                      ? "✓ " + root.balsamPath
                      : "(aucun chemin configuré)"
                color: root.balsamPath.length > 0 ? "#22c55e" : "#9ca3af"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#3f3f46"
            }

            // --- Options
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Options de conversion"; color: "#e5e7eb"; font.bold: true }
                Item { Layout.fillWidth: true }
                Button {
                    id: btnResetOpts
                    text: "Réinitialiser"
                    onClicked: root.balsamOptionsResetRequested()
                    background: Rectangle { color: btnResetOpts.pressed ? "#374151" : "#4b5563"; radius: 4 }
                    contentItem: Text { text: btnResetOpts.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 4 }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: optionsCol.width
                ColumnLayout {
                    id: optionsCol
                    width: balsamConfigPopup.width - 32
                    spacing: 10

                    Repeater {
                        model: root._balsamGroups.order
                        delegate: GroupBox {
                            required property string modelData
                            Layout.fillWidth: true
                            title: modelData
                            background: Rectangle { color: "#1f1f23"; radius: 6; border.color: "#3a3a3a" }
                            label: Text { text: parent.title; color: "#d1d5db"; font.bold: true }

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 4
                                Repeater {
                                    model: root._balsamGroups.groups[modelData]
                                    delegate: RowLayout {
                                        id: optRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 6
                                        readonly property bool depEnabled:
                                            !modelData.dependsOn
                                            || root.getBalsamOpt(modelData.dependsOn, false)
                                        readonly property string ttText:
                                            (modelData.tooltip || modelData.label)
                                            + (modelData.dependsOn
                                               ? " (nécessite : « " + modelData.dependsOn + " »)"
                                               : "")

                                        // bool → CheckBox
                                        CheckBox {
                                            id: optCheck
                                            visible: modelData.type === "bool"
                                            enabled: optRow.depEnabled
                                            text: modelData.label
                                            checked: root.getBalsamOpt(modelData.key, modelData.default)
                                            onClicked: root.balsamOptionRequested(modelData.key, checked)
                                            ToolTip.visible: hovered
                                            ToolTip.delay: 500
                                            ToolTip.timeout: 8000
                                            ToolTip.text: optRow.ttText
                                            contentItem: Text {
                                                text: optCheck.text
                                                color: optCheck.enabled ? "#d1d5db" : "#6b7280"
                                                leftPadding: optCheck.indicator.width + 6
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: 11
                                            }
                                        }

                                        // real → label cliquable (avec tooltip) + TextField
                                        Item {
                                            visible: modelData.type === "real"
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: realLabel.implicitHeight + 6
                                            Text {
                                                id: realLabel
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.label
                                                color: optRow.depEnabled ? "#d1d5db" : "#6b7280"
                                                font.pixelSize: 11
                                            }
                                            HoverHandler {
                                                id: realHover
                                                cursorShape: Qt.WhatsThisCursor
                                            }
                                            ToolTip.visible: realHover.hovered
                                            ToolTip.delay: 500
                                            ToolTip.timeout: 8000
                                            ToolTip.text: optRow.ttText
                                        }
                                        TextField {
                                            id: optReal
                                            visible: modelData.type === "real"
                                            enabled: optRow.depEnabled
                                            Layout.preferredWidth: 100
                                            text: Number(root.getBalsamOpt(modelData.key, modelData.default)).toString()
                                            color: enabled ? "white" : "#6b7280"
                                            background: Rectangle { color: "#0f0f12"; border.color: "#3a3a3a"; radius: 3 }
                                            validator: DoubleValidator {}
                                            ToolTip.visible: hovered
                                            ToolTip.delay: 500
                                            ToolTip.timeout: 8000
                                            ToolTip.text: optRow.ttText
                                            onEditingFinished: {
                                                const v = parseFloat(text.replace(",", "."))
                                                if (!isNaN(v)) root.balsamOptionRequested(modelData.key, v)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- Footer
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    id: btnCloseBalsamCfg
                    text: "Fermer"
                    onClicked: balsamConfigPopup.close()
                    background: Rectangle { color: btnCloseBalsamCfg.pressed ? "#374151" : "#4b5563"; radius: 4 }
                    contentItem: Text { text: btnCloseBalsamCfg.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                }
            }
        }
    }

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
        spacing: 6
        Text {
            text: axisRow.axisLabel
            color: "#9ca3af"
            Layout.preferredWidth: 18
            verticalAlignment: Text.AlignVCenter
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            from: axisRow.minValue
            to:   axisRow.maxValue
            stepSize: axisRow.stepValue
            value: axisRow.boundValue
            onMoved: axisRow.valueEdited(value)
        }
        TextField {
            id: tf
            Layout.preferredWidth: 70
            text: axisRow.boundValue.toFixed(axisRow.decimals)
            color: "white"
            background: Rectangle { color: "#1f1f23"; border.color: "#3a3a3a"; radius: 3 }
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
                color: btnResetAxis.pressed ? "#374151" : (btnResetAxis.hovered ? "#3a3a3a" : "transparent")
                border.color: "#3a3a3a"
                radius: 3
            }
            contentItem: Text {
                text: btnResetAxis.text
                color: "#9ca3af"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
            }
        }
    }

    // ============================================================
    // Layout
    // ============================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ---- Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "← Retour"
                onClicked: root.closeRequested()
                background: Rectangle { color: parent.pressed ? "#374151" : "#4b5563"; radius: 4 }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            Text {
                text: "Configurateur de modèle 3D"
                color: "white"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }

            // Toggle caméra
            Row {
                spacing: 6
                Button {
                    id: btnGame
                    text: "Vue jeu"
                    checkable: true
                    checked: root.cameraMode === "game"
                    onClicked: root.cameraMode = "game"
                    background: Rectangle {
                        color: btnGame.checked ? "#2563eb" : (btnGame.pressed ? "#374151" : "#4b5563")
                        radius: 4
                    }
                    contentItem: Text { text: btnGame.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                }
                Button {
                    id: btnFace
                    text: "Face"
                    checkable: true
                    checked: root.cameraMode === "face"
                    onClicked: root.cameraMode = "face"
                    background: Rectangle {
                        color: btnFace.checked ? "#2563eb" : (btnFace.pressed ? "#374151" : "#4b5563")
                        radius: 4
                    }
                    contentItem: Text { text: btnFace.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                }
            }

            Button {
                text: "Reset vue"
                onClicked: viewport.resetView()
                background: Rectangle { color: parent.pressed ? "#374151" : "#4b5563"; radius: 4 }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
            }

            Button {
                id: btnBalsamCfg
                text: "⚙ Balsam"
                onClicked: balsamConfigPopup.open()
                ToolTip.visible: hovered
                ToolTip.delay: 400
                ToolTip.text: root.balsamPath.length > 0
                              ? "Configuré : " + root.balsamPath
                              : "Configurer le chemin de balsam.exe"
                background: Rectangle {
                    color: root.balsamPath.length > 0
                           ? (btnBalsamCfg.pressed ? "#16a34a" : "#22c55e")
                           : (btnBalsamCfg.pressed ? "#7c2d12" : "#b45309")
                    radius: 4
                }
                contentItem: Text { text: btnBalsamCfg.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
            }
        }

        // ---- Body : viewport + panneau droit
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // Viewport
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#0f0f12"
                radius: 6
                border.color: "#3a3a3a"
                clip: true

                Model3DPreview {
                    id: viewport
                    anchors.fill: parent
                    modelSourceUrl: root.modelSourceUrl
                    modelName: root.modelName
                    subjectScale: Qt.vector3d(root.scaleX, root.scaleY, root.scaleZ)
                    subjectEuler: Qt.vector3d(root.eulerX, root.eulerY, root.eulerZ)
                    subjectPosition: Qt.vector3d(root.posX, root.posY, root.posZ)
                    comparisonName: root.comparisonName
                    cameraMode: root.cameraMode
                    auxObjUrl: root.auxObjUrl
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !root.hasFolder
                    color: "#22222a"
                    radius: 6
                    border.color: "#444"
                    width: 360; height: 80
                    Text {
                        anchors.centerIn: parent
                        text: "Sélectionnez un dossier de modèle ou déposez un .obj"
                        color: "#a1a1aa"
                    }
                }

                // Drag & drop d'un .obj (ou autre format supporté par
                // RuntimeLoader) directement sur le viewport.
                DropArea {
                    id: objDropArea
                    anchors.fill: parent
                    onEntered: (drag) => {
                        if (drag.hasUrls && drag.urls.length > 0) {
                            const u = drag.urls[0].toString().toLowerCase()
                            if (u.endsWith(".obj") || u.endsWith(".gltf")
                                || u.endsWith(".glb") || u.endsWith(".fbx")) {
                                drag.accept()
                            }
                        }
                    }
                    onDropped: (drop) => {
                        if (drop.hasUrls && drop.urls.length > 0) {
                            const u = drop.urls[0].toString()
                            const ul = u.toLowerCase()
                            if (ul.endsWith(".obj") || ul.endsWith(".gltf")
                                || ul.endsWith(".glb") || ul.endsWith(".fbx")) {
                                root.auxObjUrl = u
                                statusBar.message = "Modèle aperçu chargé : " + u
                                drop.accept()
                            }
                        }
                    }
                }

                // Overlay visuel pendant un drag valide
                Rectangle {
                    anchors.fill: parent
                    visible: objDropArea.containsDrag
                    color: "#3322c55e"
                    border.color: "#22c55e"
                    border.width: 3
                    radius: 6
                    z: 50
                    Text {
                        anchors.centerIn: parent
                        text: "Déposer pour prévisualiser"
                        color: "#22c55e"
                        font.pixelSize: 24
                        font.bold: true
                    }
                }
            }

            // Panneau de contrôles
            ScrollView {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: 380
                    spacing: 14

                    // --- Source
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Source"
                        background: Rectangle { color: "#2a2a2e"; radius: 6; border.color: "#3a3a3a" }
                        label: Text { text: parent.title; color: "#e5e7eb"; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            Text {
                                text: root.folderPath || "Aucun dossier sélectionné"
                                color: root.folderPath ? "#d1d5db" : "#6b7280"
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                wrapMode: Text.NoWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Button {
                                    id: btnPickFolder
                                    text: "Sélectionner dossier..."
                                    Layout.fillWidth: true
                                    onClicked: folderDialog.open()
                                    background: Rectangle { color: btnPickFolder.pressed ? "#5d4037" : "#795548"; radius: 4 }
                                    contentItem: Text { text: btnPickFolder.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
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
                                    background: Rectangle { color: btnReload.enabled ? (btnReload.pressed ? "#374151" : "#4b5563") : "#3a3a3a"; radius: 4 }
                                    contentItem: Text { text: btnReload.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                                }
                            }
                        }
                    }

                    // --- Identité
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Identité"
                        background: Rectangle { color: "#2a2a2e"; radius: 6; border.color: "#3a3a3a" }
                        label: Text { text: parent.title; color: "#e5e7eb"; font.bold: true }

                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 6

                            Text { text: "Nom"; color: "#d1d5db" }
                            TextField {
                                Layout.fillWidth: true
                                text: root.modelName
                                placeholderText: "Princess"
                                onEditingFinished: root.modelName = text
                                color: "white"
                                background: Rectangle { color: "#1f1f23"; border.color: "#3a3a3a"; radius: 3 }
                            }
                            Text { text: "Version"; color: "#d1d5db" }
                            TextField {
                                Layout.fillWidth: true
                                text: root.modelVersion
                                placeholderText: "1.0.0"
                                onEditingFinished: root.modelVersion = text
                                color: "white"
                                background: Rectangle { color: "#1f1f23"; border.color: "#3a3a3a"; radius: 3 }
                            }
                        }
                    }

                    // --- Comparaison
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Comparaison"
                        background: Rectangle { color: "#2a2a2e"; radius: 6; border.color: "#3a3a3a" }
                        label: Text { text: parent.title; color: "#e5e7eb"; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            ComboBox {
                                id: compCombo
                                Layout.fillWidth: true
                                model: ["<Aucun>"].concat(root.installedModels)
                                onActivated: {
                                    root.comparisonName = (currentIndex <= 0) ? "" : currentText
                                }
                                contentItem: Text {
                                    text: parent.displayText
                                    color: "white"
                                    leftPadding: 8
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle { color: "#1f1f23"; border.color: "#3a3a3a"; radius: 3 }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Décalage X"; color: "#d1d5db" }
                                Slider {
                                    Layout.fillWidth: true
                                    from: 0; to: 1000
                                    value: viewport.comparisonOffsetX
                                    onMoved: viewport.comparisonOffsetX = value
                                }
                                Text { text: viewport.comparisonOffsetX.toFixed(0); color: "#9ca3af"; Layout.preferredWidth: 36 }
                            }
                        }
                    }

                    // --- Aperçu .obj
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Aperçu .obj (drag&drop ou bouton)"
                        background: Rectangle { color: "#2a2a2e"; radius: 6; border.color: "#3a3a3a" }
                        label: Text { text: parent.title; color: "#e5e7eb"; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            Text {
                                text: root.auxObjUrl.toString().length > 0
                                      ? root.auxObjUrl.toString()
                                      : "Aucun .obj chargé"
                                color: root.auxObjUrl.toString().length > 0 ? "#d1d5db" : "#6b7280"
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                wrapMode: Text.NoWrap
                                font.pixelSize: 11
                            }

                            Text {
                                visible: root.auxObjUrl.toString().length > 0
                                text: "Statut : " + viewport.auxObjStatus
                                      + (viewport.auxObjStatus === "erreur" && viewport.auxObjError
                                         ? " — " + viewport.auxObjError
                                         : "")
                                color: viewport.auxObjStatus === "erreur" ? "#ef4444"
                                     : viewport.auxObjStatus === "prêt"   ? "#22c55e"
                                     : "#9ca3af"
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Button {
                                    id: btnPickObj
                                    text: "Importer .obj..."
                                    Layout.fillWidth: true
                                    onClicked: objDialog.open()
                                    background: Rectangle { color: btnPickObj.pressed ? "#5d4037" : "#795548"; radius: 4 }
                                    contentItem: Text { text: btnPickObj.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                                }
                                Button {
                                    id: btnClearObj
                                    text: "Effacer"
                                    enabled: root.auxObjUrl.toString().length > 0
                                    onClicked: root.auxObjUrl = ""
                                    background: Rectangle { color: btnClearObj.enabled ? (btnClearObj.pressed ? "#374151" : "#4b5563") : "#3a3a3a"; radius: 4 }
                                    contentItem: Text { text: btnClearObj.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                                }
                            }

                            // Conversion via balsam → bascule sur le .qml généré
                            Button {
                                id: btnBalsamConvert
                                text: LauncherManager.balsamRunning
                                      ? "⏳ Conversion en cours..."
                                      : "🔧 Convertir avec balsam"
                                Layout.fillWidth: true
                                enabled: root.auxObjUrl.toString().length > 0
                                         && root.balsamPath.length > 0
                                         && !LauncherManager.balsamRunning
                                onClicked: root.runBalsamOnAuxObj()
                                ToolTip.visible: hovered && !enabled
                                ToolTip.delay: 400
                                ToolTip.text: root.balsamPath.length === 0
                                              ? "Configure d'abord le chemin de balsam (bouton ⚙ Balsam en haut)"
                                              : (root.auxObjUrl.toString().length === 0
                                                 ? "Importe d'abord un .obj/.glb"
                                                 : "Conversion déjà en cours")
                                background: Rectangle {
                                    color: btnBalsamConvert.enabled
                                           ? (btnBalsamConvert.pressed ? "#16a34a" : "#22c55e")
                                           : "#3a3a3a"
                                    radius: 4
                                }
                                contentItem: Text { text: btnBalsamConvert.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                            }
                            Text {
                                visible: btnBalsamConvert.enabled
                                text: "Génère <dossier_du_.obj>/<basename>_qml/ et le charge ici"
                                color: "#9ca3af"
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Décalage X"; color: "#d1d5db" }
                                Slider {
                                    Layout.fillWidth: true
                                    from: -1000; to: 1000
                                    value: viewport.auxObjOffsetX
                                    onMoved: viewport.auxObjOffsetX = value
                                }
                                Text { text: viewport.auxObjOffsetX.toFixed(0); color: "#9ca3af"; Layout.preferredWidth: 40 }
                            }

                            // Scale uniforme — utile car les .obj arrivent
                            // souvent à des échelles très variables (mm/cm/m).
                            // Slider [0.05, 100] step 0.05 + boutons ÷10/×10
                            // pour atteindre les ordres de grandeur extrêmes
                            // sans saturer le slider linéaire.
                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "S"
                                minValue: 0.05; maxValue: 100; stepValue: 0.05; decimals: 2
                                defaultValue: 1
                                boundValue: viewport.auxObjScale
                                onValueEdited: (v) => viewport.auxObjScale = v
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Button {
                                    id: btnObjScaleDown
                                    text: "÷ 10"
                                    Layout.fillWidth: true
                                    onClicked: viewport.auxObjScale = Math.max(0.0001, viewport.auxObjScale / 10)
                                    background: Rectangle { color: btnObjScaleDown.pressed ? "#374151" : "#4b5563"; radius: 4 }
                                    contentItem: Text { text: btnObjScaleDown.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 4 }
                                }
                                Button {
                                    id: btnObjScaleUp
                                    text: "× 10"
                                    Layout.fillWidth: true
                                    onClicked: viewport.auxObjScale = Math.min(10000, viewport.auxObjScale * 10)
                                    background: Rectangle { color: btnObjScaleUp.pressed ? "#374151" : "#4b5563"; radius: 4 }
                                    contentItem: Text { text: btnObjScaleUp.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 4 }
                                }
                            }
                        }
                    }

                    // --- Échelle
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Échelle"
                        background: Rectangle { color: "#2a2a2e"; radius: 6; border.color: "#3a3a3a" }
                        label: Text { text: parent.title; color: "#e5e7eb"; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            CheckBox {
                                text: "Verrouillage uniforme (XYZ)"
                                checked: root.scaleLocked
                                onCheckedChanged: root.scaleLocked = checked
                                contentItem: Text {
                                    text: parent.text
                                    color: "#d1d5db"
                                    leftPadding: parent.indicator.width + 6
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            AxisSlider {
                                Layout.fillWidth: true
                                axisLabel: "X"
                                minValue: 0.05; maxValue: 500; stepValue: 0.05; decimals: 2
                                defaultValue: 1
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
                                defaultValue: 1
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
                                defaultValue: 1
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
                        background: Rectangle { color: "#2a2a2e"; radius: 6; border.color: "#3a3a3a" }
                        label: Text { text: parent.title; color: "#e5e7eb"; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

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
                        background: Rectangle { color: "#2a2a2e"; radius: 6; border.color: "#3a3a3a" }
                        label: Text { text: parent.title; color: "#e5e7eb"; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            Text {
                                text: "Y > 0 = monter (utile pour faire toucher les pieds au sol)"
                                color: "#9ca3af"
                                font.pixelSize: 10
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

                            Button {
                                text: "Reset transform global"
                                Layout.fillWidth: true
                                onClicked: root.resetTransform()
                                background: Rectangle { color: parent.pressed ? "#374151" : "#4b5563"; radius: 4 }
                                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                            }
                        }
                    }

                    // --- Actions
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Actions"
                        background: Rectangle { color: "#2a2a2e"; radius: 6; border.color: "#3a3a3a" }
                        label: Text { text: parent.title; color: "#e5e7eb"; font.bold: true }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            Button {
                                text: "Sauvegarder dans le .qml + créer .meow"
                                Layout.fillWidth: true
                                enabled: root.hasFolder
                                onClicked: root.applyTransformAndSave(false)
                                background: Rectangle {
                                    color: parent.enabled ? (parent.pressed ? "#388e3c" : "#4caf50") : "#4b5563"
                                    radius: 4
                                }
                                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
                            }
                            Button {
                                text: "Sauvegarder & Uploader"
                                Layout.fillWidth: true
                                enabled: root.hasFolder && !LauncherManager.isDownloading
                                onClicked: root.applyTransformAndSave(true)
                                background: Rectangle {
                                    color: parent.enabled ? (parent.pressed ? "#1976d2" : "#2196f3") : "#4b5563"
                                    radius: 4
                                }
                                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; padding: 6 }
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
            color: "#27272a"
            radius: 4
            border.color: "#3a3a3a"
            property string message: "Prêt."

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                verticalAlignment: Text.AlignVCenter
                text: statusBar.message
                      + (LauncherManager.downloadStatus
                         ? "  [" + LauncherManager.downloadStatus + "]"
                         : "")
                color: "#d1d5db"
                elide: Text.ElideRight
            }
        }
    }
}
