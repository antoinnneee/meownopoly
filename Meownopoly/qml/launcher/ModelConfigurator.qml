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

    // URL du serveur de ressources, à passer depuis le Launcher (logic.serverUrl).
    property string serverUrl: ""

    // --- État interne ---
    property string folderPath: ""           // chemin clean (sans file:///)
    property string modelName: ""            // ex "Princess"
    property string modelVersion: "1.0.0"
    property string comparisonName: ""
    property string cameraMode: "game"

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
                        text: "Sélectionnez un dossier de modèle pour commencer"
                        color: "#a1a1aa"
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
