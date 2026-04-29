import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import AssetManager

/*
 * Preview 3D miniature pour la card / le détail de profil.
 * Charge le model depuis :
 *  - Primitives "Cube" / "Sphere" → Model #Cube / #Sphere
 *  - Sinon : Loader3D vers <AppData>/models/<modelName>/<modelName>.qml
 *
 * Pas de physics ; rotation lente en boucle pour donner du relief.
 *
 * Cadrage :
 *  - OrthographicCamera centrée verticalement sur la moitié de la
 *    `modelHeight` estimée, magnification calée pour entrer la totalité
 *    du model dans la vue avec un peu de marge.
 *  - Le View3D est containé dans un Item clip:true pour que rien ne
 *    déborde hors du cadre de la card.
 */
Item {
    id: root

    property string modelName: "Princess"
    property bool   spinning: true
    property real   spinDegPerSec: 30
    property color  backgroundColor: "#1f1f1f"

    // Hauteur monde-3D estimée du model. Princess fait ~150 unités, Cube
    // standard ~100, etc. Sert au cadrage ortho. Surchargeable depuis le
    // parent si on veut adapter (ex: gros boss).
    property real   modelHeight: 160

    // Marge verticale autour du model (1.0 = pile la hauteur du model
    // visible ; > 1 = plus d'espace autour, donc model plus petit).
    property real   verticalMargin: 1.6

    // Inclinaison verticale de la caméra (degrés vers le bas).
    // 0 = vue strictement horizontale ; positif = légère vue plongeante.
    property real   cameraPitchDeg: 15

    clip: true

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        radius: 4
    }

    View3D {
        id: view3D
        anchors.fill: parent
        camera: camera

        environment: SceneEnvironment {
            id: env
            clearColor: "transparent"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        Node {
            id: scene

            DirectionalLight {
                eulerRotation.x: -25
                eulerRotation.y: -45
                ambientColor: Qt.rgba(0.55, 0.55, 0.55, 1.0)
                brightness: 1.3
            }

            // Caméra ortho qui pivote autour du milieu du model pour
            // donner une légère vue plongeante (cf. cameraPitchDeg).
            // Le centre de cadrage reste le point (0, modelHeight*0.5, 0)
            // quel que soit le pitch — la caméra tourne autour de la
            // cible à distance _dist constante.
            OrthographicCamera {
                id: camera
                readonly property real _pitchRad: root.cameraPitchDeg * Math.PI / 180
                readonly property real _dist: 400
                readonly property real _targetY: root.modelHeight * 0.5
                position: Qt.vector3d(0,
                                      _targetY + _dist * Math.sin(_pitchRad),
                                      _dist * Math.cos(_pitchRad))
                eulerRotation.x: -root.cameraPitchDeg
                clipNear: 1
                clipFar: 5000
                horizontalMagnification: view3D.height > 0
                                          ? (view3D.height / (root.modelHeight * root.verticalMargin))
                                          : 1
                verticalMagnification:   horizontalMagnification
            }

            Node {
                id: spinNode
                eulerRotation.y: 0

                Model {
                    id: primitive
                    visible: root.modelName === "Cube" || root.modelName === "Sphere"
                    source: root.modelName === "Sphere" ? "#Sphere" : "#Cube"
                    // Primitives Qt sont à l'origine ; on les remonte pour
                    // s'aligner avec le centre vertical visé par la caméra.
                    y: root.modelHeight * 0.5
                    scale: Qt.vector3d(
                        root.modelHeight / 100,
                        root.modelHeight / 100,
                        root.modelHeight / 100)
                    materials: PrincipledMaterial { baseColor: "#a8c8ff" }
                }

                Loader3D {
                    id: modelLoader
                    visible: root.modelName !== "Cube" && root.modelName !== "Sphere"
                    source: visible
                              ? ("file:///" + AssetManager.getAppDataPath()
                                 + "/models/" + root.modelName + "/"
                                 + root.modelName + ".qml")
                              : ""
                    onStatusChanged: {
                        if (status === Loader3D.Error)
                            console.warn("[PCP_Profile3DPreview] Erreur chargement modèle:",
                                         root.modelName)
                    }
                }
            }
        }
    }

    NumberAnimation on _spinAngle {
        running: root.spinning
        from: 0
        to: 360
        duration: 360 / Math.max(1, root.spinDegPerSec) * 1000
        loops: Animation.Infinite
    }
    property real _spinAngle: 0
    Binding {
        target: spinNode
        property: "eulerRotation.y"
        value: root._spinAngle
    }
}
