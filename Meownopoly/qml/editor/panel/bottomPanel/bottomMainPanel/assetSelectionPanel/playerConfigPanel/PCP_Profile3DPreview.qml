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
 */
Item {
    id: root

    property string modelName: "Princess"
    property bool   spinning: true
    property real   spinDegPerSec: 30
    property color  backgroundColor: "#1f1f1f"

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
                eulerRotation.x: -30
                eulerRotation.y: -45
                ambientColor: Qt.rgba(0.5, 0.5, 0.5, 1.0)
                brightness: 1.2
            }

            PerspectiveCamera {
                id: camera
                position: Qt.vector3d(0, 90, 220)
                eulerRotation.x: -15
                clipNear: 1
                clipFar: 5000
            }

            Node {
                id: spinNode
                eulerRotation.y: 0

                Model {
                    id: primitive
                    visible: root.modelName === "Cube" || root.modelName === "Sphere"
                    source: root.modelName === "Sphere" ? "#Sphere" : "#Cube"
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
