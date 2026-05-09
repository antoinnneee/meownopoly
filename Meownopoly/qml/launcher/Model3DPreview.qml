/*
 * Model3DPreview.qml — Viewport 3D pour le configurateur de modèle.
 *
 * Affiche :
 *  - Le modèle en cours de configuration (chargé depuis un dossier source
 *    arbitraire), wrappé dans un Node qui applique scale/eulerRotation
 *    depuis l'extérieur (live preview).
 *  - Optionnellement un modèle de comparaison parmi ceux installés
 *    (`AssetManager.availablePlayerModels`).
 *  - Une grille au sol (AxisHelper de QtQuick3D.Helpers).
 *
 * Modes caméra :
 *  - "game" : OrthographicCamera 55° (vue jeu, calquée sur World3D.qml).
 *  - "face" : PerspectiveCamera turntable orbital (drag souris pour
 *    tourner autour du sujet, molette pour zoom).
 *
 * Les chemins relatifs des `.mesh` et `.png` du modèle source sont
 * résolus par Loader3D par rapport à l'URL du .qml chargé — donc
 * on charge directement depuis le dossier source de l'utilisateur,
 * pas besoin de copier les assets.
 */

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.AssetUtils
import AssetManager

Item {
    id: root

    // --- API ---
    property url    modelSourceUrl: ""              // file:///.../Princess.qml
    property string modelName: ""                   // "Princess"
    property vector3d subjectScale: Qt.vector3d(1, 1, 1)
    property vector3d subjectEuler: Qt.vector3d(0, 0, 0)
    property vector3d subjectPosition: Qt.vector3d(0, 0, 0)

    // "" = pas de comparaison ; "Cube"/"Sphere" = primitives ; sinon nom
    // de modèle dans <AppData>/models/<name>/<name>.qml
    property string comparisonName: ""
    // décalage en X (unités monde) entre sujet et modèle de comparaison
    property real   comparisonOffsetX: 200

    // Aperçu d'un .obj externe (ex: avant de l'importer comme nouveau
    // modèle). Chargé via RuntimeLoader de QtQuick3D.AssetUtils, qui
    // gère obj/gltf/glb/fbx via balsamruntime.
    property url    auxObjUrl: ""
    property real   auxObjOffsetX: -200
    property real   auxObjScale: 1.0   // scale uniforme appliqué au wrapper
    // Statut/erreur exposés pour que le panneau puisse les afficher.
    readonly property string auxObjStatus: auxLoader.status === RuntimeLoader.Empty ? "vide"
                                         : auxLoader.status === RuntimeLoader.Loading ? "chargement..."
                                         : auxLoader.status === RuntimeLoader.Ready   ? "prêt"
                                         : auxLoader.status === RuntimeLoader.Error   ? "erreur" : "?"
    readonly property string auxObjError: auxLoader.errorString

    property string cameraMode: "game"              // "game" | "face"
    property color  bgColor: "#1f1f23"

    // --- Caméra game (ortho 55° calquée sur World3D.qml) ---
    property real gameMagnification: 1.0
    property real gamePanX: 0        // pan world X (≈ right écran)
    property real gamePanZ: 0        // pan world Z (≈ up écran)
    // --- Caméra face (turntable) ---
    property real orbitYaw:   0      // degrés (rotation autour de Y)
    property real orbitPitch: -15    // degrés
    property real orbitDistance: 600
    // Pan exprimé dans le repère LOCAL post-rotation (= right/up écran)
    property real facePanLocalX: 0
    property real facePanLocalY: 0

    function resetView() {
        gameMagnification = 1.0
        gamePanX = 0; gamePanZ = 0
        orbitYaw = 0
        orbitPitch = -15
        orbitDistance = 600
        facePanLocalX = 0; facePanLocalY = 0
    }

    // --- Scène ---
    View3D {
        id: view3D
        anchors.fill: parent
        camera: root.cameraMode === "game" ? gameCam : faceCam

        environment: SceneEnvironment {
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            backgroundMode: SceneEnvironment.Color
            clearColor: root.bgColor
        }

        Node {
            id: sceneRoot

            DirectionalLight {
                eulerRotation.x: -25
                eulerRotation.y: -35
                brightness: 1.0
                ambientColor: Qt.rgba(0.3, 0.3, 0.35, 1)
            }
            DirectionalLight {
                eulerRotation.x: 30
                eulerRotation.y: 145
                brightness: 0.4
            }

            // Grille XZ (axes natifs désactivés — on dessine les nôtres
            // plus bas, plus fins et translucides).
            AxisHelper {
                id: axisHelper
                enableAxisLines: false
                enableXZGrid: true
                enableXYGrid: false
                enableYZGrid: false
                gridColor: "#3f3f46"
                gridOpacity: 0.7
                scale: Qt.vector3d(5, 5, 5)
            }

            // Axes XYZ custom : cylindres fins semi-transparents.
            // #Cylinder primitive : hauteur 100u, rayon 50u, orienté +Y.
            // scale.y = 6 → hauteur 600u (bien visible) ; scale.x/z = 0.015
            // → rayon 0.75u (très fin). Couleurs RGB conventionnelles.
            Model {
                source: "#Cylinder"
                scale: Qt.vector3d(0.015, 6, 0.015)
                eulerRotation.z: 90  // bascule le Y du cylindre vers X
                materials: PrincipledMaterial {
                    baseColor: "#ef4444"
                    opacity: 0.4
                    alphaMode: PrincipledMaterial.Blend
                    lighting: PrincipledMaterial.NoLighting
                }
            }
            Model {
                source: "#Cylinder"
                scale: Qt.vector3d(0.015, 6, 0.015)
                materials: PrincipledMaterial {
                    baseColor: "#22c55e"
                    opacity: 0.4
                    alphaMode: PrincipledMaterial.Blend
                    lighting: PrincipledMaterial.NoLighting
                }
            }
            Model {
                source: "#Cylinder"
                scale: Qt.vector3d(0.015, 6, 0.015)
                eulerRotation.x: 90  // bascule Y vers Z
                materials: PrincipledMaterial {
                    baseColor: "#3b82f6"
                    opacity: 0.4
                    alphaMode: PrincipledMaterial.Blend
                    lighting: PrincipledMaterial.NoLighting
                }
            }

            // Sujet : modèle en cours de configuration
            Node {
                id: subjectWrapper
                position: root.subjectPosition
                scale: root.subjectScale
                eulerRotation: root.subjectEuler

                Loader3D {
                    id: subjectLoader
                    source: root.modelSourceUrl
                    onStatusChanged: {
                        if (status === Loader3D.Error)
                            console.error("Model3DPreview: erreur chargement sujet:",
                                          source, sourceComponent ? sourceComponent.errorString() : "")
                    }
                }
            }

            // Aperçu .obj (RuntimeLoader)
            Node {
                id: auxObjWrapper
                x: root.auxObjOffsetX
                scale: Qt.vector3d(root.auxObjScale, root.auxObjScale, root.auxObjScale)
                visible: root.auxObjUrl.toString().length > 0

                RuntimeLoader {
                    id: auxLoader
                    source: root.auxObjUrl
                    onStatusChanged: {
                        if (status === RuntimeLoader.Error)
                            console.error("Model3DPreview: erreur RuntimeLoader:",
                                          source, errorString)
                    }
                }
            }

            // Comparaison
            Node {
                id: comparisonWrapper
                x: root.comparisonOffsetX
                visible: root.comparisonName.length > 0

                // Primitives
                Model {
                    visible: root.comparisonName === "Cube" || root.comparisonName === "Sphere"
                    source: root.comparisonName === "Cube" ? "#Cube" : "#Sphere"
                    materials: PrincipledMaterial { baseColor: "#94a3b8" }
                }
                // Modèle installé
                Loader3D {
                    id: comparisonLoader
                    visible: root.comparisonName.length > 0
                             && root.comparisonName !== "Cube"
                             && root.comparisonName !== "Sphere"
                    source: visible
                            ? ("file:///" + AssetManager.getAppDataPath()
                               + "/models/" + root.comparisonName + "/"
                               + root.comparisonName + ".qml")
                            : ""
                    onStatusChanged: {
                        if (status === Loader3D.Error)
                            console.error("Model3DPreview: erreur chargement comparaison:",
                                          source, sourceComponent ? sourceComponent.errorString() : "")
                    }
                }
            }

            // Caméra GAME (ortho 55°, calque World3D).
            // Le rig parent gère le pan dans le plan XZ monde (la vue ortho
            // top-down voit principalement ce plan).
            Node {
                id: gameCamRig
                x: root.gamePanX
                z: root.gamePanZ
                OrthographicCamera {
                    id: gameCam
                    x: 0
                    y: 1000
                    z: 600
                    eulerRotation.x: -55
                    eulerRotation.y: 0
                    eulerRotation.z: 0
                    clipNear: -10000
                    clipFar: 1000055
                    horizontalMagnification: root.gameMagnification
                    verticalMagnification: root.gameMagnification
                }
            }

            // Caméra FACE — turntable + pan.
            // Hiérarchie : faceOrbit (yaw/pitch) → facePan (translate dans
            // le repère post-rotation = right/up de la caméra) → faceCam.
            // Cette structure permet un pan naturel quel que soit l'angle.
            Node {
                id: faceOrbit
                eulerRotation.y: root.orbitYaw
                eulerRotation.x: root.orbitPitch

                Node {
                    id: facePan
                    x: root.facePanLocalX
                    y: root.facePanLocalY
                    PerspectiveCamera {
                        id: faceCam
                        z: root.orbitDistance
                        clipNear: 1
                        clipFar: 10000
                        fieldOfView: 35
                    }
                }
            }
        }
    }

    // --- Interaction caméra ---
    // Mode game : drag gauche = pan ; molette = zoom.
    // Mode face : drag gauche = orbit ; drag milieu/droit OU Shift+gauche
    // = pan ; molette = zoom (distance d'orbite).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        property real lastX: 0
        property real lastY: 0
        property bool dragging: false
        property string dragMode: ""   // "orbit" | "pan"

        onPressed: (mouse) => {
            lastX = mouse.x
            lastY = mouse.y
            dragging = true
            const isPanButton = (mouse.button === Qt.MiddleButton) || (mouse.button === Qt.RightButton)
            const shiftPan = (mouse.modifiers & Qt.ShiftModifier) !== 0
            if (root.cameraMode === "face") {
                dragMode = (isPanButton || shiftPan) ? "pan" : "orbit"
            } else {
                dragMode = "pan"
            }
        }
        onReleased: { dragging = false; dragMode = "" }
        onPositionChanged: (mouse) => {
            if (!dragging) return
            const dx = mouse.x - lastX
            const dy = mouse.y - lastY
            lastX = mouse.x
            lastY = mouse.y

            if (dragMode === "orbit") {
                root.orbitYaw   += dx * 0.5
                root.orbitPitch = Math.max(-89, Math.min(89, root.orbitPitch + dy * 0.5))
                return
            }
            // dragMode === "pan"
            if (root.cameraMode === "game") {
                // Mapping écran → monde : ortho avec mag courante. La vue
                // étant inclinée à -55°, dy souris ≈ déplacement Z monde
                // (légèrement réduit par cos(35°) mais on simplifie).
                const k = 1.0 / Math.max(0.1, root.gameMagnification)
                root.gamePanX -= dx * k
                root.gamePanZ -= dy * k
            } else {
                // Mode face : pan dans le repère LOCAL de facePan.
                // dx > 0 (drag droite) → caméra doit voir scène plus à gauche
                // → on bouge facePan en -X local (qui suit la rotation, donc
                // automatiquement aligné avec "right of view").
                const k = root.orbitDistance * 0.0015
                root.facePanLocalX -= dx * k
                root.facePanLocalY += dy * k    // dy>0 (drag bas) → on monte
            }
        }
        onWheel: (wheel) => {
            const delta = wheel.angleDelta.y
            if (root.cameraMode === "face") {
                const factor = Math.pow(1.1, -delta / 120)
                root.orbitDistance = Math.max(50, Math.min(5000, root.orbitDistance * factor))
            } else {
                const factor = Math.pow(1.1, delta / 120)
                root.gameMagnification = Math.max(0.1, Math.min(20, root.gameMagnification * factor))
            }
        }
    }

    // HUD discret en haut à gauche
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 10
        color: "#cc1f1f23"
        radius: 4
        border.color: "#444"
        width: hudCol.implicitWidth + 16
        height: hudCol.implicitHeight + 12

        Column {
            id: hudCol
            anchors.centerIn: parent
            spacing: 2
            Text {
                text: root.cameraMode === "game"
                      ? "Caméra : Vue jeu (mag " + root.gameMagnification.toFixed(2)
                        + ", pan " + root.gamePanX.toFixed(0) + "/" + root.gamePanZ.toFixed(0) + ")"
                      : "Caméra : Face (yaw " + root.orbitYaw.toFixed(0)
                        + "°, pitch " + root.orbitPitch.toFixed(0)
                        + "°, dist " + root.orbitDistance.toFixed(0)
                        + ", pan " + root.facePanLocalX.toFixed(0) + "/" + root.facePanLocalY.toFixed(0) + ")"
                color: "#e5e7eb"
                font.pixelSize: 11
            }
            Text {
                text: root.cameraMode === "face"
                      ? "Drag gauche = orbite • Drag milieu/droit ou Shift+gauche = pan • Molette = zoom"
                      : "Drag = pan • Molette = zoom"
                color: "#9ca3af"
                font.pixelSize: 10
            }
        }
    }
}
